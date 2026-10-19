import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { clipInclude, clipListInclude, serializeClip } from "@/lib/clips";
import { readJson, jsonError } from "@/lib/api";
import { extractDomain, normalizeHttpUrl } from "@/lib/format";
import { scheduleParse } from "@/lib/readability";
import { upsertTagsForClip } from "@/lib/tags";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const filter = searchParams.get("filter") ?? "all";
  const tag = searchParams.get("tag");
  const q = searchParams.get("q")?.trim();
  const limit = Math.min(Number(searchParams.get("limit") ?? 100), 500);

  const where: Record<string, unknown> = {};
  if (filter === "unread") where.isRead = false;
  if (filter === "starred") where.isStarred = true;
  if (tag) where.tags = { some: { tag: { name: tag } } };
  if (q) {
    where.OR = [
      { title: { contains: q } },
      { excerpt: { contains: q } },
      { domain: { contains: q } },
    ];
  }

  const clips = await prisma.clip.findMany({
    where,
    include: clipListInclude,
    orderBy: { createdAt: "desc" },
    take: limit,
  });

  return NextResponse.json({ clips: clips.map((c) => serializeClip(c)) });
}

export async function POST(request: Request) {
  const body = await readJson(request);
  if (!body) return jsonError("Geçersiz istek gövdesi", 400);
  const rawUrl = String(body.url ?? "").trim();
  let title = String(body.title ?? "").trim();
  const tags = Array.isArray(body.tags) ? body.tags.map(String) : [];
  const excerpt = body.excerpt ? String(body.excerpt).trim() : undefined;
  const highlightText = body.highlight ? String(body.highlight).trim() : undefined;

  if (!rawUrl) return jsonError("URL gerekli", 400);
  // Yalnızca http(s): javascript:/data: adresleri listede tıklanabilir bağlantıya dönüşmesin
  const url = normalizeHttpUrl(rawUrl);
  if (!url) return jsonError("Geçersiz URL (yalnızca http/https)", 400);

  if (!title) {
    title = extractDomain(url) ?? url;
  }

  const existing = await prisma.clip.findUnique({ where: { url }, include: clipInclude });
  if (existing) {
    if (tags.length) await upsertTagsForClip(existing.id, tags);
    const updated = await prisma.clip.findUniqueOrThrow({
      where: { id: existing.id },
      include: clipInclude,
    });
    return NextResponse.json({ clip: serializeClip(updated), duplicate: true });
  }

  const clip = await prisma.clip.create({
    data: {
      url,
      title,
      excerpt,
      domain: extractDomain(url),
      parseStatus: excerpt ? "done" : "pending",
    },
    include: clipInclude,
  });

  if (tags.length) await upsertTagsForClip(clip.id, tags);

  if (highlightText) {
    await prisma.highlight.create({
      data: { clipId: clip.id, text: highlightText.slice(0, 5000) },
    });
  }

  if (!excerpt) {
    scheduleParse(clip.id, url);
  }

  const fresh = await prisma.clip.findUniqueOrThrow({
    where: { id: clip.id },
    include: clipInclude,
  });

  return NextResponse.json({ clip: serializeClip(fresh) }, { status: 201 });
}
