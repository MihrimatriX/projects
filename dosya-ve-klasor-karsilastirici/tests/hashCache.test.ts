import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { clearAllCaches, fileHashCached, loadRootCache, saveRootCache } from "../electron/hashCache";

describe("hashCache", () => {
  let tmp: string;
  let root: string;
  const realLocal = process.env.LOCALAPPDATA;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), "hash-cache-"));
    // Önbellek dosyaları kullanıcının gerçek profiline yazılmasın.
    process.env.LOCALAPPDATA = path.join(tmp, "local");
    root = path.join(tmp, "proj");
    fs.mkdirSync(root);
    fs.writeFileSync(path.join(root, "a.txt"), "v1");
  });

  afterEach(() => {
    process.env.LOCALAPPDATA = realLocal;
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it("caches hash by mtime", () => {
    const cache = loadRootCache(root);
    const h1 = fileHashCached(root, "a.txt", cache);
    const h2 = fileHashCached(root, "a.txt", cache);
    expect(h1).toBe(h2);
    fs.writeFileSync(path.join(root, "a.txt"), "v2");
    const cache2 = loadRootCache(root);
    const h3 = fileHashCached(root, "a.txt", cache2);
    expect(h3).not.toBe(h1);
    saveRootCache(root, cache2);
  });

  it("clearAllCaches removes every saved root cache", () => {
    const cache = loadRootCache(root);
    fileHashCached(root, "a.txt", cache);
    saveRootCache(root, cache);
    expect(Object.keys(loadRootCache(root))).toEqual(["a.txt"]);
    clearAllCaches();
    expect(loadRootCache(root)).toEqual({});
  });
});
