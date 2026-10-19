import { JSDOM } from "jsdom";
import { Readability } from "@mozilla/readability";
import { sanitizeHtml } from "@/lib/sanitize";
import { prisma } from "@/lib/prisma";
import { estimateReadingMinutes, extractDomain, isPrivateHost } from "@/lib/format";

const FETCH_TIMEOUT_MS = 12_000;
const MAX_HTML_BYTES = 2_000_000;
// Aynı anda en fazla bu kadar sayfa indirilir (RSS içe aktarma onlarca makale kuyruğa atabilir)
const MAX_PARALLEL_PARSES = 3;

export type ExtractedArticle = {
  title?: string;
  content: string;
  excerpt: string;
  readingMinutes: number;
};

/**
 * Baytları doğru karakter kümesiyle çözer: önce Content-Type, sonra <meta charset>, yoksa UTF-8.
 * (Eski Türkçe siteler windows-1254 / iso-8859-9 kullanır; UTF-8 varsaymak "ÅŸ" gibi bozuk metin üretir.)
 */
export function decodeHtml(buffer: ArrayBuffer, contentType?: string | null): string {
  const bytes = new Uint8Array(buffer);
  const fromHeader = /charset=["']?([\w-]+)/i.exec(contentType ?? "")?.[1];
  const head = new TextDecoder("latin1").decode(bytes.subarray(0, 4096));
  const fromMeta = /<meta[^>]+charset=["']?([\w-]+)/i.exec(head)?.[1];
  for (const label of [fromHeader, fromMeta]) {
    if (!label) continue;
    try {
      return new TextDecoder(label).decode(bytes);
    } catch {
      // bilinmeyen karakter kümesi adı: sıradakini dene
    }
  }
  return new TextDecoder("utf-8").decode(bytes);
}

/** Readability ile makale gövdesini çıkarır; gövde bulunamazsa null. */
export function extractArticle(html: string, url: string): ExtractedArticle | null {
  const dom = new JSDOM(html, { url });
  try {
    const article = new Readability(dom.window.document).parse();
    if (!article?.content) return null;
    const plain = article.textContent ?? "";
    return {
      title: article.title?.trim() || undefined,
      content: sanitizeHtml(article.content),
      excerpt: (article.excerpt ?? plain.slice(0, 280)).trim(),
      readingMinutes: estimateReadingMinutes(plain),
    };
  } finally {
    dom.window.close();
  }
}

async function fetchHtml(url: string): Promise<string> {
  if (isPrivateHost(new URL(url).hostname)) {
    throw new Error("Özel ağ adresleri desteklenmiyor");
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        "User-Agent": "WebClipper/1.0 (+https://github.com; readability)",
        Accept: "text/html,application/xhtml+xml",
      },
      redirect: "follow",
    });

    // Yönlendirme sonrası yerel ağa düşen yanıt kullanılmaz
    if (res.url && isPrivateHost(new URL(res.url).hostname)) {
      throw new Error("Özel ağ adreslerine yönlendirme desteklenmiyor");
    }
    if (!res.ok) throw new Error(`HTTP ${res.status}`);

    const buffer = await res.arrayBuffer();
    if (buffer.byteLength > MAX_HTML_BYTES) {
      throw new Error("Sayfa çok büyük");
    }

    return decodeHtml(buffer, res.headers.get("content-type"));
  } finally {
    clearTimeout(timer);
  }
}

export async function parseClipContent(clipId: string, url: string): Promise<void> {
  try {
    const article = extractArticle(await fetchHtml(url), url);
    await prisma.clip.update({
      where: { id: clipId },
      data: article
        ? { ...article, domain: extractDomain(url), parseStatus: "done" }
        : { parseStatus: "failed", domain: extractDomain(url) },
    });
  } catch {
    // Kayıt bu arada silinmiş olabilir; o durumda yapılacak bir şey yok
    await prisma.clip
      .update({ where: { id: clipId }, data: { parseStatus: "failed", domain: extractDomain(url) } })
      .catch(() => undefined);
  }
}

const queue: (() => Promise<void>)[] = [];
let active = 0;

function pump() {
  while (active < MAX_PARALLEL_PARSES && queue.length) {
    active++;
    void queue.shift()!().finally(() => {
      active--;
      pump();
    });
  }
}

// Arka planda çalışır: istek hemen döner, içerik Readability ile ayrıştırılıp sonra DB'ye yazılır
export function scheduleParse(clipId: string, url: string): void {
  queue.push(() => parseClipContent(clipId, url));
  pump();
}
