import { describe, expect, it } from "vitest";
import { parseBackup, toBackupItem } from "@/lib/backup";
import { isPrivateHost, normalizeHttpUrl } from "@/lib/format";

describe("normalizeHttpUrl", () => {
  it("yalnizca http(s) adresleri kabul eder ve metni degistirmez", () => {
    expect(normalizeHttpUrl(" https://ornek.test/a?b=1 ")).toBe("https://ornek.test/a?b=1");
    expect(normalizeHttpUrl("http://ornek.test")).toBe("http://ornek.test");
    expect(normalizeHttpUrl("javascript:alert(1)")).toBeNull();
    expect(normalizeHttpUrl("data:text/html,x")).toBeNull();
    expect(normalizeHttpUrl("file:///C:/gizli.txt")).toBeNull();
    expect(normalizeHttpUrl("adres degil")).toBeNull();
    expect(normalizeHttpUrl(42)).toBeNull();
  });
});

describe("isPrivateHost", () => {
  it("yerel ve ozel ag adreslerini yakalar", () => {
    for (const h of ["localhost", "app.localhost", "nas.local", "127.0.0.1", "10.1.2.3", "192.168.1.5", "172.20.0.1", "169.254.1.1", "[::1]", "fd12:3456::1"]) {
      expect(isPrivateHost(h), h).toBe(true);
    }
    for (const h of ["ornek.test", "172.32.0.1", "8.8.8.8", "localhost.ornek.com"]) {
      expect(isPrivateHost(h), h).toBe(false);
    }
  });
});

describe("yedek bicimi (eklentiyle uyumlu)", () => {
  const dbClip = {
    id: "c1",
    url: "https://ornek.test/makale",
    title: "Makale",
    excerpt: "Özet",
    content: "<p>Gövde</p>",
    domain: "ornek.test",
    isRead: true,
    isStarred: false,
    createdAt: new Date("2026-01-02T03:04:05Z"),
    tags: [{ tag: { name: "okuma" } }],
    highlights: [{ id: "h1", text: "Önemli", note: "not", createdAt: new Date("2026-01-03T00:00:00Z") }],
  };

  it("disa aktarilan kayit geri okununca ayni veriyi verir", () => {
    const [item] = parseBackup(JSON.parse(JSON.stringify([toBackupItem(dbClip)])));
    expect(item).toMatchObject({
      url: dbClip.url,
      title: "Makale",
      content: "<p>Gövde</p>",
      isRead: true,
      tags: ["okuma"],
      highlights: [{ text: "Önemli", note: "not" }],
      createdAt: "2026-01-02T03:04:05.000Z",
    });
  });

  it("eklenti disa aktarimini ({ clips } veya dizi) okur, gecersiz adresleri atlar", () => {
    const ext = [
      { url: "https://a.test/1", title: "Bir", tags: ["Haber", "haber"], highlights: [{ id: "x", text: "vurgu" }], createdAt: "bozuk" },
      { url: "javascript:alert(1)", title: "Kotu" },
      { title: "Adressiz" },
      { url: "https://a.test/2", tags: [{ id: "t", name: "Web" }] },
    ];
    const items = parseBackup({ clips: ext });
    expect(items.map((i) => i.url)).toEqual(["https://a.test/1", "https://a.test/2"]);
    expect(items[0].tags).toEqual(["haber"]);
    expect(items[0].highlights).toEqual([{ text: "vurgu", note: null }]);
    expect(Date.parse(items[0].createdAt)).not.toBeNaN();
    expect(items[1].title).toBe("https://a.test/2");
    expect(items[1].tags).toEqual(["web"]);
  });

  it("liste icermeyen dosyayi reddeder", () => {
    expect(() => parseBackup({ foo: 1 })).toThrow(/liste/);
    expect(() => parseBackup(null)).toThrow();
  });
});
