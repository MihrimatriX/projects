import fs from "fs";
import path from "path";
import { matchesQuery } from "../src/lib/format";

export type Snippet = {
  id: string;
  title: string;
  description: string;
  language: string;
  tags: string[];
  folder: string;
  code: string;
  createdAt: string;
  updatedAt: string;
  lastUsedAt: string | null;
};

export function normalizeSnippet(s: Partial<Snippet> & { id: string }): Snippet {
  return {
    id: String(s.id),
    title: String(s.title ?? "Başlıksız").trim() || "Başlıksız",
    description: String(s.description ?? ""),
    language: String(s.language ?? "text"),
    tags: Array.isArray(s.tags) ? s.tags.map(String) : [],
    folder: String(s.folder ?? ""),
    code: String(s.code ?? ""),
    createdAt: s.createdAt ?? new Date().toISOString(),
    updatedAt: s.updatedAt ?? new Date().toISOString(),
    lastUsedAt: s.lastUsedAt ?? null,
  };
}

/**
 * Dosya yoksa boş liste. Dosya bozuksa (geçersiz JSON / dizi değil) boş liste döner ama önce dosyayı
 * `snippets.corrupt-<zaman>.json` olarak kenara alır; aksi halde ilk kayıt tüm kütüphanenin üzerine yazardı.
 */
export function loadSnippets(file: string): Snippet[] {
  let raw: string;
  try {
    raw = fs.readFileSync(file, "utf8");
  } catch {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) throw new Error("dizi değil");
    return parsed
      .filter((s): s is Partial<Snippet> & { id: string } => !!s && typeof s === "object" && "id" in s)
      .map(normalizeSnippet);
  } catch {
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    fs.renameSync(file, path.join(path.dirname(file), `snippets.corrupt-${stamp}.json`));
    return [];
  }
}

/** Geçici dosyaya yazıp yeniden adlandırır: yazma yarıda kesilirse eski dosya sağlam kalır. */
export function saveSnippets(file: string, snippets: Snippet[]): void {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = `${file}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(snippets, null, 2), "utf8");
  fs.renameSync(tmp, file);
}

export function parseImportJson(raw: string): Partial<Snippet>[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw.replace(/^﻿/, ""));
  } catch {
    throw new Error("Dosya geçerli bir JSON değil.");
  }
  if (!Array.isArray(parsed)) throw new Error("JSON bir snippet dizisi olmalı ([ {...}, ... ]).");
  return parsed.filter((s): s is Partial<Snippet> => !!s && typeof s === "object");
}

/** Var olan id'ler atlanır (üzerine yazılmaz); id'siz kayıtlara yeni id verilir. Eklenen sayıyı döner. */
export function mergeImport(file: string, incoming: Partial<Snippet>[]): number {
  const byId = new Map(loadSnippets(file).map((s) => [s.id, s]));
  let imported = 0;
  incoming.forEach((s, i) => {
    const item = normalizeSnippet({ ...s, id: s.id ? String(s.id) : `import-${Date.now()}-${i}` });
    if (!byId.has(item.id)) {
      byId.set(item.id, item);
      imported++;
    }
  });
  saveSnippets(file, Array.from(byId.values()));
  return imported;
}

export function searchSnippets(snippets: Snippet[], query: string): Snippet[] {
  return snippets.filter((s) => matchesQuery(s, query));
}
