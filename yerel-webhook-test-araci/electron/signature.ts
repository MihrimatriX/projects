import crypto from "crypto";
import type { SignaturePreset, SignatureVerifyResult } from "../src/types";

function timingSafeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

export function verifyWebhookSignature(
  preset: SignaturePreset,
  secret: string,
  rawBody: string,
  headers: Record<string, string>
): SignatureVerifyResult {
  if (!secret.trim()) {
    return { valid: false, message: "Gizli anahtar gerekli" };
  }

  const lower = Object.fromEntries(
    Object.entries(headers).map(([k, v]) => [k.toLowerCase(), v])
  );

  if (preset === "stripe") {
    const sig = lower["stripe-signature"];
    if (!sig) return { valid: false, message: "stripe-signature header yok" };
    // Anahtar rotasyonunda Stripe birden fazla v1 imzası gönderir; herhangi biri eşleşirse geçerlidir.
    const pairs = sig.split(",").map((p) => {
      const i = p.indexOf("=");
      return [p.slice(0, i).trim(), p.slice(i + 1).trim()] as const;
    });
    const timestamp = pairs.find(([k]) => k === "t")?.[1];
    const v1s = pairs.filter(([k]) => k === "v1").map(([, v]) => v);
    if (!timestamp || !v1s.length) return { valid: false, message: "Stripe imza formatı geçersiz" };
    const payload = `${timestamp}.${rawBody}`;
    const expected = crypto.createHmac("sha256", secret).update(payload).digest("hex");
    return v1s.some((v1) => timingSafeEqual(expected, v1))
      ? { valid: true, message: "Stripe HMAC geçerli" }
      : { valid: false, message: "Stripe HMAC eşleşmedi" };
  }

  if (preset === "github") {
    const sig256 = lower["x-hub-signature-256"];
    const sig = lower["x-hub-signature"];
    if (sig256) {
      const expected =
        "sha256=" + crypto.createHmac("sha256", secret).update(rawBody).digest("hex");
      return timingSafeEqual(expected, sig256)
        ? { valid: true, message: "GitHub SHA256 geçerli" }
        : { valid: false, message: "GitHub SHA256 eşleşmedi" };
    }
    if (sig) {
      const expected = "sha1=" + crypto.createHmac("sha1", secret).update(rawBody).digest("hex");
      return timingSafeEqual(expected, sig)
        ? { valid: true, message: "GitHub SHA1 geçerli" }
        : { valid: false, message: "GitHub SHA1 eşleşmedi" };
    }
    return { valid: false, message: "x-hub-signature header yok" };
  }

  if (preset === "shopify") {
    const hmac = lower["x-shopify-hmac-sha256"];
    if (!hmac) return { valid: false, message: "x-shopify-hmac-sha256 yok" };
    const expected = crypto.createHmac("sha256", secret).update(rawBody, "utf8").digest("base64");
    return timingSafeEqual(expected, hmac)
      ? { valid: true, message: "Shopify HMAC geçerli" }
      : { valid: false, message: "Shopify HMAC eşleşmedi" };
  }

  return { valid: false, message: "Bilinmeyen preset" };
}
