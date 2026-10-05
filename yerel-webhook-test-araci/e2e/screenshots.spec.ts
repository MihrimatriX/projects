import { expect, test } from "@playwright/test";
import crypto from "crypto";
import fs from "fs";
import path from "path";
import { launch, root } from "./helpers";

// README görüntüsü: `$env:HOOK_SCREENSHOTS=1; npx playwright test screenshots` -> docs/ekran.png
// Kurgusal örnek istekler, geçici veri klasörü; gerçek sır / kişisel veri görünmez.
test.skip(!process.env.HOOK_SCREENSHOTS, "Yalnızca HOOK_SCREENSHOTS=1 ile");

test("README ekran görüntüsü", async () => {
  const ctx = await launch();
  const { app, page } = ctx;
  try {
    await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].setContentSize(1280, 800));
    const hook = await ctx.hookUrl();
    const secret = "whsec_ornek";
    const send = (p: string, method: string, body?: object, headers: Record<string, string> = {}) =>
      fetch(`${hook}${p}`, {
        method,
        headers: body ? { "Content-Type": "application/json", ...headers } : headers,
        body: body ? JSON.stringify(body) : undefined,
      });
    await send("/github", "POST", { action: "opened", number: 42 }, { "X-GitHub-Event": "pull_request" });
    await send("/saglik", "GET");
    await send("/kargo", "PUT", { takip: "TR123456", durum: "yolda" });
    const body = JSON.stringify({ id: "evt_1001", type: "checkout.session.completed", data: { amount: 24900, currency: "try", customer: "musteri_42" } });
    const t = Math.floor(Date.now() / 1000);
    const sig = crypto.createHmac("sha256", secret).update(`${t}.${body}`).digest("hex");
    await fetch(`${hook}/odeme`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Stripe-Signature": `t=${t},v1=${sig}`, Authorization: "Bearer sk_test_ornek" },
      body,
    });
    const list = page.getByRole("listbox", { name: "İstekler" });
    await expect(list.getByRole("option")).toHaveCount(4);
    const detail = page.getByRole("region", { name: "İstek detayı" });
    await detail.getByRole("button", { name: /^İmza doğrulama/ }).click();
    await detail.getByLabel("Webhook secret").fill(secret);
    await detail.getByRole("button", { name: "Doğrula", exact: true }).click();
    await expect(detail.getByText("İmza geçerli")).toBeVisible();
    await expect(page.locator(".toast")).not.toHaveClass(/show/, { timeout: 8000 });
    fs.mkdirSync(path.join(root, "docs"), { recursive: true });
    await page.screenshot({ path: path.join(root, "docs", "ekran.png") });
  } finally {
    await ctx.close();
  }
});
