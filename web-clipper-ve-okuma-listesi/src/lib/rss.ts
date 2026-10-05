import Parser from "rss-parser";
import { extractDomain, isPrivateHost, normalizeHttpUrl } from "@/lib/format";

const parser = new Parser({
  timeout: 10_000,
  headers: { "User-Agent": "WebClipper/1.0 RSS Importer" },
});

export type RssEntry = {
  url: string;
  title: string;
  excerpt?: string;
  publishedAt?: Date;
};

export async function fetchFeedEntries(feedUrl: string): Promise<{ title: string; entries: RssEntry[] }> {
  const parsed = new URL(feedUrl);
  if (isPrivateHost(parsed.hostname)) {
    throw new Error("Özel ağ RSS adresleri desteklenmiyor");
  }

  const feed = await parser.parseURL(feedUrl);
  const entries: RssEntry[] = [];
  for (const item of feed.items ?? []) {
    // Yalnızca http(s) bağlantılar: feed'deki javascript:/data: adresleri listeye girmez
    const url = normalizeHttpUrl(item.link) ?? normalizeHttpUrl(item.guid);
    if (!url) continue;
    entries.push({
      url,
      title: (item.title ?? url).trim(),
      excerpt: item.contentSnippet?.slice(0, 280) ?? item.summary?.slice(0, 280),
      // Geçersiz tarih (Invalid Date) Prisma create'i düşürüp tüm içe aktarmayı bozar
      publishedAt: item.pubDate && !isNaN(Date.parse(item.pubDate)) ? new Date(item.pubDate) : undefined,
    });
  }

  return {
    title: feed.title ?? extractDomain(feedUrl) ?? "RSS Feed",
    entries,
  };
}
