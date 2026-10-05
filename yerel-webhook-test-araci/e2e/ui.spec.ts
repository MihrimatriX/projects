import { expect, test } from "@playwright/test";
import fs from "fs";
import net from "net";
import path from "path";
import { launch, mockSaveDialog } from "./helpers";

// Arayüz envanteri: docs/arayuz-testi.md. Her test kendi geçici veri klasörünü kullanır.

test("sunucu, endpoint'ler, ayarlar, kısayollar ve dışa aktarma", async () => {
  const ctx = await launch();
  const { app, page, dir } = ctx;
  try {
    const sidebar = page.getByRole("complementary", { name: "Endpoint listesi" });
    const toast = page.locator(".toast");

    // Sunucu: çalışırken port kilitli; durdur / başlat
    await expect(sidebar.getByLabel("Port")).toBeDisabled();
    await sidebar.getByRole("button", { name: "Durdur" }).click();
    await expect(page.locator(".titlebar-badge")).toHaveText("127.0.0.1");
    await expect(sidebar.getByLabel("Port")).toBeEnabled();
    // Seçilen port doluysa sonraki port denenir
    const blocker = net.createServer();
    await new Promise<void>((r) => blocker.listen(0, "127.0.0.1", () => r()));
    const busy = (blocker.address() as net.AddressInfo).port;
    await sidebar.getByLabel("Port").fill(String(busy));
    await sidebar.getByRole("button", { name: "Sunucuyu başlat" }).click();
    await expect(page.locator(".titlebar-badge")).not.toHaveText(`127.0.0.1:${busy}`);
    await expect(page.locator(".titlebar-badge")).toHaveText(/127\.0\.0\.1:\d+/);
    await expect(toast).toContainText("dinliyor");
    blocker.close();

    // Endpoint oluşturma penceresi: İptal, ×, Esc, Ctrl+N, oluştur
    const create = page.getByRole("dialog", { name: "Yeni endpoint" });
    await sidebar.getByRole("button", { name: "+ Endpoint oluştur" }).click();
    await create.getByRole("button", { name: "İptal" }).click();
    await expect(create).toHaveCount(0);
    await sidebar.getByRole("button", { name: "+ Endpoint oluştur" }).click();
    await create.getByRole("button", { name: "Kapat" }).click();
    await page.keyboard.press("Control+n");
    await expect(create).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(create).toHaveCount(0);
    await page.keyboard.press("Control+n");
    await create.getByRole("button", { name: "Endpoint oluştur" }).click();
    await expect(page.locator(".hook-id")).toHaveCount(2);
    await expect(toast).toContainText("Endpoint oluşturuldu");

    // Endpoint seçimi, URL kopyalama (düğme + Ctrl+L)
    const slugs = await page.locator(".hook-id").allTextContents();
    await sidebar.getByRole("button", { name: `${slugs[1]} URL kopyala` }).click();
    await page.locator(".endpoint-card").first().click();
    await expect(page.locator(".endpoint-card").first()).toHaveClass(/active/);
    await page.locator("body").click({ position: { x: 700, y: 400 } });
    await page.keyboard.press("Control+l");
    await expect.poll(ctx.copied).toEqual([
      expect.stringContaining(`/hook/${slugs[1]}`),
      expect.stringContaining(`/hook/${slugs[0]}`),
    ]);

    // Endpoint silme: ilk tık onay ister, odak kaybında vazgeçilir, ikinci tık siler
    const del = sidebar.getByRole("button", { name: `${slugs[1]} endpoint sil` });
    await del.click();
    await expect(sidebar.getByRole("button", { name: `${slugs[1]} silinsin mi? Onayla` })).toBeVisible();
    await sidebar.getByRole("button", { name: `${slugs[1]} silinsin mi? Onayla` }).click();
    await expect(page.locator(".hook-id")).toHaveCount(1);
    await expect(sidebar.getByRole("button", { name: /endpoint sil/ })).toHaveCount(0); // son endpoint silinemez

    // Kısayol yardımı: ?, ×, Esc
    const help = page.getByRole("dialog", { name: "Klavye kısayolları" });
    await page.keyboard.press("?");
    await expect(help).toContainText("Ctrl+l");
    await help.getByRole("button", { name: "Kapat" }).click();
    await page.keyboard.press("?");
    await page.keyboard.press("Escape");
    await expect(help).toHaveCount(0);

    // Ayarlar: geçersiz port Kaydet'i kapatır; anahtarlar, seçimler kaydedilir
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    await sidebar.getByRole("button", { name: "Ayarlar" }).click();
    await settings.getByLabel("Varsayılan port").fill("80");
    await expect(settings.getByText("Port 1024-65535")).toBeVisible();
    await expect(settings.getByRole("button", { name: "Kaydet" })).toBeDisabled();
    await settings.getByLabel("Varsayılan port").fill("9876");
    await expect(settings.getByLabel("localhost-only")).toBeDisabled();
    for (const name of ["Açılışta sunucuyu başlat", "Secret maskeleme"]) {
      await expect(settings.getByLabel(name)).toHaveAttribute("aria-pressed", "true");
      await settings.getByLabel(name).click();
      await expect(settings.getByLabel(name)).toHaveAttribute("aria-pressed", "false");
    }
    await settings.getByLabel("Maksimum body boyutu").selectOption("1024000");
    await settings.getByLabel("Global retention limit").selectOption("5000");
    await page.keyboard.press("r"); // pencere açıkken kısayollar arka planda çalışmaz
    await settings.getByRole("button", { name: "Kaydet" }).click();
    await expect(settings).toHaveCount(0);
    await expect(toast).toContainText("Ayarlar kaydedildi");
    await sidebar.getByRole("button", { name: "Ayarlar" }).click();
    await expect(settings.getByLabel("Varsayılan port")).toHaveValue("9876");
    await expect(settings.getByLabel("Secret maskeleme")).toHaveAttribute("aria-pressed", "false");
    await expect(settings.getByLabel("Maksimum body boyutu")).toHaveValue("1024000");
    await expect(settings.getByLabel("Global retention limit")).toHaveValue("5000");
    // Maskeleme geri açılır; İptal değişikliği atar
    await settings.getByLabel("Secret maskeleme").click();
    await settings.getByRole("button", { name: "Kaydet" }).click();
    await sidebar.getByRole("button", { name: "Ayarlar" }).click();
    await settings.getByLabel("Açılışta sunucuyu başlat").click();
    await settings.getByRole("button", { name: "İptal" }).click();
    await sidebar.getByRole("button", { name: "Ayarlar" }).click();
    await expect(settings.getByLabel("Açılışta sunucuyu başlat")).toHaveAttribute("aria-pressed", "false");

    // Dışa aktarma: iptal + kaydet
    const out = path.join(dir, "gunluk.json");
    await mockSaveDialog(app, ["", out]);
    await settings.getByRole("button", { name: "Günlüğü dışa aktar" }).click();
    await expect(toast).toContainText("İptal edildi");
    await settings.getByRole("button", { name: "Günlüğü dışa aktar" }).click();
    await expect(toast).toContainText("Dışa aktarıldı");
    const exported = JSON.parse(fs.readFileSync(out, "utf8"));
    expect(exported.endpoints).toHaveLength(1);
    await settings.getByRole("button", { name: "Kapat" }).click();
    await expect(settings).toHaveCount(0);
  } finally {
    await ctx.close();
  }
});

test("istek listesi, detay, filtre, replay, curl, imza, mock kuralları, silme", async () => {
  const ctx = await launch();
  const { page } = ctx;
  try {
    const hook = await ctx.hookUrl();
    const list = page.getByRole("listbox", { name: "İstekler" });
    const detail = page.getByRole("region", { name: "İstek detayı" });
    const toast = page.locator(".toast");

    await expect(list).toContainText("Henüz istek yok");
    await fetch(`${hook}/siparis`, { method: "POST", headers: { "Content-Type": "application/json" }, body: '{"id":1}' });
    await fetch(`${hook}/durum?x=1`);
    await fetch(`${hook}/fatura`, { method: "DELETE" });
    await expect(list.getByRole("option")).toHaveCount(3);
    await expect(list.getByRole("option").first()).toHaveAttribute("aria-selected", "true"); // son gelen seçilir

    // Klavye ile gezinme
    await page.locator("body").click({ position: { x: 700, y: 400 } });
    await page.keyboard.press("ArrowDown");
    await expect(list.getByRole("option").nth(1)).toHaveAttribute("aria-selected", "true");
    await page.keyboard.press("ArrowUp");
    await page.keyboard.press("ArrowUp"); // başa sarar
    await expect(list.getByRole("option").nth(2)).toHaveAttribute("aria-selected", "true");
    await expect(detail).toContainText("/siparis");

    // Bölümler açılır/kapanır
    for (const name of ["İmza doğrulama", "Headers", "Body"]) {
      const header = detail.getByRole("button", { name: new RegExp(`^${name}`) });
      const before = await header.getAttribute("aria-expanded");
      await header.click();
      await expect(header).toHaveAttribute("aria-expanded", before === "true" ? "false" : "true");
    }
    await expect(detail.getByRole("button", { name: /^İmza doğrulama/ })).toHaveAttribute("aria-expanded", "true");

    // Yanlış secret -> imza başarısız
    await detail.getByLabel("İmza preset").selectOption("stripe");
    await detail.getByLabel("Webhook secret").fill("yanlis");
    await detail.getByRole("button", { name: "Doğrula", exact: true }).click();
    await expect(detail.getByText("İmza başarısız")).toBeVisible();

    // curl (düğme + c), replay (düğme + r)
    await detail.getByRole("button", { name: "curl kopyala (c)" }).click();
    await page.locator("body").click({ position: { x: 700, y: 400 } });
    await page.keyboard.press("c");
    await expect.poll(async () => (await ctx.copied()).filter((t) => t.startsWith("curl")).length).toBe(2);
    expect((await ctx.copied())[0]).toContain("/siparis");
    await detail.getByRole("button", { name: "Yeniden gönder (r)" }).click();
    await expect(toast).toContainText("Yeniden gönderildi");
    await expect(list.getByRole("option")).toHaveCount(4);
    await page.locator("body").click({ position: { x: 700, y: 400 } });
    await page.keyboard.press("r");
    await expect(list.getByRole("option")).toHaveCount(5);

    // Filtre: f ve / odaklar, yöntem çipleri aria-pressed, eşleşme yok mesajı, temizle
    const filter = page.getByLabel("İstek filtresi");
    await page.locator("body").click({ position: { x: 700, y: 400 } });
    await page.keyboard.press("f");
    await expect(filter).toBeFocused();
    await filter.press("Escape");
    await page.locator("body").click({ position: { x: 700, y: 400 } });
    await page.keyboard.press("/");
    await expect(filter).toBeFocused();
    await filter.fill("fatura");
    await expect(list.getByRole("option")).toHaveCount(1);
    await filter.fill("");
    for (const [method, count] of [["GET", 1], ["DELETE", 1], ["POST", 3]] as const) {
      const chip = page.getByRole("button", { name: method, exact: true });
      await chip.click();
      await expect(chip).toHaveAttribute("aria-pressed", "true");
      await expect(list.getByRole("option")).toHaveCount(count);
      await chip.click();
    }
    await page.getByRole("button", { name: "PATCH", exact: true }).click();
    await expect(list).toContainText("Filtreyle eşleşen istek yok");
    await page.getByRole("button", { name: "Filtreyi temizle" }).click();
    await expect(list.getByRole("option")).toHaveCount(5);

    // Mock kuralları: boş durum, ekle, kısayollar pencerede çalışmaz, sil, Esc
    await page.getByRole("button", { name: "Mock kuralları" }).click();
    const mock = page.getByRole("dialog", { name: "Mock yanıt kuralları" });
    await expect(mock).toContainText("Henüz kural yok");
    await mock.getByLabel("Mock method").fill("PATCH");
    await mock.getByLabel("Mock path regex").fill("^/hook/.+/odeme");
    await mock.getByLabel("Mock durum kodu").fill("202");
    await mock.getByLabel("Mock yanıt gövdesi").fill("kabul");
    await mock.getByRole("button", { name: "Kural ekle" }).click();
    await expect(mock.getByText("PATCH ^/hook/.+/odeme → 202")).toBeVisible();
    await page.keyboard.press("ArrowDown"); // arkadaki seçim değişmemeli
    const res = await fetch(`${hook}/odeme`, { method: "PATCH", body: "x" });
    expect(res.status).toBe(202);
    expect(await res.text()).toBe("kabul");
    expect((await fetch(`${hook}/baska`, { method: "PATCH" })).status).toBe(200);
    await mock.getByRole("button", { name: "Kuralı sil: PATCH ^/hook/.+/odeme → 202" }).click();
    await expect(mock).toContainText("Henüz kural yok");
    await page.keyboard.press("Escape");
    await expect(mock).toHaveCount(0);
    await expect(list.getByRole("option")).toHaveCount(7);

    // İstek silme ve tümünü silme (onaylı)
    await list.getByRole("option").first().click();
    await detail.getByRole("button", { name: "İsteği sil" }).click();
    await expect(toast).toContainText("İstek silindi");
    await expect(list.getByRole("option")).toHaveCount(6);
    await expect(detail).toContainText("Detay için listeden bir istek seçin");
    await page.getByRole("button", { name: "Tüm istekleri sil" }).click();
    await expect(list.getByRole("option")).toHaveCount(6);
    await page.getByRole("button", { name: "Emin misiniz? Tümünü sil" }).click();
    await expect(list).toContainText("Henüz istek yok");
    await expect(page.locator(".endpoint-card")).toContainText("0 istek");
  } finally {
    await ctx.close();
  }
});

test("dar pencere / yüksek DPI (%150): endpoint çekmecesi", async () => {
  const ctx = await launch();
  const { app, page } = ctx;
  try {
    await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].webContents.setZoomFactor(1.5));
    const toggle = page.getByRole("button", { name: "Endpoint'ler" });
    await expect(toggle).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    await toggle.click();
    await expect(toggle).toHaveAttribute("aria-expanded", "true");
    await expect(page.locator(".sidebar")).toHaveClass(/open/);
    await page.locator(".endpoint-card").first().click(); // seçim çekmeceyi kapatır
    await expect(toggle).toHaveAttribute("aria-expanded", "false");
    await toggle.click();
    await page.keyboard.press("Escape");
    await expect(toggle).toHaveAttribute("aria-expanded", "false");
  } finally {
    await ctx.close();
  }
});
