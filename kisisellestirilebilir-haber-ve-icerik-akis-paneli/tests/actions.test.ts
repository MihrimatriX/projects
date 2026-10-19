import http from "node:http";
import type { AddressInfo } from "node:net";
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";
import { listen, startFixtureServer } from "./fixtures/serve.mjs";

// Sunucu eylemleri Next istek baglami disinda calisir
vi.mock("next/cache", () => ({ revalidatePath: () => {} }));

const { prisma } = await import("@/lib/db");
const actions = await import("@/app/actions");

let fixtures: http.Server;
let dynamic: http.Server;
let base = "";
let dynBase = "";
// Dinamik feed: testler oge ekleyip yenilemeyi dener
let dynItems = ["ilk"];
let dynUp = true;

const rss = (items: string[]) =>
  `<?xml version="1.0"?><rss version="2.0"><channel><title>Dinamik</title>${items
    .map((t) => `<item><title>${t}</title><guid>dyn-${t}</guid><link>https://d.test/${t}</link></item>`)
    .join("")}</channel></rss>`;

beforeAll(async () => {
  process.env.RSS_ALLOW_PRIVATE_HOSTS = "1";
  fixtures = await startFixtureServer();
  base = `http://127.0.0.1:${(fixtures.address() as AddressInfo).port}`;
  dynamic = await listen(
    http.createServer((_, res) => {
      if (!dynUp) return void res.writeHead(503).end();
      res.writeHead(200, { "Content-Type": "application/xml" }).end(rss(dynItems));
    })
  );
  dynBase = `http://127.0.0.1:${(dynamic.address() as AddressInfo).port}`;
});

afterAll(async () => {
  await new Promise((r) => fixtures.close(r));
  await new Promise((r) => dynamic.close(r));
  delete process.env.RSS_ALLOW_PRIVATE_HOSTS;
  delete process.env.DEFAULT_FEEDS;
});

beforeEach(async () => {
  await prisma.feed.deleteMany();
  await prisma.appSetting.deleteMany();
  dynItems = ["ilk"];
  dynUp = true;
});

describe("sunucu eylemleri (yerel fikstur feed'leri)", () => {
  it("feed ekler, makaleleri kaydeder; ayni feed tekrar eklenince kopya olusmaz", async () => {
    const res = await actions.addFeed(`${base}/teknoloji.xml`, "Teknoloji");
    expect(res.success).toBe(true);
    expect(res.feed).toMatchObject({ title: "Yerel Teknoloji", folder: "Teknoloji" });
    expect(await prisma.article.count()).toBe(3);

    await actions.addFeed(`${base}/teknoloji.xml`, "Teknoloji");
    expect(await prisma.article.count()).toBe(3);
    expect(await prisma.feed.count()).toBe(1);

    const unread = await actions.getArticles({ status: "unread" });
    expect(unread.map((a) => a.title)[0]).toBe("Yapay zeka çipleri yerelleşiyor"); // en yeni once
  });

  it("gecersiz, erisilemeyen ya da RSS olmayan adres kaydedilmez ve hata mesaji doner", async () => {
    expect(await actions.addFeed("bozuk-url")).toMatchObject({ success: false, error: expect.stringMatching(/Geçersiz/) });
    expect(await actions.addFeed(`${base}/yok.xml`)).toMatchObject({ success: false, error: expect.stringMatching(/404/) });
    expect(await actions.addFeed(`${base}/bozuk.xml`)).toMatchObject({ success: false, error: expect.stringMatching(/RSS\/Atom/) });
    expect(await prisma.feed.count()).toBe(0);
  });

  it("yenileme yeni ogeleri sayar; feed cevrimdisiyken makaleler korunur ve hata feed'e yazilir", async () => {
    const { feed } = await actions.addFeed(`${dynBase}/feed`);
    dynItems = ["ilk", "ikinci"];
    expect(await actions.refreshFeeds()).toMatchObject({ success: true, count: 1, failed: [] });

    dynUp = false;
    const offline = await actions.refreshFeeds();
    expect(offline.count).toBe(0);
    expect(offline.failed).toEqual([{ title: "Dinamik", error: expect.stringMatching(/503/) }]);
    expect(await prisma.article.count()).toBe(2);
    expect((await prisma.feed.findUnique({ where: { id: feed!.id } }))?.lastError).toMatch(/503/);

    dynUp = true;
    await actions.refreshFeeds();
    expect((await prisma.feed.findUnique({ where: { id: feed!.id } }))?.lastError).toBeNull();
  });

  it("okundu/yildiz ve filtreye gore tumunu okundu isaretler", async () => {
    await actions.addFeed(`${base}/teknoloji.xml`, "Teknoloji");
    await actions.addFeed(`${base}/bilim.xml`, "Bilim");
    const [first] = await actions.getArticles({ folder: "Bilim" });
    await actions.toggleArticleStarred(first.id, true);
    expect((await actions.getArticles({ status: "starred" })).map((a) => a.id)).toEqual([first.id]);

    expect(await actions.markAllAsRead({ folder: "Teknoloji" })).toMatchObject({ success: true, count: 3 });
    const feeds = await actions.getFeeds();
    expect(Object.fromEntries(feeds.map((f) => [f.title, f._count.articles]))).toEqual({
      "Yerel Bilim": 2,
      "Yerel Teknoloji": 0,
    });
  });

  it("OPML disa/ice aktarma; cevrimdisi feed abonelik olarak korunur", async () => {
    await actions.addFeed(`${base}/teknoloji.xml`, "Teknoloji");
    const opml = await actions.exportOpml();
    expect(opml).toContain(`xmlUrl="${base}/teknoloji.xml"`);

    await prisma.feed.deleteMany();
    const withDead = opml.replace(
      "</outline>\n  </body>",
      `  <outline text="Kapali" xmlUrl="${base}/hata.xml" category="Diger" />\n    </outline>\n  </body>`
    );
    expect(await actions.importOpml(withDead)).toEqual({ success: true, count: 2, failed: 1 });
    const feeds = await prisma.feed.findMany({ orderBy: { title: "asc" } });
    expect(feeds.map((f) => [f.title, f.folder, Boolean(f.lastError)])).toEqual([
      ["Kapali", "Diger", true],
      ["Yerel Teknoloji", "Teknoloji", false],
    ]);
    expect(await actions.importOpml("<html/>")).toMatchObject({ success: false });
  });

  it("varsayilan feed'ler bir kez eklenir; kullanici silince geri gelmez", async () => {
    process.env.DEFAULT_FEEDS = JSON.stringify([
      { url: `${base}/bilim.xml`, folder: "Bilim", title: "Bilim (varsayılan)" },
      { url: `${base}/hata.xml`, folder: "Bilim", title: "Erişilemeyen" },
    ]);
    await Promise.all([actions.seedDefaultFeeds(), actions.seedDefaultFeeds()]);
    const feeds = await prisma.feed.findMany({ orderBy: { title: "asc" } });
    expect(feeds.map((f) => [f.title, Boolean(f.lastError)])).toEqual([
      ["Bilim (varsayılan)", false],
      ["Erişilemeyen", true],
    ]);
    expect(await prisma.article.count()).toBe(2);

    for (const f of feeds) await actions.deleteFeed(f.id);
    await actions.seedDefaultFeeds();
    expect(await prisma.feed.count()).toBe(0);
  });
});
