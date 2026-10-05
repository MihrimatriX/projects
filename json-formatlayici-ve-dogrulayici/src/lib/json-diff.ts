export type DiffKind = "added" | "removed" | "changed" | "unchanged";

export interface DiffEntry {
  path: string;
  kind: DiffKind;
  before?: unknown;
  after?: unknown;
}

export function diffJson(left: unknown, right: unknown, basePath = "$"): DiffEntry[] {
  const entries: DiffEntry[] = [];

  if (left === right) {
    if (typeof left !== "object" || left === null) {
      entries.push({ path: basePath, kind: "unchanged", before: left, after: right });
    }
    return entries;
  }

  const leftIsObj = left !== null && typeof left === "object";
  const rightIsObj = right !== null && typeof right === "object";

  if (!leftIsObj || !rightIsObj) {
    entries.push({ path: basePath, kind: "changed", before: left, after: right });
    return entries;
  }

  if (Array.isArray(left) && Array.isArray(right)) {
    const max = Math.max(left.length, right.length);
    for (let i = 0; i < max; i++) {
      const p = `${basePath}[${i}]`;
      if (i >= left.length) {
        entries.push({ path: p, kind: "added", after: right[i] });
      } else if (i >= right.length) {
        entries.push({ path: p, kind: "removed", before: left[i] });
      } else {
        entries.push(...diffJson(left[i], right[i], p));
      }
    }
    return entries;
  }

  if (Array.isArray(left) !== Array.isArray(right)) {
    entries.push({ path: basePath, kind: "changed", before: left, after: right });
    return entries;
  }

  const leftObj = left as Record<string, unknown>;
  const rightObj = right as Record<string, unknown>;
  const keys = new Set([...Object.keys(leftObj), ...Object.keys(rightObj)]);

  for (const key of keys) {
    const p = `${basePath}.${key}`;
    if (!(key in leftObj)) {
      entries.push({ path: p, kind: "added", after: rightObj[key] });
    } else if (!(key in rightObj)) {
      entries.push({ path: p, kind: "removed", before: leftObj[key] });
    } else {
      entries.push(...diffJson(leftObj[key], rightObj[key], p));
    }
  }

  return entries;
}

/**
 * Satir bazli LCS farki: soldan silinen ve saga eklenen satir indeksleri.
 * ponytail: O(n*m) bellek; 4M hucre ustunde vurgu yapilmaz (bos kume), gerekirse Myers algoritmasina gecilir.
 */
export function lineDiff(a: string[], b: string[]): { removed: Set<number>; added: Set<number> } {
  const removed = new Set<number>();
  const added = new Set<number>();
  const n = a.length;
  const m = b.length;
  if (n * m > 4_000_000) return { removed, added };
  const dp = Array.from({ length: n + 1 }, () => new Uint32Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      dp[i][j] = a[i] === b[j] ? dp[i + 1][j + 1] + 1 : Math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) {
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) removed.add(i++);
    else added.add(j++);
  }
  while (i < n) removed.add(i++);
  while (j < m) added.add(j++);
  return { removed, added };
}

export function summarizeDiff(entries: DiffEntry[]) {
  const meaningful = entries.filter((e) => e.kind !== "unchanged");
  return {
    added: meaningful.filter((e) => e.kind === "added").length,
    removed: meaningful.filter((e) => e.kind === "removed").length,
    changed: meaningful.filter((e) => e.kind === "changed").length,
    total: meaningful.length,
  };
}
