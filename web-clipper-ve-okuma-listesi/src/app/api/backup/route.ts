import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { errorMessage, jsonError } from "@/lib/api";
import { parseBackup, toBackupItem } from "@/lib/backup";
import { estimateReadingMinutes, extractDomain } from "@/lib/format";
import { scheduleParse } from "@/lib/readability";
import { sanitizeHtml } from "@/lib/sanitize";
import { upsertTagsForClip } from "@/lib/tags";

// Tüm okuma listesini eklentiyle uyumlu JSON yedeği olarak indirir.
export async function GET() {
  const clips = await prisma.clip.findMany({
    include: { tags: { include: { tag: true } }, highlights: { orderBy: { createdAt: "asc" } } },
    orderBy: { createdAt: "desc" },
  });
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(JSON.stringify(clips.map(toBackupItem), null, 2), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Content-Disposition": `attachment; filename="kayitli-okuma-${date}.json"`,
    },
  });
}

// Eklenti veya web yedeğini içe aktarır; aynı adresli kayıtlar atlanır (yalnızca etiketleri eklenir).
export async function POST(request: Request) {
  const raw: unknown = await request.json().catch(() => undefined);
  let items;
  try {
    items = parseBackup(raw);
  } catch (err) {
    return jsonError(errorMessage(err, "Geçersiz yedek dosyası"), 400);
  }

  let imported = 0;
  let skipped = 0;
  for (const item of items) {
    const existing = await prisma.clip.findUnique({ where: { url: item.url } });
    if (existing) {
      skipped++;
      if (item.tags.length) await upsertTagsForClip(existing.id, item.tags);
      continue;
    }
    // Eklentideki içerik yalnızca kaba bir filtreden geçmiştir: sunucuda yeniden temizlenir
    const content = item.content ? sanitizeHtml(item.content) : null;
    const plain = content?.replace(/<[^>]+>/g, " ") ?? "";
    const clip = await prisma.clip.create({
      data: {
        url: item.url,
        title: item.title,
        excerpt: item.excerpt,
        content,
        domain: item.domain ?? extractDomain(item.url),
        readingMinutes: content ? estimateReadingMinutes(plain) : null,
        parseStatus: content || item.excerpt ? "done" : "pending",
        isRead: item.isRead,
        isStarred: item.isStarred,
        createdAt: new Date(item.createdAt),
        highlights: { create: item.highlights },
      },
    });
    if (item.tags.length) await upsertTagsForClip(clip.id, item.tags);
    if (!content && !item.excerpt) scheduleParse(clip.id, item.url);
    imported++;
  }

  return NextResponse.json({ imported, skipped, total: items.length });
}
