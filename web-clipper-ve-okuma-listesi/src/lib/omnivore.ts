export type OmnivoreItem = {
  url?: string;
  title?: string;
  description?: string;
  labels?: string[];
  savedAt?: string;
  slug?: string;
};

export function parseOmnivoreExport(raw: unknown): OmnivoreItem[] {
  if (!raw) return [];

  if (Array.isArray(raw)) {
    return raw.filter(isOmnivoreItem);
  }

  if (typeof raw === "object" && raw !== null) {
    const obj = raw as Record<string, unknown>;
    if (Array.isArray(obj.links)) return obj.links.filter(isOmnivoreItem);
    if (Array.isArray(obj.items)) return obj.items.filter(isOmnivoreItem);
  }

  return [];
}

function isOmnivoreItem(v: unknown): v is OmnivoreItem {
  return typeof v === "object" && v !== null && typeof (v as OmnivoreItem).url === "string";
}

export function omnivoreToClipPayload(item: OmnivoreItem) {
  return {
    url: item.url!.trim(),
    title: (item.title ?? item.url ?? "").trim(),
    excerpt: item.description?.trim(),
    tags: (item.labels ?? []).map((l) => l.trim().toLowerCase()).filter(Boolean),
    createdAt: item.savedAt && !isNaN(Date.parse(item.savedAt)) ? new Date(item.savedAt) : undefined,
  };
}
