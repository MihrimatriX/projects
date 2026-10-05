import crypto from "crypto";
import fs from "fs";
import path from "path";
import { settingsDir } from "./settingsStore";

export type CacheEntry = { mtimeMs: number; size: number; hash: string };
export type RootCache = Record<string, CacheEntry>;

function cacheDir(): string {
  const dir = path.join(settingsDir(), "hash-cache");
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

function cachePath(root: string): string {
  const id = crypto.createHash("sha256").update(path.resolve(root)).digest("hex").slice(0, 16);
  return path.join(cacheDir(), `${id}.json`);
}

export function loadRootCache(root: string): RootCache {
  try {
    return JSON.parse(fs.readFileSync(cachePath(root), "utf8")) as RootCache;
  } catch {
    return {};
  }
}

export function saveRootCache(root: string, cache: RootCache): void {
  fs.writeFileSync(cachePath(root), JSON.stringify(cache), "utf8");
}

/** mtime+size eşleşirse önbellekten MD5 döner; aksi halde okur ve günceller. */
export function fileHashCached(root: string, rel: string, cache: RootCache): string {
  const full = path.join(root, rel);
  const stat = fs.statSync(full);
  const hit = cache[rel];
  if (hit && hit.mtimeMs === stat.mtimeMs && hit.size === stat.size) {
    return hit.hash;
  }
  const buf = fs.readFileSync(full);
  const hash = crypto.createHash("md5").update(buf).digest("hex");
  cache[rel] = { mtimeMs: stat.mtimeMs, size: stat.size, hash };
  return hash;
}

export function clearCacheForRoot(root: string): void {
  const p = cachePath(root);
  if (fs.existsSync(p)) fs.unlinkSync(p);
}

/** Tüm kökler için hash önbelleğini siler (Ayarlar > Önbelleği temizle). */
export function clearAllCaches(): void {
  fs.rmSync(cacheDir(), { recursive: true, force: true });
}
