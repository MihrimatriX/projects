export function extractDomain(url: string): string | null {
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return null;
  }
}

export function formatRelativeDate(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

  if (diffDays === 0) return "bugün";
  if (diffDays === 1) return "dün";
  if (diffDays < 7) return `${diffDays} gün önce`;
  if (diffDays < 30) return `${Math.floor(diffDays / 7)} hafta önce`;
  return date.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
}

export function estimateReadingMinutes(text: string): number {
  const words = text.trim().split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.ceil(words / 200));
}

export function normalizeTagName(name: string): string {
  return name.trim().toLowerCase().slice(0, 32);
}

/** Yalnızca http(s) adresleri kabul edilir: javascript:/data:/file: bağlantıları kaydedilip tıklanamaz. */
export function normalizeHttpUrl(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const value = raw.trim();
  try {
    // Adres olduğu gibi saklanır (mükerrer kontrolü mevcut kayıtlarla aynı metni karşılaştırır)
    const { protocol } = new URL(value);
    return protocol === "http:" || protocol === "https:" ? value : null;
  } catch {
    return null;
  }
}

/** Sunucunun kendi ağına (localhost, özel IP aralıkları) istek atmasını engellemek için. */
export function isPrivateHost(hostname: string): boolean {
  const h = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (h === "localhost" || h.endsWith(".localhost") || h.endsWith(".local")) return true;
  if (/^(127|10|0)\./.test(h) || /^192\.168\./.test(h) || /^169\.254\./.test(h)) return true;
  if (/^172\.(1[6-9]|2\d|3[01])\./.test(h)) return true;
  // IPv6: loopback, belirtilmemiş, link-local, unique-local
  if (h === "::1" || h === "::" || /^fe80:/.test(h) || /^f[cd][0-9a-f]{2}:/.test(h)) return true;
  return false;
}
