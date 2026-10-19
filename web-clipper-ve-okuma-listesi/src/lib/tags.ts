import { prisma } from "@/lib/prisma";
import { normalizeTagName } from "@/lib/format";

export async function upsertTagsForClip(clipId: string, tagNames: string[]): Promise<void> {
  const names = [...new Set(tagNames.map(normalizeTagName).filter(Boolean))];
  if (names.length === 0) return;

  for (const name of names) {
    const tag = await prisma.tag.upsert({
      where: { name },
      create: { name },
      update: {},
    });
    await prisma.clipTag.upsert({
      where: { clipId_tagId: { clipId, tagId: tag.id } },
      create: { clipId, tagId: tag.id },
      update: {},
    });
  }
}
