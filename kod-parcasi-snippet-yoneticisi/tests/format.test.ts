import os from "os";
import { describe, expect, it } from "vitest";
import { expandPlaceholders } from "../electron/placeholders";
import { codePreview, collectTags, ipcErrorMessage, parseTags, summarizeImport, tagsToInput } from "../src/lib/format";

describe("yer tutucular", () => {
  it("tarih, kullanıcı ve makine adını genişletir, bilinmeyeni bırakır", () => {
    const out = expandPlaceholders("{{date}}|{{YEAR}}|{{user}}|{{hostname}}|{{bilinmeyen}}");
    const [date, year, user, host, unknown] = out.split("|");
    expect(date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(year).toBe(String(new Date().getFullYear()));
    expect(user).toBe(os.userInfo().username);
    expect(host).toBe(os.hostname());
    expect(unknown).toBe("{{bilinmeyen}}");
  });
});

describe("format", () => {
  it("etiketleri ayrıştırır ve geri yazar", () => {
    expect(parseTags(" #react, hooks ,, #ts ")).toEqual(["react", "hooks", "ts"]);
    expect(tagsToInput(["react", "#ts"])).toBe("#react, #ts");
  });

  it("etiketleri tekilleştirip sıralar", () => {
    const s = (tags: string[]) => ({ id: "x", title: "", description: "", language: "", folder: "", code: "", tags });
    expect(collectTags([s(["b", "a"]), s(["a", " "])])).toEqual(["a", "b"]);
  });

  it("önizleme ilk dolu satırı kısaltır", () => {
    expect(codePreview("\n\n  const x = 1;\nfoo")).toBe("  const x = 1;");
    expect(codePreview("x".repeat(70), 10)).toBe(`${"x".repeat(10)}…`);
  });

  it("IPC hata önekini temizler", () => {
    expect(ipcErrorMessage(new Error("Error invoking remote method 'snippets:import': Error: Dosya geçerli bir JSON değil.")))
      .toBe("Dosya geçerli bir JSON değil.");
  });
});

describe("içe aktarma önizlemesi", () => {
  it("eksik/yanlış tipli alanlara dayanıklı sayar, geçersiz girdiye Türkçe hata verir", () => {
    expect(summarizeImport('[{"id":"a","tags":["x","y"],"folder":"F"},{"title":"etiketsiz"},null,{"folder":3}]')).toEqual({
      snippets: 3,
      tags: 2,
      folders: 2,
    });
    expect(() => summarizeImport("{ bozuk")).toThrow("geçerli bir JSON değil");
    expect(() => summarizeImport('{"a":1}')).toThrow("snippet dizisi");
  });
});
