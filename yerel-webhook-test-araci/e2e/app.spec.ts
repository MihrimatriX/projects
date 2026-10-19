import { _electron as electron, expect, test } from "@playwright/test";
import crypto from "crypto";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));

test("sunucu otomatik başlar, webhook yakalanır, maskelenir, aranır, mock + imza çalışır", async () => {
  // Ayrı userData: kullanıcının gerçek hookyerel.db dosyasına dokunulmaz.
  const userData = fs.mkdtempSync(path.join(os.tmpdir(), "hook-e2e-"));
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.VITE_DEV_SERVER_URL;

  const app = await electron.launch({ args: [root, `--user-data-dir=${userData}`], env });
  try {
    const page = await app.firstWindow();

    // Açılışta sunucu kendiliğinden dinler (8787 doluysa sonraki port)
    const badge = page.locator(".titlebar-badge");
    await expect(badge).toHaveText(/127\.0\.0\.1:\d+/);
    const port = Number((await badge.textContent())!.split(":")[1]);
    const slug = (await page.locator(".hook-id").first().textContent())!.trim();
    const hookUrl = `http://127.0.0.1:${port}/hook/${slug}`;

    // GitHub imzalı, gizli alan içeren webhook
    const secret = "gh-e2e-secret";
    const body = JSON.stringify({ event: "checkout.completed", password: "cok-gizli", customer: "musteri-42" });
    const sig = "sha256=" + crypto.createHmac("sha256", secret).update(body).digest("hex");
    const res = await fetch(`${hookUrl}/odeme`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: "Bearer abc.def", "X-Hub-Signature-256": sig },
      body,
    });
    expect(res.status).toBe(200);

    const list = page.getByRole("listbox");
    await expect(list.getByRole("option")).toHaveCount(1);
    const detail = page.getByRole("region", { name: "İstek detayı" });
    await expect(detail.getByText(`/hook/${slug}/odeme`)).toBeVisible();
    // Gizli değerler arayüzde maskeli
    await expect(detail.locator(".json-viewer")).toContainText("musteri-42");
    await expect(detail.locator(".json-viewer")).not.toContainText("cok-gizli");
    await expect(detail.getByText("Bearer abc.def")).toHaveCount(0);

    // İmza doğrulama ham gövde üzerinden yapılır
    await detail.getByText("İmza doğrulama").click();
    await detail.getByLabel("İmza preset").selectOption("github");
    await detail.getByLabel("Webhook secret").fill(secret);
    await detail.getByRole("button", { name: "Doğrula", exact: true }).click();
    await expect(detail.getByText("İmza geçerli")).toBeVisible();

    // Gövde içinde arama
    const filter = page.getByLabel("İstek filtresi");
    await filter.fill("musteri-42");
    await expect(list.getByRole("option")).toHaveCount(1);
    await filter.fill("bulunmayan-deger");
    await expect(list.getByRole("option")).toHaveCount(0);
    await filter.fill("");

    // Mock kuralı: PUT isteğine 418
    await page.getByRole("button", { name: "Mock kuralları" }).click();
    const mock = page.getByRole("dialog");
    await mock.getByLabel("Mock method").fill("PUT");
    await mock.getByLabel("Mock durum kodu").fill("418");
    await mock.getByLabel("Mock yanıt gövdesi").fill('{"mock":true}');
    await mock.getByRole("button", { name: "Kural ekle" }).click();
    await expect(mock.getByText("PUT * → 418")).toBeVisible();
    await mock.getByRole("button", { name: "Kapat" }).first().click();

    const put = await fetch(hookUrl, { method: "PUT", body: "x" });
    expect(put.status).toBe(418);
    expect(await put.json()).toEqual({ mock: true });
    await expect(list.getByRole("option")).toHaveCount(2);

    // PUT çipi ile yöntem filtresi
    await page.getByRole("button", { name: "PUT", exact: true }).click();
    await expect(list.getByRole("option")).toHaveCount(1);

    // Bilinmeyen slug 404
    expect((await fetch(`http://127.0.0.1:${port}/hook/yok-boyle`, { method: "POST" })).status).toBe(404);
  } finally {
    await app.close();
    fs.rmSync(userData, { recursive: true, force: true });
  }
});
