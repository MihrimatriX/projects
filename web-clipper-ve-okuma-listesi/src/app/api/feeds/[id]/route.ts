import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { fetchFeedEntries } from "@/lib/rss";
import { extractDomain } from "@/lib/format";
import { scheduleParse } from "@/lib/readability";
import { upsertTagsForClip } from "@/lib/tags";
import { errorMessage, isNotFound, jsonError } from "@/lib/api";

type Params = { params: Promise<{ id: string }> };

export async function POST(_request: Request, { params }: Params) {
  const { id } = await params;
  const feed = await prisma.feed.findUnique({ where: { id } });
  if (!feed) return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });

  let feedData;
  try {
    feedData = await fetchFeedEntries(feed.url);
  } catch (err) {
    return jsonError(`Feed okunamadı: ${errorMessage(err, "bilinmeyen hata")}`, 502);
  }
  const { title, entries } = feedData;
  await prisma.feed.update({
    where: { id },
    data: { title, lastFetched: new Date() },
  });

  let imported = 0;
  for (const entry of entries.slice(0, 30)) {
    const exists = await prisma.clip.findUnique({ where: { url: entry.url } });
    if (exists) continue;

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

  return NextResponse.json({ imported });
}

export async function DELETE(_request: Request, { params }: Params) {
  const { id } = await params;
  try {
    await prisma.feed.delete({ where: { id } });
  } catch (err) {
    if (isNotFound(err)) return jsonError("Bulunamadı", 404);
    throw err;
  }
  return NextResponse.json({ ok: true });
}
