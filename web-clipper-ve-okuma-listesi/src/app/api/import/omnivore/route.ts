import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { parseOmnivoreExport, omnivoreToClipPayload } from "@/lib/omnivore";
import { extractDomain, normalizeHttpUrl } from "@/lib/format";
import { scheduleParse } from "@/lib/readability";
import { upsertTagsForClip } from "@/lib/tags";

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const items = parseOmnivoreExport(body?.data ?? body);

  if (!items.length) {
    return NextResponse.json({ error: "Geçerli Omnivore JSON bulunamadı" }, { status: 400 });
  }

  let imported = 0;
  let skipped = 0;
  let highlights = 0;

  for (const item of items) {
    const payload = omnivoreToClipPayload(item);
    const url = normalizeHttpUrl(payload.url);
    if (!url) continue;
    payload.url = url;

    const existing = await prisma.clip.findUnique({ where: { url: payload.url } });
    if (existing) {
      skipped++;
      if (payload.tags.length) await upsertTagsForClip(existing.id, payload.tags);
      continue;
    }

    const clip = await prisma.clip.create({
      data: {
        url: payload.url,
        title: payload.title || extractDomain(payload.url) || payload.url,
        excerpt: payload.excerpt,
        domain: extractDomain(payload.url),
        parseStatus: payload.excerpt ? "done" : "pending",
        createdAt: payload.createdAt ?? new Date(),
      },
    });

    if (payload.tags.length) await upsertTagsForClip(clip.id, payload.tags);
    if (!payload.excerpt) scheduleParse(clip.id, payload.url);

    if (Array.isArray((item as { highlights?: unknown[] }).highlights)) {
      for (const h of (item as { highlights: { quote?: string; note?: string }[] }).highlights) {
        const text = h.quote?.trim();
        if (!text) continue;
        await prisma.highlight.create({
          data: { clipId: clip.id, text: text.slice(0, 5000), note: h.note?.slice(0, 2000) ?? null },
        });
        highlights++;
      }
    }

    imported++;
  }

  return NextResponse.json({ imported, skipped, highlights, total: items.length });
}
