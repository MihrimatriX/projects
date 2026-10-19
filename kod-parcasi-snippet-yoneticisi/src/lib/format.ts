import type { Snippet } from "../types";

const LANG_COLORS: Record<string, string> = {
  ts: "ts",
  typescript: "ts",
  js: "ts",
  javascript: "ts",
  rs: "rs",
  rust: "rs",
  py: "py",
  python: "py",
};

export function langBadgeClass(language: string): string {
  const key = language.trim().toLowerCase();
  return LANG_COLORS[key] ?? "default";
}

export function langBadgeLabel(language: string): string {
  const t = language.trim();
  if (!t) return "??";
  return t.slice(0, 2).toUpperCase();
}

export function codePreview(code: string, max = 60): string {
  const line = code.split("\n").find((l) => l.trim()) ?? "";
  return line.length > max ? `${line.slice(0, max)}…` : line;
}

export function formatRelativeDate(iso?: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "—";

  const now = new Date();
  const startToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startDate = new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const diffDays = Math.round((startToday.getTime() - startDate.getTime()) / 86400000);

  const time = d.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  if (diffDays === 0) return `bugün ${time}`;
  if (diffDays === 1) return `dün ${time}`;
  return d.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
}

export function collectTags(snippets: Snippet[]): string[] {
  const set = new Set<string>();
  for (const s of snippets) {
    for (const t of s.tags) {
      const tag = t.trim();
      if (tag) set.add(tag);
    }
  }
  return [...set].sort((a, b) => a.localeCompare(b, "tr"));
}

export function collectFolders(snippets: Snippet[]): string[] {
  const set = new Set<string>();
  for (const s of snippets) {
    const f = s.folder?.trim();
    if (f) set.add(f);
  }
  return [...set].sort((a, b) => a.localeCompare(b, "tr"));
}

export function parseTags(raw: string): string[] {
  return raw
    .split(",")
    .map((t) => t.trim().replace(/^#/, ""))
    .filter(Boolean);
}

export function tagsToInput(tags: string[]): string {
  return tags.map((t) => (t.startsWith("#") ? t : `#${t}`)).join(", ");
}

/** Başlık, açıklama, kod, dil, klasör ve etiketlerde Türkçe büyük/küçük harf duyarsız arama. */
export function matchesQuery(s: Snippet, query: string): boolean {
  const q = query.trim().toLocaleLowerCase("tr");
  if (!q) return true;
  const has = (v: string | undefined) => (v ?? "").toLocaleLowerCase("tr").includes(q);
  return (
    has(s.title) ||
    has(s.description) ||
    has(s.code) ||
    has(s.language) ||
    has(s.folder) ||
    s.tags.some(has)
  );
}

/** ipcMain.handle hatalarındaki "Error invoking remote method '...': Error:" önekini atar. */
export function ipcErrorMessage(err: unknown): string {
  const msg = err instanceof Error ? err.message : String(err);
  return msg.replace(/^Error invoking remote method '[^']+': (?:\w*Error: )?/, "");
}

/**
 * İçe aktarma önizlemesi: JSON'u doğrular ve snippet/etiket/klasör sayılarını döner. Ana süreçteki
 * normalizeSnippet gibi eksik ya da yanlış tipli alanlara dayanıklıdır (etiketsiz kayıt hata vermez).
 */
export function summarizeImport(raw: string): { snippets: number; tags: number; folders: number } {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw.replace(/^\uFEFF/, ""));
  } catch {
    throw new Error("Dosya geçerli bir JSON değil.");
  }
  if (!Array.isArray(parsed)) throw new Error("JSON bir snippet dizisi olmalı ([ {...}, ... ]).");
  const items = (parsed as Partial<Snippet>[])
    .filter((s) => !!s && typeof s === "object")
    .map((s) => ({ ...s, tags: Array.isArray(s.tags) ? s.tags.map(String) : [], folder: String(s.folder ?? "") }));
  return {
    snippets: items.length,
    tags: collectTags(items as Snippet[]).length,
    folders: collectFolders(items as Snippet[]).length,
  };
}
