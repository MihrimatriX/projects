import { expect, test } from "@playwright/test";
import fs from "fs";
import path from "path";
import { importDemo, launch, root } from "./helpers";

// README görüntüleri: `$env:MAIL_SCREENSHOTS=1; npx playwright test screenshots` -> docs/*.png
// Kurgusal örnek veri (@ornek.com), geçici veri klasörü; gerçek hesap / kişisel veri görünmez.
test.skip(!process.env.MAIL_SCREENSHOTS, "Yalnızca MAIL_SCREENSHOTS=1 ile");

test("README ekran görüntüleri", async () => {
  const ctx = await launch({ onboardingDone: true, theme: "light" });
  const { app, page, dir } = ctx;
  const docs = path.join(root, "docs");
  fs.mkdirSync(docs, { recursive: true });
  try {
    // Şifresiz örnek hesap: kenar çubuğunda ad görünür, senkron denenmez.
    fs.writeFileSync(
      path.join(dir, "accounts.json"),
      JSON.stringify([{ id: "demo", email: "ben@ornek.com", displayName: "Deniz Yılmaz", server: "imap.ornek.com", smtpServer: "smtp.ornek.com", provider: "custom" }])
    );
    await importDemo(ctx);
    await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].setContentSize(1280, 800));
    const inbox = page.getByRole("list", { name: "Gelen Kutusu" });
    await inbox.getByRole("listitem").filter({ hasText: "Fatura" }).click();
    await expect(page.frameLocator('iframe[title="Mail içeriği"]').getByText("12.500 TL")).toBeVisible();
    await expect(page.locator(".status-bar")).toHaveCount(0, { timeout: 8000 });
    await page.screenshot({ path: path.join(docs, "ekran.png") });

    // Yeni mail + şablon + takip
    await page.keyboard.press("c");
    const compose = page.getByRole("dialog", { name: "Yeni mesaj" });
    await compose.getByLabel("Kime").fill("elif.kaya@ornek.com");
    await compose.getByLabel("Konu").fill("Sprint 14 tahminleri");
    await compose.getByLabel("Mesaj").fill("Merhaba Elif,\n\nTahminleri perşembe akşamına kadar tabloya işliyorum.\n\nDeniz");
    await compose.getByLabel("Yanıt takibi başlat").check();
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(docs, "ekran-yeni-mail.png") });
    await compose.getByRole("button", { name: "İptal" }).click();

    // Koyu tema + Takip klasörü
    await app.evaluate(({ nativeTheme }) => (nativeTheme.themeSource = "dark"));
    await page.getByRole("navigation", { name: "Klasörler" }).getByRole("button", { name: /^Takip/ }).click();
    await page.waitForTimeout(600);
    await page.screenshot({ path: path.join(docs, "ekran-koyu.png") });
  } finally {
    await ctx.close();
  }
});
