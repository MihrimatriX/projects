import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  loadSnippets,
  mergeImport,
  normalizeSnippet,
  parseImportJson,
  saveSnippets,
  searchSnippets,
} from "../electron/snippetStore";

describe("snippetStore", () => {
  let dir: string;
  let file: string;

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), "snip-"));
    file = path.join(dir, "snippets.json");
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it("dosya yoksa boş liste, kaydet/oku turu veriyi korur", () => {
    expect(loadSnippets(file)).toEqual([]);
    const s = normalizeSnippet({ id: "1", title: "  Merhaba ", tags: ["a"], code: "x" });
    saveSnippets(file, [s]);
    expect(loadSnippets(file)).toEqual([{ ...s, title: "Merhaba" }]);
    expect(fs.existsSync(`${file}.tmp`)).toBe(false);
  });

  it("bozuk dosyayı silmez, kenara alır", () => {
    fs.writeFileSync(file, "{ yarim json");
    expect(loadSnippets(file)).toEqual([]);
    expect(fs.existsSync(file)).toBe(false);
    const backups = fs.readdirSync(dir).filter((f) => f.startsWith("snippets.corrupt-"));
    expect(backups).toHaveLength(1);
    expect(fs.readFileSync(path.join(dir, backups[0]), "utf8")).toBe("{ yarim json");
  });

  it("normalizeSnippet eksik alanları doldurur", () => {
    const s = normalizeSnippet({ id: "x", tags: "bozuk" as unknown as string[] });
    expect(s.title).toBe("Başlıksız");
    expect(s.tags).toEqual([]);
    expect(s.language).toBe("text");
    expect(s.lastUsedAt).toBeNull();
  });

  it("içe aktarma var olan id'leri atlar, id'siz kayda id verir", () => {
    saveSnippets(file, [normalizeSnippet({ id: "a", title: "Eski" })]);
    const n = mergeImport(file, [{ id: "a", title: "Yeni" }, { title: "İdsiz" }, { id: "b", title: "B" }]);
    expect(n).toBe(2);
    const all = loadSnippets(file);
    expect(all.find((s) => s.id === "a")?.title).toBe("Eski");
    expect(all.map((s) => s.title).sort()).toEqual(["B", "Eski", "İdsiz"]);
  });

  it("parseImportJson geçersiz girdiye Türkçe hata verir, BOM'u tolere eder", () => {
    expect(() => parseImportJson("nope")).toThrow("geçerli bir JSON değil");
    expect(() => parseImportJson('{"a":1}')).toThrow("dizisi olmalı");
    expect(parseImportJson('﻿[{"id":"1"}, null, 5]')).toEqual([{ id: "1" }]);
  });

  it("arama başlık, kod, etiket ve klasörde Türkçe harf duyarsız çalışır", () => {
    const list = [
      normalizeSnippet({ id: "1", title: "İstek gönder", code: "fetch(url)", tags: ["http"] }),
      normalizeSnippet({ id: "2", title: "Liste", code: "arr.map(x => x)", folder: "Diziler" }),
    ];
    const ids = (q: string) => searchSnippets(list, q).map((s) => s.id);
    expect(ids("istek")).toEqual(["1"]);
    expect(ids("FETCH")).toEqual(["1"]);
    expect(ids("http")).toEqual(["1"]);
    expect(ids("diziler")).toEqual(["2"]);
    expect(ids("  ")).toEqual(["1", "2"]);
    expect(ids("yok")).toEqual([]);
  });
});
