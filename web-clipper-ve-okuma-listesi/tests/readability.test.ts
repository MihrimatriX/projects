import { readFileSync } from "fs";
import path from "path";
import { describe, expect, it } from "vitest";
import { decodeHtml, extractArticle } from "@/lib/readability";

// Yalnizca yerel HTML ornekleri kullanilir; testler internete cikmaz.
const fixture = (name: string) => readFileSync(path.join(__dirname, "fixtures", name), "utf8");
const URL_ = "https://ornek.test/haber/bisiklet";

// windows-1254 (Turkce) kodlamasina cevirir: test icin elle kurulan kucuk tablo
const CP1254: Record<string, number> = { ş: 0xfe, Ş: 0xde, ğ: 0xf0, Ğ: 0xd0, ı: 0xfd, İ: 0xdd, ç: 0xe7, Ç: 0xc7, ö: 0xf6, Ö: 0xd6, ü: 0xfc, Ü: 0xdc, â: 0xe2, î: 0xee, "©": 0xa9, "—": 0x97 };
function toCp1254(text: string): ArrayBuffer {
  const bytes = [...text].map((ch) => CP1254[ch] ?? (ch.charCodeAt(0) < 128 ? ch.charCodeAt(0) : 0x3f));
  return new Uint8Array(bytes).buffer;
}

describe("extractArticle", () => {
  it("makale govdesini, basligi ve okuma suresini cikarir; menu/kenar cubugu disarida kalir", () => {
    const article = extractArticle(fixture("article.html"), URL_);
    expect(article).not.toBeNull();
    expect(article!.title).toContain("Şehirde Bisiklet Kullanımı");
    expect(article!.content).toContain("bisiklet yolu ağı iki katına çıktı");
    expect(article!.content).not.toContain("Çok okunanlar");
    expect(article!.content).not.toContain("Ana sayfa");
    expect(article!.excerpt.length).toBeGreaterThan(20);
    expect(article!.readingMinutes).toBeGreaterThanOrEqual(1);
  });

  it("script ve olay ozniteliklerini temizler", () => {
    const { content } = extractArticle(fixture("article.html"), URL_)!;
    expect(content.toLowerCase()).not.toContain("<script");
    expect(content).not.toContain("onclick");
    expect(content).not.toContain("onerror");
    expect(content).toContain('src="https://ornek.test/foto.jpg"');
  });

  it("makale olmayan sayfada null doner", () => {
    expect(extractArticle(fixture("no-article.html"), "https://ornek.test/giris")).toBeNull();
  });
});

describe("decodeHtml", () => {
  const html = fixture("article.html");

  it("UTF-8 sayfayi oldugu gibi cozer", () => {
    expect(decodeHtml(new TextEncoder().encode(html).buffer as ArrayBuffer, "text/html; charset=utf-8")).toBe(html);
  });

  it("<meta charset=windows-1254> sayfadaki Turkce karakterleri bozmadan cozer", () => {
    const legacy = html.replace('<meta charset="utf-8">', '<meta charset="windows-1254">');
    const decoded = decodeHtml(toCp1254(legacy), "text/html");
    expect(decoded).toContain("Şehirde Bisiklet Kullanımı");
    expect(extractArticle(decoded, URL_)!.content).toContain("yüzde altmışı");
  });

  it("Content-Type basligindaki charset meta etiketinden onceliklidir", () => {
    const decoded = decodeHtml(toCp1254("<p>Güneş ışığı</p>"), "text/html; charset=ISO-8859-9");
    expect(decoded).toBe("<p>Güneş ışığı</p>");
  });

  it("bilinmeyen charset adinda UTF-8'e duser", () => {
    const bytes = new TextEncoder().encode("<meta charset=\"x-yok\"><p>çay</p>");
    expect(decodeHtml(bytes.buffer as ArrayBuffer, null)).toContain("çay");
  });
});
