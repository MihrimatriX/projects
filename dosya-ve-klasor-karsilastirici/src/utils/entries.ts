import type { FileEntry } from "../types";

/** Klasör ağacı filtresi: "yalnızca farklar" + yol içinde büyük/küçük harf duyarsız arama. */
export function filterEntries(entries: FileEntry[], onlyDiff: boolean, query: string): FileEntry[] {
  const q = query.trim().toLocaleLowerCase("tr");
  return entries.filter(
    (e) =>
      (!onlyDiff || e.status !== "identical") &&
      (!q || e.relativePath.toLocaleLowerCase("tr").includes(q))
  );
}
