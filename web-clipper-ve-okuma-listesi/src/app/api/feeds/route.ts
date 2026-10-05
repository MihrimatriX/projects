import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { fetchFeedEntries } from "@/lib/rss";
import { extractDomain, normalizeHttpUrl } from "@/lib/format";
import { errorMessage, jsonError, readJson } from "@/lib/api";
import { scheduleParse } from "@/lib/readability";
import { upsertTagsForClip } from "@/lib/tags";

export async function GET() {
  const feeds = await prisma.feed.findMany({ orderBy: { createdAt: "desc" } });
  return NextResponse.json({
    feeds: feeds.map((f) => ({
      id: f.id,
      url: f.url,
      title: f.title,
      lastFetched: f.lastFetched?.toISOString() ?? null,
      createdAt: f.createdAt.toISOString(),
    })),
  });
}

export async function POST(request: Request) {
  const body = await readJson(request);
  const rawUrl = String(body?.url ?? "").trim();
  if (!rawUrl) return jsonError("Feed URL gerekli", 400);
  const url = normalizeHttpUrl(rawUrl);
  if (!url) return jsonError("Geçersiz URL (yalnızca http/https)", 400);

  let feedData;
  try {
    feedData = await fetchFeedEntries(url);
  } catch (err) {
    // Ağ / XML hatası 500 yerine anlaşılır mesajla döner
    return jsonError(`Feed okunamadı: ${errorMessage(err, "bilinmeyen hata")}`, 502);
  }
  const { title, entries } = feedData;
  const feed = await prisma.feed.upsert({
    where: { url },
    create: { url, title, lastFetched: new Date() },
    update: { title, lastFetched: new Date() },
  });

  let imported = 0;
  let skipped = 0;

  for (const entry of entries.slice(0, 50)) {
    const existing = await prisma.clip.findUnique({ where: { url: entry.url } });
    if (existing) {
      skipped++;
      continue;
    }

    const clip = await prisma.clip.create({
      data: {
        url: entry.url,
        title: entry.title,
        excerpt: entry.excerpt,
        domain: extractDomain(entry.url),
        parseStatus: entry.excerpt ? "done" : "pending",
        createdAt: entry.publishedAt ?? new Date(),
      },
    });

    await upsertTagsForClip(clip.id, ["rss"]);
    if (!entry.excerpt) scheduleParse(clip.id, entry.url);
    imported++;
  }

  return NextResponse.json({ feed, imported, skipped, total: entries.length });
}
