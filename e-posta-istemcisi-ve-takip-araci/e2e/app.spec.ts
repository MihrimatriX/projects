import { _electron as electron, expect, test } from "@playwright/test";
import fs from "fs";
import net from "net";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";
import { startFakeSmtp } from "../test/fakeSmtp";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const PASSWORD = "E2e-Gizli-Sifre-987";

/** Kapalı bir port: IMAP bağlantısı hızlıca reddedilir (gerçek sunucuya çıkılmaz). */
async function closedPort() {
  const srv = net.createServer();
  await new Promise<void>((r) => srv.listen(0, "127.0.0.1", () => r()));
  const port = (srv.address() as net.AddressInfo).port;
  await new Promise((r) => srv.close(r));
  return port;
}

test("hesap kur (şifre safeStorage ile), SMTP ile gönder, Gönderilenler'de gör", async () => {
  // Ayrı userData: kullanıcının gerçek posta kutusu/hesaplarına dokunulmaz.
  const userData = fs.mkdtempSync(path.join(os.tmpdir(), "mail-e2e-"));
  fs.writeFileSync(
    path.join(userData, "settings.json"),
    JSON.stringify({ onboardingDone: true, useIdle: false, backgroundSync: false, minimizeToTray: false })
  );
  const smtp = await startFakeSmtp("ben@test.local", PASSWORD);
  const imapPort = await closedPort();
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.VITE_DEV_SERVER_URL;

  const app = await electron.launch({ args: [root, `--user-data-dir=${userData}`], env });
  try {
    const page = await app.firstWindow();
    await expect(page.getByText("E-posta istemcisine hoş geldiniz").first()).toBeVisible();

    // Hesap ekle
    await page.getByRole("button", { name: "Ayarlar" }).click();
    const dialog = page.getByRole("dialog");
    await dialog.getByLabel("Görünen ad").fill("Ben");
    await dialog.getByLabel("E-posta").fill("ben@test.local");
    await dialog.getByLabel("IMAP sunucu").fill("127.0.0.1");
    await dialog.getByLabel("IMAP port").fill(String(imapPort));
    await dialog.getByLabel("SMTP sunucu").fill("127.0.0.1");
    await dialog.getByLabel("SMTP port").fill(String(smtp.port));
    await dialog.getByLabel("Şifre").fill(PASSWORD);
    await dialog.getByRole("button", { name: "Bağlantıyı test et" }).click();
    await expect(dialog.getByRole("status")).toContainText("SMTP OK", { timeout: 30_000 });
    await dialog.getByRole("button", { name: "Kaydet" }).click();
    await expect(dialog).toHaveCount(0);

    // Şifre diske düz metin yazılmadı
    const creds = path.join(userData, "credentials.json");
    await expect.poll(() => fs.existsSync(creds)).toBe(true);
    for (const f of ["credentials.json", "accounts.json", "settings.json", "mailbox.db"]) {
      const p = path.join(userData, f);
      if (!fs.existsSync(p)) continue;
      const raw = fs.readFileSync(p);
      expect(raw.toString("utf8")).not.toContain(PASSWORD);
      expect(raw.toString("utf8")).not.toContain(Buffer.from(PASSWORD).toString("base64"));
    }

    // Ayarlar tekrar açılınca şifre arayüze gelmez, "kayıtlı" ipucu görünür
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await expect(dialog.getByLabel("Şifre")).toHaveValue("");
    await expect(dialog.getByLabel("Şifre")).toHaveAttribute("placeholder", /Kayıtlı/);
    await dialog.getByRole("button", { name: "Kapat" }).click();

    // Yeni mesaj gönder
    await page.keyboard.press("c");
    await page.getByLabel("Kime").fill("alici@test.local");
    await page.getByLabel("Konu").fill("E2E deneme mesaji");
    await page.getByLabel("Mesaj", { exact: true }).fill("Merhaba, bu bir e2e testidir.");
    await page.getByLabel("Yanıt takibi başlat").check();
    await page.getByRole("button", { name: "Gönder", exact: true }).click();
    await expect.poll(() => smtp.mails.length, { timeout: 30_000 }).toBe(1);
    expect(smtp.mails[0]).toContain("Subject: E2E deneme mesaji");
    expect(smtp.mails[0]).toContain("Merhaba, bu bir e2e testidir.");

    await expect(page.getByRole("list", { name: "Gönderilmiş" }).getByText("E2E deneme mesaji")).toBeVisible();
    await page.getByRole("navigation", { name: "Klasörler" }).getByRole("button", { name: /^Takip/ }).click();
    await expect(page.getByRole("list", { name: "Takip" }).getByText("E2E deneme mesaji")).toBeVisible();

    // SMTP kapalıyken gönderim hatası modalda gösterilir, yazılan mesaj kaybolmaz
    await smtp.close();
    await page.keyboard.press("c");
    await page.getByLabel("Kime").fill("alici@test.local");
    await page.getByLabel("Konu").fill("Gonderilemeyen");
    await page.getByRole("button", { name: "Gönder", exact: true }).click();
    await expect(page.getByRole("alert")).toBeVisible({ timeout: 30_000 });
    await expect(page.getByLabel("Konu")).toHaveValue("Gonderilemeyen");
  } finally {
    await app.close();
    await smtp.close().catch(() => {});
    fs.rmSync(userData, { recursive: true, force: true });
  }
});
