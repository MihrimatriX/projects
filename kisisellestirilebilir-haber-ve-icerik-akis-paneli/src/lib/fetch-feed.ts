import { assertPublicFeedTarget } from "@/lib/ssrf";

/** Tarayıcı benzeri istek — birçok site bot User-Agent'ını 403 ile reddeder */
const BROWSER_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const FEED_ACCEPT =
  "application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.8";

const MAX_REDIRECTS = 5;
export const FEED_TIMEOUT_MS = 15_000;

function feedFetchError(status: number, url: string): Error {
  if (status === 403) {
    return new Error(
      "Site erişimi engelledi (403). Bazı feed'ler bot trafiğine kapalıdır; farklı bir RSS URL deneyin."
    );
  }
  if (status === 404) {
    return new Error("Feed bulunamadı (404). URL'yi kontrol edin.");
  }
  if (status === 401) {
    return new Error("Feed kimlik doğrulama istiyor (401). Herkese açık RSS URL kullanın.");
  }
  return new Error(`Feed indirilemedi (HTTP ${status}): ${url}`);
}

function networkError(err: unknown, timeoutMs: number): Error {
  const name = (err as { name?: string })?.name;
  if (name === "TimeoutError" || name === "AbortError") {
    return new Error(`Feed ${Math.round(timeoutMs / 1000)} sn içinde yanıt vermedi (zaman aşımı).`);
  }
  return new Error("Feed'e ulaşılamadı. İnternet bağlantınızı veya adresi kontrol edin.");
}

/**
 * Feed XML'ini indirir. Her yönlendirme adımı SSRF kontrolünden geçer (yönlendirme ile yerel ağa
 * kaçış engellenir); istek zaman aşımına uğrarsa ya da ağ yoksa anlaşılır bir Türkçe hata fırlatır.
 */
export async function fetchFeedXml(url: string, timeoutMs = FEED_TIMEOUT_MS): Promise<string> {
  let current = url;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    await assertPublicFeedTarget(current);
    const origin = new URL(current).origin;
    try {
      const res = await fetch(current, {
        headers: {
          "User-Agent": BROWSER_UA,
          Accept: FEED_ACCEPT,
          "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
          Referer: `${origin}/`,
          "Cache-Control": "no-cache",
        },
        redirect: "manual",
        cache: "no-store",
        signal: AbortSignal.timeout(timeoutMs),
      });

      const location = res.headers.get("location");
      if (res.status >= 300 && res.status < 400 && location) {
        current = new URL(location, current).toString();
        continue;
      }
      if (!res.ok) throw feedFetchError(res.status, current);

      const text = await res.text();
      if (!text.trim()) throw new Error("Feed boş yanıt döndü.");
      return text;
    } catch (err) {
      if (err instanceof Error && !["TypeError", "TimeoutError", "AbortError"].includes(err.name)) throw err;
      throw networkError(err, timeoutMs);
    }
  }
  throw new Error("Feed çok fazla yönlendirme yaptı.");
}
