import fs from "fs";
import path from "path";

/** Basit .gitignore: dizin adları ve kök segmentler (glob karmaşık desenler atlanır). */
export function parseGitignoreContent(content: string): string[] {
  const dirs = new Set<string>();
  for (const line of content.split("\n")) {
    let t = line.trim();
    if (!t || t.startsWith("#")) continue;
    if (t.startsWith("!")) continue;
    t = t.replace(/^\//, "").replace(/\/$/, "");
    const segment = t.split("/")[0];
    if (!segment || segment.includes("*") || segment.includes("?") || segment.includes("[")) {
      continue;
    }
    dirs.add(segment);
  }
  return [...dirs];
}

export function loadGitignoreDirs(root: string): string[] {
  const file = path.join(root, ".gitignore");
  if (!fs.existsSync(file)) return [];
  try {
    return parseGitignoreContent(fs.readFileSync(file, "utf8"));
  } catch {
    return [];
  }
}

export function mergeIgnoreDirs(
  extraIgnore: string[],
  leftRoot?: string,
  rightRoot?: string,
  useGitignore = true
): string[] {
  const merged = new Set(extraIgnore);
  if (useGitignore) {
    if (leftRoot) for (const d of loadGitignoreDirs(leftRoot)) merged.add(d);
    if (rightRoot) for (const d of loadGitignoreDirs(rightRoot)) merged.add(d);
  }
  return [...merged];
}
