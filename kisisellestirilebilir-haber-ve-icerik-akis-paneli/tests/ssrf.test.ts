import { afterEach, describe, expect, it } from "vitest";
import { assertPublicFeedTarget, assertPublicFeedUrl, isPrivateHost } from "@/lib/ssrf";

afterEach(() => {
  delete process.env.RSS_ALLOW_PRIVATE_HOSTS;
});

describe("SSRF korumasi", () => {
  it("yerel ve ozel adresleri tanir", () => {
    for (const h of ["localhost", "app.localhost", "nas.local", "127.0.0.1", "10.1.2.3", "192.168.1.5", "172.20.0.1", "169.254.1.1", "0.0.0.0", "[::1]", "::", "fd00::1", "fe80::1", "::ffff:127.0.0.1"]) {
      expect(isPrivateHost(h), h).toBe(true);
    }
    for (const h of ["example.com", "8.8.8.8", "172.32.0.1", "2606:4700::1111"]) {
      expect(isPrivateHost(h), h).toBe(false);
    }
  });

  it("gecersiz URL, http disi protokol ve yerel adresi reddeder", () => {
    expect(() => assertPublicFeedUrl("bozuk")).toThrow(/Geçersiz/);
    expect(() => assertPublicFeedUrl("file:///C:/gizli.xml")).toThrow(/HTTP ve HTTPS/);
    expect(() => assertPublicFeedUrl("http://127.0.0.1:8080/feed")).toThrow(/SSRF/);
    expect(assertPublicFeedUrl(" https://example.com/rss ").hostname).toBe("example.com");
  });

  it("RSS_ALLOW_PRIVATE_HOSTS=1 yalnizca acikca verildiginde yerel adrese izin verir", async () => {
    process.env.RSS_ALLOW_PRIVATE_HOSTS = "1";
    expect(() => assertPublicFeedUrl("http://127.0.0.1:8080/feed")).not.toThrow();
    await expect(assertPublicFeedTarget("http://localhost/feed")).resolves.toBeUndefined();
  });

  it("IP adresi dogrudan verilen hedefte DNS gerekmeden karar verir", async () => {
    await expect(assertPublicFeedTarget("http://10.0.0.1/feed")).rejects.toThrow(/SSRF/);
    await expect(assertPublicFeedTarget("http://93.184.216.34/feed")).resolves.toBeUndefined();
  });

  it("cozulemeyen alan adinda anlasilir hata verir", async () => {
    await expect(assertPublicFeedTarget("https://olmayan-alan.invalid/rss")).rejects.toThrow(/çözümlenemedi/);
  });
});
