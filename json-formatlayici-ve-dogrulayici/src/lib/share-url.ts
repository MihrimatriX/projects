import { compressToEncodedURIComponent, decompressFromEncodedURIComponent } from "lz-string";

const MAX_RAW_CHARS = 200_000;

export interface SharePayload {
  j: string;
  m?: "json" | "ndjson";
}

function encodePayload(payload: SharePayload): string {
  const json = JSON.stringify(payload);
  if (typeof window !== "undefined") {
    return compressToEncodedURIComponent(json);
  }
  return Buffer.from(json, "utf-8").toString("base64");
}

function decodePayload(encoded: string): string | null {
  try {
    if (typeof window !== "undefined") {
      const lz = decompressFromEncodedURIComponent(encoded);
      if (lz) return lz;
    }
    return decodeURIComponent(escape(atob(encoded)));
  } catch {
    return null;
  }
}

export function buildShareUrl(
  rawJson: string,
  mode: "json" | "ndjson",
  baseUrl?: string
): string | null {
  if (!rawJson.trim()) return null;
  if (rawJson.length > MAX_RAW_CHARS) return null;

  const payload: SharePayload = { j: rawJson };
  if (mode === "ndjson") payload.m = "ndjson";

  const encoded = encodePayload(payload);
  const origin =
    baseUrl ??
    (typeof window !== "undefined" ? window.location.origin + window.location.pathname : "");
  return `${origin}#d=${encoded}`;
}

export function parseShareHash(hash: string): SharePayload | null {
  const match = hash.match(/[#&]d=([^&]+)/);
  if (!match) return null;

  const json = decodePayload(match[1]);
  if (!json) return null;

  try {
    const payload = JSON.parse(json) as SharePayload;
    if (typeof payload.j !== "string") return null;
    return payload;
  } catch {
    return null;
  }
}
