export type MergeConflict = {
  index: number;
  base: string;
  left: string;
  right: string;
};

export type ThreeWayResult = {
  merged: string;
  conflicts: MergeConflict[];
  autoResolved: number;
};

// Satır numarasına göre (hizalamasız) 3 yönlü birleştirme: tek taraf base'den ayrıldıysa o taraf alınır,
// iki taraf da farklı değiştirdiyse çakışma sayılır. Satır ekleme/silme kaymaları çakışma üretir.
export function threeWayMerge(
  base: string,
  left: string,
  right: string
): ThreeWayResult {
  const baseLines = base.split("\n");
  const leftLines = left.split("\n");
  const rightLines = right.split("\n");
  const maxLen = Math.max(baseLines.length, leftLines.length, rightLines.length);
  const merged: string[] = [];
  const conflicts: MergeConflict[] = [];
  let autoResolved = 0;

  for (let i = 0; i < maxLen; i++) {
    const b = baseLines[i] ?? "";
    const l = leftLines[i] ?? "";
    const r = rightLines[i] ?? "";

    if (l === r) {
      merged.push(l);
      if (l !== b) autoResolved++;
      continue;
    }
    if (l === b) {
      merged.push(r);
      autoResolved++;
      continue;
    }
    if (r === b) {
      merged.push(l);
      autoResolved++;
      continue;
    }
    conflicts.push({ index: i + 1, base: b, left: l, right: r });
    merged.push(l);
  }

  return { merged: merged.join("\n"), conflicts, autoResolved };
}

export function applyConflictResolutions(
  base: string,
  left: string,
  right: string,
  resolutions: Record<number, "left" | "right" | "base" | "both">
): string {
  const baseLines = base.split("\n");
  const leftLines = left.split("\n");
  const rightLines = right.split("\n");
  const maxLen = Math.max(baseLines.length, leftLines.length, rightLines.length);
  const merged: string[] = [];

  for (let i = 0; i < maxLen; i++) {
    const res = resolutions[i + 1];
    const l = leftLines[i] ?? "";
    const r = rightLines[i] ?? "";
    const b = baseLines[i] ?? "";
    if (res === "left") merged.push(l);
    else if (res === "right") merged.push(r);
    else if (res === "base") merged.push(b);
    else if (res === "both") merged.push(`${l}\n${r}`);
    else merged.push(l === r ? l : l !== b ? l : r);
  }
  return merged.join("\n");
}
