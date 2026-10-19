const SECRET_HEADER_NAMES = [
  "authorization",
  "x-api-key",
  "api-key",
  "x-auth-token",
  "cookie",
  "stripe-signature",
  "x-hub-signature",
  "x-hub-signature-256",
  "x-shopify-hmac-sha256",
];

const SECRET_BODY_PATTERNS = [
  /("?(?:password|secret|token|api_key|apikey|access_token)"?\s*:\s*)"[^"]*"/gi,
  /(Bearer\s+)[A-Za-z0-9._\-]+/gi,
];

export function generateSlug(): string {
  return `hook_${Math.random().toString(36).slice(2, 8)}`;
}

export function generateId(): string {
  return `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
}

export function maskHeaders(headers: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(headers)) {
    if (SECRET_HEADER_NAMES.includes(key.toLowerCase())) {
      out[key] = "••••••••••••";
    } else {
      out[key] = value;
    }
  }
  return out;
}

export function maskBody(body: string): string {
  if (!body) return body;
  let masked = body;
  for (const pattern of SECRET_BODY_PATTERNS) {
    masked = masked.replace(pattern, '$1"••••••••"');
  }
  return masked;
}

export function truncateBody(body: string, maxBytes = 512_000): string {
  const buf = Buffer.from(body, "utf8");
  if (buf.length <= maxBytes) return body;
  return buf.subarray(0, maxBytes).toString("utf8") + "\n\n… (gövde kısaltıldı)";
}

export function parseHookSlug(url: string): string | null {
  const match = url.match(/^\/hook\/([^/?#]+)/);
  return match ? match[1] : null;
}

/** Replay yalnızca bu makineye yapılabilir (URL.hostname IPv6'yı köşeli parantezle verir). */
export function isLoopbackHost(hostname: string): boolean {
  return ["127.0.0.1", "localhost", "::1", "[::1]"].includes(hostname.toLowerCase());
}
