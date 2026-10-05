import { describe, expect, it } from "vitest";
import {
  buildExport,
  cleanName,
  exportFileName,
  isBoardEmpty,
  isSnapshotJson,
  parseImport,
  snapshotHasShapes,
} from "@/lib/board-utils";

// tldraw getSnapshot(editor.store) bicimi: kayitlar document.store altinda id -> kayit
const withShape = JSON.stringify({
  document: {
    store: {
      "document:document": { id: "document:document", typeName: "document" },
      "shape:a": { id: "shape:a", typeName: "shape", type: "geo" },
    },
    schema: { schemaVersion: 2, sequences: {} },
  },
  session: {},
});
const noShape = JSON.stringify({
  document: { store: { "page:p": { id: "page:p", typeName: "page" } }, schema: {} },
});

describe("snapshotHasShapes / isBoardEmpty", () => {
  it("getSnapshot bicimindeki sekilleri bulur", () => {
    expect(snapshotHasShapes(withShape)).toBe(true);
    expect(isBoardEmpty(withShape)).toBe(false);
  });
  it("sekilsiz, bos ve bozuk veriyi bos sayar", () => {
    expect(isBoardEmpty(noShape)).toBe(true);
    expect(isBoardEmpty("{}")).toBe(true);
    expect(isBoardEmpty(undefined)).toBe(true);
    expect(isBoardEmpty("{bozuk")).toBe(true);
  });
  it("store anahtarli (TLStoreSnapshot) veriyi de okur", () => {
    expect(snapshotHasShapes(JSON.stringify({ store: { "shape:x": { typeName: "shape" } } }))).toBe(true);
  });
});

describe("cleanName / isSnapshotJson", () => {
  it("adi kirpar, bos veya metin olmayan adi reddeder, uzun adi kisaltir", () => {
    expect(cleanName("  Plan  ")).toBe("Plan");
    expect(cleanName("   ")).toBeNull();
    expect(cleanName(42)).toBeNull();
    expect(cleanName("x".repeat(500))).toHaveLength(120);
  });
  it("yalnizca JSON nesnesi olan tuval verisini kabul eder", () => {
    expect(isSnapshotJson("{}")).toBe(true);
    expect(isSnapshotJson(withShape)).toBe(true);
    expect(isSnapshotJson("[1]")).toBe(false);
    expect(isSnapshotJson("null")).toBe(false);
    expect(isSnapshotJson("{bozuk")).toBe(false);
    expect(isSnapshotJson({})).toBe(false);
  });
});

describe("disa / ice aktarma", () => {
  it("disa aktarilan dosya ayni ad ve veriyle geri okunur", () => {
    const file = buildExport("Yol haritası", withShape);
    const back = parseImport(file, "dosya");
    expect(back.name).toBe("Yol haritası");
    expect(JSON.parse(back.data)).toEqual(JSON.parse(withShape));
  });
  it("ham tldraw snapshot'inda adi dosya adindan alir", () => {
    expect(parseImport(withShape, "toplanti").name).toBe("toplanti");
  });
  it("tldraw .tldr dosyasini store bicimine cevirir", () => {
    const tldr = JSON.stringify({
      tldrawFileFormatVersion: 1,
      schema: { schemaVersion: 2 },
      records: [{ id: "shape:k", typeName: "shape" }],
    });
    const { data } = parseImport(tldr, "eskiz");
    expect(snapshotHasShapes(data)).toBe(true);
    expect(JSON.parse(data).schema).toEqual({ schemaVersion: 2 });
  });
  it("gecersiz dosyalari anlasilir hatayla reddeder", () => {
    expect(() => parseImport("metin", "a")).toThrow(/JSON/);
    expect(() => parseImport('{"foo":1}', "a")).toThrow(/tldraw/);
  });
  it("dosya adindan Windows'ta gecersiz karakterleri temizler", () => {
    expect(exportFileName('Plan: A/B "v2"', "png")).toBe("Plan-AB-v2.png");
    expect(exportFileName("  ", "json")).toBe("pano.json");
  });
});
