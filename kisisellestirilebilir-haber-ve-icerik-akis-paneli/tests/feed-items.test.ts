import { describe, expect, it } from "vitest";
import { buildOpml, itemToArticle, matchesSearch, parseOpml } from "@/lib/feed-items";
import { importMessage, syncMessage } from "@/lib/format";

describe("itemToArticle", () => {
  it("icerik, ozet, yazar ve tarihi esler", () => {
    const a = itemToArticle("f1", {
      guid: "g1",
      title: "Baslik",
      link: "https://x.test/1",
      creator: "Ayşe",
      content: "Kısa açıklama",
      contentEncoded: "<p>Merhaba <b>dünya</b></p>",
      isoDate: "2026-10-05T08:00:00.000Z",
    });
    expect(a).toMatchObject({ feedId: "f1", guid: "g1", author: "Ayşe", snippet: "Merhaba dünya" });
    expect(a.publishedAt.toISOString()).toBe("2026-10-05T08:00:00.000Z");
  });

  it("guid/link yoksa her cagrida ayni anahtari uretir (yenilemede kopya olusmaz)", () => {
    const item = { title: "Linksiz", pubDate: "Mon, 05 Oct 2026 08:00:00 GMT" };
    expect(itemToArticle("f1", item).guid).toBe(itemToArticle("f1", item).guid);
    expect(itemToArticle("f1", {}).title).toBe("Başlıksız Haber");
  });

  it("gecersiz tarihte simdiki zamani kullanir", () => {
    const now = new Date("2026-01-01T00:00:00Z");
    expect(itemToArticle("f", { pubDate: "dun" }, now).publishedAt).toBe(now);
  });
});

describe("OPML", () => {
  it("disa aktarilan OPML ozel karakterlerle birlikte geri okunur", () => {
    const feeds = [
      { title: 'A & "B"', url: "https://x.test/rss?a=1&b=2", folder: "Haber & Gündem" },
      { title: "C", url: "https://y.test/feed", folder: "Genel" },
    ];
    expect(parseOpml(buildOpml(feeds))).toEqual([
      { url: "https://x.test/rss?a=1&b=2", title: 'A & "B"', folder: "Haber & Gündem" },
      { url: "https://y.test/feed", title: "C", folder: "Genel" },
    ]);
  });

  it("category yoksa ust outline basligini klasor olarak kullanir", () => {
    const xml = `<opml><body>
      <outline text="Teknoloji"><outline text="T1" xmlUrl="https://t.test/1"/></outline>
      <outline text="Kok" xmlUrl="https://k.test/rss"/>
    </body></opml>`;
    expect(parseOpml(xml)).toEqual([
      { url: "https://t.test/1", title: "T1", folder: "Teknoloji" },
      { url: "https://k.test/rss", title: "Kok", folder: "Genel" },
    ]);
    expect(parseOpml("<html/>")).toEqual([]);
  });
});

describe("arama ve mesajlar", () => {
  it("Turkce harf duyarsiz arar", () => {
    expect(matchesSearch({ title: "İstanbul'da veri merkezi", snippet: null }, "istanbul")).toBe(true);
    expect(matchesSearch({ title: "x", snippet: "IŞIK hızında" }, "ışık")).toBe(true);
    expect(matchesSearch({ title: "x", snippet: "y" }, "z")).toBe(false);
    expect(matchesSearch({ title: "x" }, "  ")).toBe(true);
  });

  it("senkron ve ice aktarma ozetleri hatalari gosterir", () => {
    expect(syncMessage({ success: true, count: 2, failed: [] })).toBe("Senkron tamamlandı · 2 yeni makale");
    expect(
      syncMessage({
        success: true,
        count: 0,
        failed: [
          { title: "A", error: "zaman aşımı" },
          { title: "B", error: "x" },
        ],
      })
    ).toBe("Yeni makale yok · A güncellenemedi: zaman aşımı (+1 akış daha)");
    expect(importMessage(3, 1)).toMatch(/3 feed içe aktarıldı, 1 feed indirilemedi/);
  });
});
