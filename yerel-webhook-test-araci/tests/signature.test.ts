import crypto from "crypto";
import { describe, expect, it } from "vitest";
import { verifyWebhookSignature } from "../electron/signature";

const body = '{"id":"evt_1","type":"payment_intent.succeeded"}';
const secret = "whsec_test";
const hmac = (alg: string, data: string, enc: "hex" | "base64" = "hex") =>
  crypto.createHmac(alg, secret).update(data).digest(enc);

describe("imza doğrulama", () => {
  it("Stripe: t + v1 HMAC; anahtar rotasyonunda birden fazla v1", () => {
    const sig = hmac("sha256", `123.${body}`);
    expect(verifyWebhookSignature("stripe", secret, body, { "Stripe-Signature": `t=123,v1=${sig}` }).valid).toBe(true);
    const rotated = `t=123,v1=${"0".repeat(64)},v1=${sig}`;
    expect(verifyWebhookSignature("stripe", secret, body, { "stripe-signature": rotated }).valid).toBe(true);
    expect(verifyWebhookSignature("stripe", secret, `${body} `, { "stripe-signature": `t=123,v1=${sig}` }).valid).toBe(false);
    expect(verifyWebhookSignature("stripe", secret, body, { "stripe-signature": "bozuk" }).message).toMatch(/format/);
  });

  it("GitHub: sha256 ve sha1", () => {
    const sha256 = { "x-hub-signature-256": `sha256=${hmac("sha256", body)}` };
    expect(verifyWebhookSignature("github", secret, body, sha256).valid).toBe(true);
    expect(verifyWebhookSignature("github", "yanlis", body, sha256).valid).toBe(false);
    expect(verifyWebhookSignature("github", secret, body, { "x-hub-signature": `sha1=${hmac("sha1", body)}` }).valid).toBe(true);
  });

  it("Shopify: base64 HMAC", () => {
    const headers = { "x-shopify-hmac-sha256": hmac("sha256", body, "base64") };
    expect(verifyWebhookSignature("shopify", secret, body, headers).valid).toBe(true);
    expect(verifyWebhookSignature("shopify", secret, body, {}).valid).toBe(false);
  });

  it("boş gizli anahtar reddedilir", () => {
    expect(verifyWebhookSignature("github", "  ", body, {}).message).toBe("Gizli anahtar gerekli");
  });
});
