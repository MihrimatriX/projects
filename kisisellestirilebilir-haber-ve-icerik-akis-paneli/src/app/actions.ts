"use server";

import Parser from "rss-parser";
import type { Feed, Prisma } from "@prisma/client";
import { prisma } from "@/lib/db";
import { fetchFeedXml } from "@/lib/fetch-feed";
import { assertPublicFeedUrl } from "@/lib/ssrf";
import { buildOpml, itemToArticle, parseOpml, type FeedItemLike } from "@/lib/feed-items";
import { revalidatePath } from "next/cache";

const parser = new Parser({
  customFields: {
    item: [["content:encoded", "contentEncoded"]],
  },
});

async function downloadFeed(url: string) {
  const xml = await fetchFeedXml(url);
  try {
    return await parser.parseString(xml);
  } catch {
    throw new Error("Adres geçerli bir RSS/Atom beslemesi döndürmedi.");
  }
}

const errorMessage = (error: unknown, fallback: string) =>
  error instanceof Error ? error.message : fallback;

/** Yeni ogeleri kaydeder (guid tekil); eklenen makale sayisini dondurur. */
async function saveItems(feedId: string, items: FeedItemLike[] = []): Promise<number> {
  const rows = items.map((item) => itemToArticle(feedId, item));
  if (rows.length === 0) return 0;
  const existing = await prisma.article.findMany({
    where: { guid: { in: rows.map((r) => r.guid) } },
    select: { guid: true },
  });
  const seen = new Set(existing.map((e) => e.guid));
  let added = 0;
  for (const row of rows) {
    if (seen.has(row.guid)) continue;
    seen.add(row.guid);
    await prisma.article.create({ data: row });
    added++;
  }
  return added;
}

/** Tek feed'i indirir; hata olursa makaleler korunur, hata mesaji feed.lastError'a yazilir. */
async function syncFeed(feed: Pick<Feed, "id" | "url" | "title">) {
  try {
    const data = await downloadFeed(feed.url);
    const added = await saveItems(feed.id, data.items as FeedItemLike[]);
    await prisma.feed.update({
      where: { id: feed.id },
      data: { lastFetchedAt: new Date(), lastError: null },
    });
    return { added };
  } catch (err) {
    const error = errorMessage(err, "Feed güncellenemedi.");
    await prisma.feed.update({ where: { id: feed.id }, data: { lastError: error } }).catch(() => {});
    return { added: 0, error };
  }
}

export async function getFeeds() {
  try {
    return await prisma.feed.findMany({
      orderBy: { title: "asc" },
      include: {
        _count: {
          select: {
            articles: {
              where: { isRead: false },
            },
          },
        },
      },
    });
  } catch (error) {
    console.error("Feeds fetch error:", error);
    return [];
  }
}

type ArticleFilter = {
  feedId?: string;
  folder?: string;
  status?: "all" | "unread" | "starred";
};

function articleWhere(filter: ArticleFilter): Prisma.ArticleWhereInput {
  const where: Prisma.ArticleWhereInput = {};
  if (filter.feedId) where.feedId = filter.feedId;
  else if (filter.folder) where.feed = { folder: filter.folder };
  if (filter.status === "unread") where.isRead = false;
  else if (filter.status === "starred") where.isStarred = true;
  return where;
}

export async function getArticles(filter: ArticleFilter) {
  try {
    return await prisma.article.findMany({
      where: articleWhere(filter),
      orderBy: { publishedAt: "desc" },
      include: {
        feed: {
          select: { title: true, folder: true },
        },
      },
    });
  } catch (error) {
    console.error("Articles fetch error:", error);
    return [];
  }
}

export async function addFeed(url: string, folder: string = "Genel") {
  try {
    const cleanUrl = url.trim();
    assertPublicFeedUrl(cleanUrl);
    // Once indirip dogrular: gecersiz/erisilemeyen adres kaydedilmez
    const feedData = await downloadFeed(cleanUrl);
    const meta = {
      title: feedData.title || "Adsız Akış",
      siteUrl: feedData.link,
      description: feedData.description,
      folder: folder || "Genel",
      lastFetchedAt: new Date(),
      lastError: null,
    };
    const feed = await prisma.feed.upsert({
      where: { url: cleanUrl },
      update: meta,
      create: { url: cleanUrl, ...meta },
    });
    await saveItems(feed.id, feedData.items as FeedItemLike[]);

    revalidatePath("/");
    return { success: true, feed };
  } catch (error: unknown) {
    console.error("Add feed error:", error);
    return { success: false, error: errorMessage(error, "RSS Akışı çözümlenemedi.") };
  }
}

export async function deleteFeed(feedId: string) {
  try {
    await prisma.feed.delete({ where: { id: feedId } });
    revalidatePath("/");
    return { success: true };
  } catch (error) {
    console.error("Delete feed error:", error);
    return { success: false };
  }
}

/** Tum feedleri paralel yeniler. Cevrimdisiyken her feed kendi hatasini dondurur, uygulama calismaya devam eder. */
export async function refreshFeeds() {
  try {
    const feeds = await prisma.feed.findMany();
    const results = await Promise.all(feeds.map(syncFeed));
    const failed = feeds.flatMap((f, i) => {
      const error = results[i].error;
      return error ? [{ title: f.title, error }] : [];
    });
    revalidatePath("/");
    return { success: true, count: results.reduce((n, r) => n + r.added, 0), failed };
  } catch (error) {
    console.error("Refresh error:", error);
    return { success: false, count: 0, failed: [] };
  }
}

export async function toggleArticleRead(articleId: string, isRead: boolean) {
  try {
    await prisma.article.update({
      where: { id: articleId },
      data: { isRead },
    });
    revalidatePath("/");
    return { success: true };
  } catch {
    return { success: false };
  }
}

export async function toggleArticleStarred(articleId: string, isStarred: boolean) {
  try {
    await prisma.article.update({
      where: { id: articleId },
      data: { isStarred },
    });
    revalidatePath("/");
    return { success: true };
  } catch {
    return { success: false };
  }
}

export async function markAllAsRead(filter: { feedId?: string; folder?: string }) {
  try {
    const res = await prisma.article.updateMany({
      where: { ...articleWhere(filter), isRead: false },
      data: { isRead: true },
    });
    revalidatePath("/");
    return { success: true, count: res.count };
  } catch (error) {
    console.error("Mark all as read error:", error);
    return { success: false, count: 0 };
  }
}

/**
 * OPML ice aktarma. Feed kaydi indirme basarisiz olsa da eklenir (cevrimdisi ice aktarmada abonelik
 * kaybolmaz); hata feed'in yaninda gosterilir ve sonraki yenilemede tekrar denenir.
 */
export async function importOpml(xmlText: string) {
  const entries = parseOpml(xmlText);
  if (entries.length === 0) {
    return { success: false, count: 0, failed: 0, error: "OPML dosyasında feed bulunamadı." };
  }
  let count = 0;
  let failed = 0;
  for (const entry of entries) {
    const url = entry.url;
    try {
      assertPublicFeedUrl(url);
    } catch {
      failed++;
      continue;
    }
    const feed = await prisma.feed.upsert({
      where: { url },
      update: { folder: entry.folder },
      create: { url, folder: entry.folder, title: entry.title || new URL(url).hostname },
    });
    const res = await syncFeed(feed);
    if (res.error) failed++;
    count++;
  }
  revalidatePath("/");
  return { success: true, count, failed };
}

export async function exportOpml(): Promise<string> {
  try {
    return buildOpml(await prisma.feed.findMany({ orderBy: { title: "asc" } }));
  } catch (error) {
    console.error("OPML Export error:", error);
    return "";
  }
}

const SEEDED_KEY = "defaultFeedsSeeded";

type DefaultFeed = { url: string; folder: string; title: string };

function defaultFeeds(): DefaultFeed[] {
  // DEFAULT_FEEDS (JSON) testlerde yerel fikstur feed'i vermek icin kullanilir
  if (process.env.DEFAULT_FEEDS) {
    try {
      return JSON.parse(process.env.DEFAULT_FEEDS) as DefaultFeed[];
    } catch {
      console.error("DEFAULT_FEEDS JSON okunamadı; varsayılanlar kullanılıyor.");
    }
  }
  return [
    { url: "https://www.aa.com.tr/tr/rss/default?cat=guncel", folder: "Haberler", title: "Anadolu Ajansı — Güncel" },
    { url: "https://dev.to/feed", folder: "Geliştirici", title: "DEV Community" },
  ];
}

/**
 * Varsayilan feedler yalnizca bir kez eklenir (kullanici hepsini silerse geri gelmez). Kayitlar
 * internet olmasa da eklenir; makaleler ilk basarili yenilemede gelir.
 */
export async function seedDefaultFeeds() {
  try {
    if (await prisma.appSetting.findUnique({ where: { key: SEEDED_KEY } })) return;
    try {
      await prisma.appSetting.create({ data: { key: SEEDED_KEY, value: new Date().toISOString() } });
    } catch {
      return; // eszamanli baska bir istek tohumluyor
    }
    if ((await prisma.feed.count()) > 0) return; // eski surumden gelen veritabani

    const feeds = [];
    for (const d of defaultFeeds()) {
      feeds.push(await prisma.feed.create({ data: { url: d.url, folder: d.folder, title: d.title } }));
    }
    await Promise.all(feeds.map(syncFeed));
    revalidatePath("/");
  } catch (error) {
    console.error("Database seed error:", error);
  }
}
