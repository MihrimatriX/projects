import { lookup } from "node:dns/promises";

/** Blocks feed URLs that target private/local networks (SSRF mitigation). */
export function isPrivateHost(hostname: string): boolean {
  let h = hostname.toLowerCase().replace(/^\[|\]$/g, "");
  if (h.startsWith("::ffff:")) h = h.slice(7); // IPv4-mapped IPv6
  if (h === "localhost" || h.endsWith(".localhost") || h.endsWith(".local")) return true;
  if (h === "::" || h === "::1" || h.startsWith("fe80:") || /^f[cd][0-9a-f]{0,2}:/i.test(h)) return true;
  if (/^127\.|^10\.|^192\.168\.|^169\.254\.|^0\.|^172\.(1[6-9]|2\d|3[01])\./.test(h)) return true;
  return false;
}

// Yalnizca testler/yerel fikstur sunuculari icin: RSS_ALLOW_PRIVATE_HOSTS=1 yerel adreslere izin verir.
const allowPrivate = () => process.env.RSS_ALLOW_PRIVATE_HOSTS === "1";

const BLOCKED = "Özel ağ veya yerel adresler engellendi (SSRF koruması).";

export function assertPublicFeedUrl(url: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(url.trim());
  } catch {
    throw new Error("Geçersiz besleme URL'si.");
  }
  if (!["http:", "https:"].includes(parsed.protocol)) {
    throw new Error("Yalnızca HTTP ve HTTPS beslemeleri desteklenir.");
  }
  if (!allowPrivate() && isPrivateHost(parsed.hostname)) throw new Error(BLOCKED);
  return parsed;
}

/** URL kontrolune ek olarak alan adinin cozuldugu IP'leri de denetler (ozel IP'ye cozulen adlar). */
export async function assertPublicFeedTarget(url: string): Promise<void> {
  const parsed = assertPublicFeedUrl(url);
  if (allowPrivate()) return;
  let addresses: { address: string }[];
  try {
    addresses = await lookup(parsed.hostname.replace(/^\[|\]$/g, ""), { all: true });
  } catch {
    throw new Error(`Feed'e ulaşılamadı: "${parsed.hostname}" adresi çözümlenemedi. İnternet bağlantınızı kontrol edin.`);
  }
  if (addresses.some((a) => isPrivateHost(a.address))) throw new Error(BLOCKED);
}
