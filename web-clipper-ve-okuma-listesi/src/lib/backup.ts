// Yedek biçimi Chrome eklentisinin "JSON indir" çıktısıyla aynıdır (kayıt dizisi): eklenti yedeği web
// arayüzüne, web yedeği de eklentinin Ayarlar → İçe aktar bölümüne yüklenebilir.
import { normalizeHttpUrl, normalizeTagName } from "@/lib/format";

export type BackupHighlight = { id?: string; text: string; note: string | null; createdAt?: string };

export type BackupItem = {
  id?: string;
  url: string;
  title: string;
  excerpt: string | null;
  content: string | null;
  domain: string | null;
  isRead: boolean;
  isStarred: boolean;
  tags: string[];
  highlights: BackupHighlight[];
  createdAt: string;
};

type DbClip = {
  id: string;
  url: string;
  title: string;
  excerpt: string | null;
  content: string | null;
  domain: string | null;
  isRead: boolean;
  isStarred: boolean;
  createdAt: Date;
  tags: { tag: { name: string } }[];
  highlights: { id: string; text: string; note: string | null; createdAt: Date }[];
};

export function toBackupItem(clip: DbClip): BackupItem {
  return {
    id: clip.id,
    url: clip.url,
    title: clip.title,
    excerpt: clip.excerpt,
    content: clip.content,
    domain: clip.domain,
    isRead: clip.isRead,
    isStarred: clip.isStarred,
    tags: clip.tags.map((t) => t.tag.name),
    highlights: clip.highlights.map((h) => ({
      id: h.id,
      text: h.text,
      note: h.note,
      createdAt: h.createdAt.toISOString(),
    })),
    createdAt: clip.createdAt.toISOString(),
  };
}

const str = (v: unknown, max: number) => (typeof v === "string" && v.trim() ? v.trim().slice(0, max) : null);

/**
 * Eklenti veya web yedeğini doğrular. Kabul: kayıt dizisi ya da { clips: [...] }.
 * Geçersiz (http(s) olmayan) adresler atlanır; etiketler metin ya da { name } olabilir.
 */
export function parseBackup(raw: unknown): BackupItem[] {
  const list = Array.isArray(raw)
    ? raw
    : raw && typeof raw === "object" && Array.isArray((raw as { clips?: unknown }).clips)
      ? (raw as { clips: unknown[] }).clips
      : null;
  if (!list) throw new Error("Yedek dosyası bir kayıt listesi içermiyor.");

  const items: BackupItem[] = [];
  for (const entry of list) {
    if (!entry || typeof entry !== "object") continue;
    const e = entry as Record<string, unknown>;
    const url = normalizeHttpUrl(e.url);
    if (!url) continue;
    const created = typeof e.createdAt === "string" && !isNaN(Date.parse(e.createdAt)) ? e.createdAt : null;
    const tags = Array.isArray(e.tags)
      ? e.tags
          .map((t) => normalizeTagName(typeof t === "string" ? t : String((t as { name?: unknown })?.name ?? "")))
          .filter(Boolean)
      : [];
    const highlights = Array.isArray(e.highlights)
      ? e.highlights.flatMap((h) => {
          const text = str((h as { text?: unknown })?.text, 5000);
          return text ? [{ text, note: str((h as { note?: unknown }).note, 2000) }] : [];
        })
      : [];
    items.push({
      url,
      title: str(e.title, 500) ?? url,
      excerpt: str(e.excerpt, 2000),
      content: typeof e.content === "string" && e.content.trim() ? e.content : null,
      domain: str(e.domain, 255),
      isRead: e.isRead === true,
      isStarred: e.isStarred === true,
      tags: [...new Set(tags)],
      highlights,
      createdAt: created ?? new Date().toISOString(),
    });
  }
  return items;
}
