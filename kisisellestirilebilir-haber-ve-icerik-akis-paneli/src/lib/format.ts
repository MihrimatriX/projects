const COLORS = ["#e03131", "#1971c2", "#bb1919", "#24292f", "#2f9e44", "#ae3ec9", "#f76707"];

export function feedInitial(title: string): string {
  const t = title.trim();
  return (t[0] ?? "?").toUpperCase();
}

export function feedColor(title: string): string {
  let hash = 0;
  for (let i = 0; i < title.length; i++) {
    hash = title.charCodeAt(i) + ((hash << 5) - hash);
  }
  return COLORS[Math.abs(hash) % COLORS.length];
}

export function formatRelative(dateStr: string | Date): string {
  try {
    const date = dateStr instanceof Date ? dateStr : new Date(dateStr);
    const diffMs = Date.now() - date.getTime();
    const mins = Math.floor(diffMs / 60000);
    if (mins < 60) return `${Math.max(1, mins)} dk önce`;
    const hours = Math.floor(mins / 60);
    if (hours < 24) return `${hours} saat önce`;
    return date.toLocaleDateString("tr-TR", { day: "numeric", month: "short", year: "numeric" });
  } catch {
    return "";
  }
}

export function formatSyncTime(dateStr: string | Date | null | undefined): string {
  if (!dateStr) return "—";
  try {
    const d = dateStr instanceof Date ? dateStr : new Date(dateStr);
    return d.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  } catch {
    return "—";
  }
}

export function readingMinutes(html: string): number {
  const text = html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
  const words = text ? text.split(" ").length : 0;
  return Math.max(1, Math.round(words / 200));
}

export function hostFromUrl(url: string | null | undefined): string {
  if (!url) return "";
  try {
    return new URL(url).host.replace(/^www\./, "");
  } catch {
    return url;
  }
}

export function filterLabel(filter: {
  feedId?: string;
  folder?: string;
  status?: string;
}, feeds: { id: string; title: string; folder: string }[]): string {
  if (filter.feedId) {
    return feeds.find((f) => f.id === filter.feedId)?.title ?? "Feed";
  }
  if (filter.folder) return filter.folder;
  if (filter.status === "starred") return "Yıldızlı";
  if (filter.status === "all") return "Tüm akış";
  return "Okunmamış";
}

/** Yenileme sonucu icin kullaniciya gosterilecek ozet (cevrimdisi/hatali feedler dahil). */
export function syncMessage(res: {
  success: boolean;
  count: number;
  failed: { title: string; error: string }[];
}): string {
  if (!res.success) return "Senkron başarısız oldu.";
  const added = res.count > 0 ? `${res.count} yeni makale` : "Yeni makale yok";
  if (res.failed.length === 0) return `Senkron tamamlandı · ${added}`;
  const first = res.failed[0];
  const more = res.failed.length > 1 ? ` (+${res.failed.length - 1} akış daha)` : "";
  return `${added} · ${first.title} güncellenemedi: ${first.error}${more}`;
}

export function importMessage(count: number, failed: number): string {
  if (failed === 0) return `${count} feed içe aktarıldı`;
  return `${count} feed içe aktarıldı, ${failed} feed indirilemedi (sonraki yenilemede tekrar denenir)`;
}
