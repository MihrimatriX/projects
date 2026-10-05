import crypto from "crypto";
import { diffLines } from "diff";
import fs from "fs";
import path from "path";
import { fileHashCached, loadRootCache, saveRootCache } from "./hashCache";
import { mergeIgnoreDirs } from "./gitignoreParser";

export type FileStatus = "identical" | "different" | "left_only" | "right_only";

export type FileEntry = {
  relativePath: string;
  status: FileStatus;
};

export type CompareResult = {
  mode: "folder";
  entries: FileEntry[];
  leftCount: number;
  rightCount: number;
  leftRoot: string;
  rightRoot: string;
  /** MAX_FILES sınırına ulaşıldı: liste eksik, "yalnızca sol/sağ" sonuçları yanıltıcı olabilir. */
  truncated: boolean;
  cacheHit?: boolean;
};

export type DiffStats = {
  additions: number;
  deletions: number;
};

export const DEFAULT_IGNORE = [
  "node_modules",
  ".git",
  "dist",
  "build",
  "__pycache__",
  ".dart_tool",
  "target",
  ".venv",
  "venv",
];

export const MAX_FILES = 8000;
export const MAX_TEXT_BYTES = 4 * 1024 * 1024;

export function shouldIgnoreDir(name: string, extraIgnore: string[] = []): boolean {
  if (name.startsWith(".") && name !== ".") return true;
  const all = [...DEFAULT_IGNORE, ...extraIgnore];
  return all.includes(name);
}

export function listFiles(root: string, limit = MAX_FILES, extraIgnore: string[] = []): string[] {
  const files: string[] = [];

  function walk(dir: string) {
    if (files.length >= limit) return;
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (entry.isDirectory()) {
        if (shouldIgnoreDir(entry.name, extraIgnore)) continue;
        walk(path.join(dir, entry.name));
      } else if (entry.isFile()) {
        // Nokta ile başlayan dosyalar (.gitignore, .env.example...) da karşılaştırılır; gizli klasörler shouldIgnoreDir'de elenir.
        files.push(path.relative(root, path.join(dir, entry.name)).replace(/\\/g, "/"));
        if (files.length >= limit) return;
      }
    }
  }

  walk(root);
  return files.sort();
}

export function fileHash(root: string, rel: string): string {
  const buf = fs.readFileSync(path.join(root, rel));
  return crypto.createHash("md5").update(buf).digest("hex");
}

export type CompareProgress = {
  phase: "hashing";
  current: number;
  total: number;
};

export type CompareOptions = {
  useGitignore?: boolean;
  onProgress?: (p: CompareProgress) => void;
};

export function compareFolders(
  left: string,
  right: string,
  extraIgnore: string[] = [],
  options: CompareOptions = {}
): CompareResult {
  const ignore = mergeIgnoreDirs(
    extraIgnore,
    left,
    right,
    options.useGitignore !== false
  );
  const leftFiles = new Set(listFiles(left, MAX_FILES, ignore));
  const rightFiles = new Set(listFiles(right, MAX_FILES, ignore));
  const truncated = leftFiles.size >= MAX_FILES || rightFiles.size >= MAX_FILES;
  const entries: FileEntry[] = [];

  for (const rel of leftFiles) {
    if (!rightFiles.has(rel)) entries.push({ relativePath: rel, status: "left_only" });
  }
  for (const rel of rightFiles) {
    if (!leftFiles.has(rel)) entries.push({ relativePath: rel, status: "right_only" });
  }
  const common = [...leftFiles].filter((f) => rightFiles.has(f));
  const leftCache = loadRootCache(left);
  const rightCache = loadRootCache(right);

  common.forEach((rel, index) => {
    options.onProgress?.({ phase: "hashing", current: index + 1, total: common.length });
    try {
      const lh = fileHashCached(left, rel, leftCache);
      const rh = fileHashCached(right, rel, rightCache);
      entries.push({
        relativePath: rel,
        status: lh === rh ? "identical" : "different",
      });
    } catch {
      entries.push({ relativePath: rel, status: "different" });
    }
  });

  saveRootCache(left, leftCache);
  saveRootCache(right, rightCache);

  entries.sort((a, b) => a.relativePath.localeCompare(b.relativePath));

  return {
    mode: "folder",
    entries,
    leftCount: leftFiles.size,
    rightCount: rightFiles.size,
    leftRoot: left,
    rightRoot: right,
    truncated,
    cacheHit: common.length > 0,
  };
}

export function isBinaryBuffer(buf: Buffer): boolean {
  const sample = buf.subarray(0, Math.min(buf.length, 8192));
  return sample.includes(0);
}

export function readTextFile(filePath: string): { content: string; binary: boolean; truncated: boolean } {
  const stat = fs.statSync(filePath);
  const truncated = stat.size > MAX_TEXT_BYTES;
  const readLen = Math.min(stat.size, MAX_TEXT_BYTES);
  const fd = fs.openSync(filePath, "r");
  const buf = Buffer.alloc(readLen);
  fs.readSync(fd, buf, 0, readLen, 0);
  fs.closeSync(fd);
  if (isBinaryBuffer(buf)) {
    return { content: "", binary: true, truncated: false };
  }
  return { content: buf.toString("utf8"), binary: false, truncated };
}

// Satır bazlı +/− sayımı: `diff` paketinin Myers algoritması (O(N·D)).
// Önceki LCS tablosu O(m·n) bellek ayırıyordu; birkaç bin satırlık dosyada main süreci çöküyordu.
export function diffStats(left: string, right: string): DiffStats {
  let additions = 0;
  let deletions = 0;
  for (const part of diffLines(left, right)) {
    if (part.added) additions += part.count ?? 0;
    else if (part.removed) deletions += part.count ?? 0;
  }
  return { additions, deletions };
}

export function resolvePaths(
  left: string,
  right: string,
  relativePath?: string
): { leftPath: string; rightPath: string } {
  const leftStat = fs.statSync(left);
  const rightStat = fs.statSync(right);
  if (leftStat.isFile() && rightStat.isFile()) {
    return { leftPath: left, rightPath: right };
  }
  if (!relativePath) throw new Error("Dosya yolu gerekli");
  return {
    leftPath: path.join(left, relativePath),
    rightPath: path.join(right, relativePath),
  };
}

export function detectLanguage(filePath: string): string {
  const ext = path.extname(filePath).toLowerCase();
  const map: Record<string, string> = {
    ".ts": "typescript",
    ".tsx": "typescript",
    ".js": "javascript",
    ".jsx": "javascript",
    ".json": "json",
    ".md": "markdown",
    ".html": "html",
    ".css": "css",
    ".scss": "scss",
    ".xml": "xml",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".py": "python",
    ".rs": "rust",
    ".go": "go",
    ".cs": "csharp",
    ".java": "java",
    ".sql": "sql",
    ".sh": "shell",
    ".ps1": "powershell",
  };
  return map[ext] ?? "plaintext";
}

/** Hedef varsa ve istenirse önce `.bak` yedeği alır, sonra yazar. backupPath yalnızca bu çağrıda yedek alındıysa dolu. */
export function writeWithBackup(
  outputPath: string,
  content: string,
  createBackup = true
): { outputPath: string; backupPath: string | null } {
  let backupPath: string | null = null;
  if (fs.existsSync(outputPath)) {
    if (createBackup) {
      backupPath = `${outputPath}.bak`;
      fs.copyFileSync(outputPath, backupPath);
    }
  } else {
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  }
  fs.writeFileSync(outputPath, content, "utf8");
  return { outputPath, backupPath };
}

export function mergeCopy(
  sourcePath: string,
  targetPath: string,
  createBackup = true
): { backupPath: string | null } {
  if (!fs.existsSync(sourcePath)) throw new Error(`Kaynak bulunamadı: ${sourcePath}`);
  let backupPath: string | null = null;
  if (fs.existsSync(targetPath)) {
    if (createBackup) {
      backupPath = `${targetPath}.bak`;
      fs.copyFileSync(targetPath, backupPath);
    }
  } else {
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  }
  fs.copyFileSync(sourcePath, targetPath);
  return { backupPath };
}
