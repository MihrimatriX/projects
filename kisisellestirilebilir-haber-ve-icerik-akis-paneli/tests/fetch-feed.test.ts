import http from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { fetchFeedXml } from "@/lib/fetch-feed";
import { listen, startFixtureServer } from "./fixtures/serve.mjs";

let server: http.Server;
let base = "";

beforeAll(async () => {
  server = await startFixtureServer();
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(() => new Promise<void>((r) => server.close(() => r())));
afterEach(() => {
  delete process.env.RSS_ALLOW_PRIVATE_HOSTS;
  vi.unstubAllGlobals();
});

describe("fetchFeedXml (yerel fikstur, internet gerekmez)", () => {
  it("yerel adres varsayilan olarak engellenir", async () => {
    await expect(fetchFeedXml(`${base}/teknoloji.xml`)).rejects.toThrow(/SSRF/);
  });

  it("izinle fikstur feed'ini indirir; 404 ve 500'u anlasilir hataya cevirir", async () => {
    process.env.RSS_ALLOW_PRIVATE_HOSTS = "1";
    expect(await fetchFeedXml(`${base}/teknoloji.xml`)).toContain("<title>Yerel Teknoloji</title>");
    await expect(fetchFeedXml(`${base}/yok.xml`)).rejects.toThrow(/404/);
    await expect(fetchFeedXml(`${base}/hata.xml`)).rejects.toThrow(/HTTP 500/);
  });

  it("baglanti yoksa (cevrimdisi) Turkce hata verir", async () => {
    process.env.RSS_ALLOW_PRIVATE_HOSTS = "1";
    const closed = await startFixtureServer();
    const port = (closed.address() as AddressInfo).port;
    await new Promise((r) => closed.close(r));
    await expect(fetchFeedXml(`http://127.0.0.1:${port}/x.xml`)).rejects.toThrow(/ulaşılamadı/);
  });

  it("yanit vermeyen sunucuda zaman asimina ugrar", async () => {
    process.env.RSS_ALLOW_PRIVATE_HOSTS = "1";
    const hang = await listen(http.createServer(() => {}));
    try {
      const port = (hang.address() as AddressInfo).port;
      await expect(fetchFeedXml(`http://127.0.0.1:${port}/x.xml`, 300)).rejects.toThrow(/zaman aşımı/);
    } finally {
      hang.closeAllConnections();
      await new Promise((r) => hang.close(r));
    }
  });

  it("yerel aga yonlendirmeyi engeller", async () => {
    const fetchMock = vi.fn(
      async () => new Response(null, { status: 302, headers: { location: "http://127.0.0.1/admin" } })
    );
    vi.stubGlobal("fetch", fetchMock);
    await expect(fetchFeedXml("http://93.184.216.34/feed")).rejects.toThrow(/SSRF/);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("izinli yonlendirmeyi izler", async () => {
    process.env.RSS_ALLOW_PRIVATE_HOSTS = "1";
    const redirect = await listen(
      http.createServer((_, res) => res.writeHead(301, { location: `${base}/bilim.xml` }).end())
    );
    try {
      const url = `http://127.0.0.1:${(redirect.address() as AddressInfo).port}/eski`;
      expect(await fetchFeedXml(url)).toContain("Yerel Bilim");
    } finally {
      await new Promise((r) => redirect.close(r));
    }
  });
});
