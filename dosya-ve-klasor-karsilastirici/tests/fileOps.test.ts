import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { compareFolders, mergeCopy, readTextFile, writeWithBackup } from "../electron/compareLogic";
import { filterEntries } from "../src/utils/entries";

describe("dosya işlemleri", () => {
  let tmp: string;
  let left: string;
  let right: string;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), "fileops-"));
    left = path.join(tmp, "left");
    right = path.join(tmp, "right");
    fs.mkdirSync(left);
    fs.mkdirSync(right);
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it("nokta ile başlayan dosyaları karşılaştırır, gizli klasörleri atlar", () => {
    fs.writeFileSync(path.join(left, ".env.example"), "A=1");
    fs.writeFileSync(path.join(right, ".env.example"), "A=2");
    fs.mkdirSync(path.join(left, ".cache"));
    fs.writeFileSync(path.join(left, ".cache", "x.bin"), "x");
    const result = compareFolders(left, right);
    expect(result.entries).toEqual([{ relativePath: ".env.example", status: "different" }]);
    expect(result.truncated).toBe(false);
  });

  it(".gitignore dizinlerini ayara göre atlar", () => {
    fs.writeFileSync(path.join(left, ".gitignore"), "out/\n");
    fs.writeFileSync(path.join(right, ".gitignore"), "out/\n");
    fs.mkdirSync(path.join(left, "out"));
    fs.writeFileSync(path.join(left, "out", "a.js"), "1");
    const paths = (o: boolean) =>
      compareFolders(left, right, [], { useGitignore: o }).entries.map((e) => e.relativePath);
    expect(paths(true)).not.toContain("out/a.js");
    expect(paths(false)).toContain("out/a.js");
  });

  it("yalnızca solda olan dosyayı alt klasörüyle sağa kopyalar (yedek yok)", () => {
    fs.mkdirSync(path.join(left, "sub"));
    fs.writeFileSync(path.join(left, "sub", "only.txt"), "merhaba");
    const { backupPath } = mergeCopy(path.join(left, "sub", "only.txt"), path.join(right, "sub", "only.txt"));
    expect(backupPath).toBeNull();
    expect(fs.readFileSync(path.join(right, "sub", "only.txt"), "utf8")).toBe("merhaba");
    expect(compareFolders(left, right).entries[0].status).toBe("identical");
  });

  it("binary dosyayı algılar ve bayt bayt kopyalar", () => {
    const bin = Buffer.from([0, 1, 2, 255]);
    fs.writeFileSync(path.join(left, "a.bin"), bin);
    expect(readTextFile(path.join(left, "a.bin")).binary).toBe(true);
    mergeCopy(path.join(left, "a.bin"), path.join(right, "a.bin"));
    expect(fs.readFileSync(path.join(right, "a.bin")).equals(bin)).toBe(true);
  });

  it("writeWithBackup yalnızca istenince ve hedef varsa yedek alır", () => {
    const out = path.join(tmp, "nested", "merged.txt");
    expect(writeWithBackup(out, "v1").backupPath).toBeNull();
    const second = writeWithBackup(out, "v2");
    expect(second.backupPath).toBe(`${out}.bak`);
    expect(fs.readFileSync(`${out}.bak`, "utf8")).toBe("v1");
    // Eski .bak dosyası varken yedeksiz yazımda yanlışlıkla yedek bildirilmemeli.
    expect(writeWithBackup(out, "v3", false).backupPath).toBeNull();
    expect(fs.readFileSync(out, "utf8")).toBe("v3");
    expect(fs.readFileSync(`${out}.bak`, "utf8")).toBe("v1");
  });
});

describe("filterEntries", () => {
  const entries = [
    { relativePath: "src/App.tsx", status: "different" as const },
    { relativePath: "src/İkon.svg", status: "identical" as const },
    { relativePath: "README.md", status: "left_only" as const },
  ];

  it("varsayılan olarak aynı dosyaları gizler", () => {
    expect(filterEntries(entries, true, "").map((e) => e.relativePath)).toEqual(["src/App.tsx", "README.md"]);
    expect(filterEntries(entries, false, "")).toHaveLength(3);
  });

  it("yolda büyük/küçük harf duyarsız (Türkçe) arar", () => {
    expect(filterEntries(entries, false, "  ikon ").map((e) => e.relativePath)).toEqual(["src/İkon.svg"]);
    expect(filterEntries(entries, true, "SRC")).toHaveLength(1);
  });
});
