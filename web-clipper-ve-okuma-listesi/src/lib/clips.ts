import type { ClipItem, ClipSummary, HighlightItem } from "@/types/clip";

type ClipWithTags = {
  id: string;
  url: string;
  title: string;
  excerpt: string | null;
  content: string | null;
  domain: string | null;
  readingMinutes: number | null;
  parseStatus: string;
  isRead: boolean;
  isStarred: boolean;
  createdAt: Date;
  tags: { tag: { id: string; name: string } }[];
  highlights?: { id: string; text: string; note: string | null; color: string; createdAt: Date }[];
  _count?: { highlights: number };
};

function mapHighlights(hs: NonNullable<ClipWithTags["highlights"]>): HighlightItem[] {
  return hs.map((h) => ({
    id: h.id,
    text: h.text,
    note: h.note,
    color: h.color,
    createdAt: h.createdAt.toISOString(),
  }));
}

export function serializeClip(clip: ClipWithTags, includeContent = false): ClipItem | ClipSummary {
  const base = {
    id: clip.id,
    url: clip.url,
    title: clip.title,
    excerpt: clip.excerpt,
    domain: clip.domain,
    readingMinutes: clip.readingMinutes,
    parseStatus: clip.parseStatus as ClipItem["parseStatus"],
    isRead: clip.isRead,
    isStarred: clip.isStarred,
    createdAt: clip.createdAt.toISOString(),
    tags: clip.tags.map((t) => ({ id: t.tag.id, name: t.tag.name })),
  };

  if (includeContent) {
    return {
      ...base,
      content: clip.content,
      highlights: mapHighlights(clip.highlights ?? []),
    };
  }

  return {
    ...base,
    highlightCount: clip._count?.highlights ?? clip.highlights?.length ?? 0,
  };
}

export const clipInclude = {
  tags: { include: { tag: true } },
} as const;

export const clipDetailInclude = {
  ...clipInclude,
  highlights: { orderBy: { createdAt: "asc" as const } },
} as const;

export const clipListInclude = {
  ...clipInclude,
  _count: { select: { highlights: true } },
} as const;
