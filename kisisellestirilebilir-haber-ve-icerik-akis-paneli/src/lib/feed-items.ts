// Feed ogesi -> makale satiri ve OPML okuma/yazma: sunucu eylemlerinden bagimsiz, saf fonksiyonlar.

export type FeedItemLike = {
  guid?: string;
  link?: string;
  title?: string;
  pubDate?: string;
  isoDate?: string;
  creator?: string;
  author?: string;
  content?: string;
  contentEncoded?: string;
  "content:encoded"?: string;
  description?: string;
  summary?: string;
};

const stripHtml = (html: string): string =>
  html ? html.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim() : "";

export function itemToArticle(feedId: string, item: FeedItemLike, now = new Date()) {
  // content:encoded tam metni tasir; rss-parser'in `content` alani cogu zaman yalnizca description'dir
  const content =
    item.contentEncoded || item["content:encoded"] || item.content || item.description || "";
  const parsed = Date.parse(item.isoDate || item.pubDate || "");
  const title = item.title || "Başlıksız Haber";
  return {
    feedId,
    // guid/link yoksa feed + baslik + tarihten sabit anahtar: her yenilemede kopya olusmaz
    guid: item.guid || item.link || `${feedId}:${title}:${item.pubDate ?? ""}`,
    title,
    link: item.link || "",
    author: item.creator || item.author || null,
    content,
    snippet: item.summary || stripHtml(content).slice(0, 160),
    publishedAt: isNaN(parsed) ? now : new Date(parsed),
  };
}

const decodeXml = (s: string) =>
  s
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");

const encodeXml = (s: string) =>
  s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

export type OpmlFeed = { url: string; title?: string; folder: string };

/** OPML'deki xmlUrl'li outline'lari dondurur. Klasor: category niteligi ya da ust outline basligi. */
export function parseOpml(xml: string): OpmlFeed[] {
  const result: OpmlFeed[] = [];
  const parents: (string | null)[] = [];
  const tagRegex = /<(\/?)outline\b([^>]*?)(\/?)>/gi;
  let m: RegExpExecArray | null;
  while ((m = tagRegex.exec(xml)) !== null) {
    const [, closing, attrsStr, selfClosing] = m;
    if (closing) {
      parents.pop();
      continue;
    }
    const attrs: Record<string, string> = {};
    for (const a of attrsStr.matchAll(/([\w:-]+)\s*=\s*"([^"]*)"/g)) attrs[a[1].toLowerCase()] = decodeXml(a[2]);
    const url = attrs.xmlurl || attrs.url;
    if (url) {
      const parent = [...parents].reverse().find((p) => p);
      result.push({ url: url.trim(), title: attrs.title || attrs.text, folder: attrs.category || parent || "Genel" });
    }
    if (!selfClosing) parents.push(url ? null : attrs.title || attrs.text || null);
  }
  return result;
}

export function buildOpml(feeds: { title: string; url: string; folder: string }[], now = new Date()): string {
  const lines = feeds.map(
    (f) =>
      `      <outline text="${encodeXml(f.title)}" title="${encodeXml(f.title)}" type="rss" xmlUrl="${encodeXml(f.url)}" category="${encodeXml(f.folder)}" />`
  );
  return [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<opml version="1.0">`,
    `  <head>`,
    `    <title>Haber Akış Paneli dışa aktarımı</title>`,
    `    <dateCreated>${now.toUTCString()}</dateCreated>`,
    `  </head>`,
    `  <body>`,
    `    <outline title="Abonelikler" text="Abonelikler">`,
    ...lines,
    `    </outline>`,
    `  </body>`,
    `</opml>`,
  ].join("\n");
}

/** Arama: baslik + ozet, Turkce buyuk/kucuk harf duyarsiz. */
export function matchesSearch(a: { title: string; snippet?: string | null }, term: string): boolean {
  const q = term.trim().toLocaleLowerCase("tr-TR");
  if (!q) return true;
  return `${a.title} ${a.snippet ?? ""}`.toLocaleLowerCase("tr-TR").includes(q);
}
