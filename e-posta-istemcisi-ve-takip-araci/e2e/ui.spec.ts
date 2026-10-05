import { expect, test, type Page } from "@playwright/test";
import fs from "fs";
import path from "path";
import { importDemo, launch, mockDialogs } from "./helpers";

// Arayüz envanteri: docs/arayuz-testi.md. Her test kendi geçici veri klasörünü kullanır.

const status = (page: Page) => page.locator(".status-bar");
const reader = (page: Page) => page.locator(".reader-subject");

test("karşılama, yardım, hakkında, şablonlar, ayarlar ve yedekleme", async () => {
  const ctx = await launch(null);
  const { app, page, dir } = ctx;
  try {
    // İlk açılış: karşılama; Esc kapatır ve bir daha gösterilmez
    const welcome = page.getByRole("dialog", { name: "E-posta istemcisine hoş geldiniz" });
    await expect(welcome).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(welcome).toHaveCount(0);
    await expect.poll(() => ctx.settings().onboardingDone).toBe(true);

    // Yardım: F1, Esc, Tamam
    const help = page.getByRole("dialog", { name: "Klavye Kısayolları" });
    await page.keyboard.press("F1");
    await expect(help).toContainText(/geri al/i);
    await page.keyboard.press("Escape");
    await expect(help).toHaveCount(0);
    await page.keyboard.press("F1");
    await help.getByRole("button", { name: "Tamam" }).click();
    await expect(help).toHaveCount(0);

    // Hesap yokken senkron: anlaşılır mesaj
    await page.getByRole("button", { name: "Senkronize" }).click();
    await expect(status(page)).toContainText("Senkronize edilecek hesap yok");

    // Ayarlar: arka plana tıklamak kapatmaz (yazılanlar kaybolmaz)
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await expect(settings).toBeVisible();
    await page.locator(".modal-backdrop").click({ position: { x: 4, y: 4 } });
    await expect(settings).toBeVisible();

    // Sağlayıcı profili, hesap ekle/kaldır, bağlantı testi, OAuth doğrulaması
    await settings.getByLabel("Hesap 1 sağlayıcı").selectOption("gmail");
    await expect(settings.getByLabel("IMAP sunucu")).toHaveValue("imap.gmail.com");
    await expect(settings.getByLabel("SMTP sunucu")).toHaveValue("smtp.gmail.com");
    await settings.getByLabel("Hesap 1 sağlayıcı").selectOption("outlook");
    await expect(settings.getByLabel("IMAP sunucu")).toHaveValue("outlook.office365.com");
    await settings.getByRole("button", { name: "Bağlantıyı test et" }).click();
    await expect(settings.getByRole("status")).toContainText("gerekli");
    await settings.getByRole("button", { name: "Google ile bağlan" }).click();
    await expect(settings.getByRole("status")).toContainText("Client ID gerekli");
    await settings.getByRole("button", { name: /Hesap ekle/ }).click();
    await expect(settings.getByLabel("Hesap 2 sağlayıcı")).toBeVisible();
    await settings.getByRole("button", { name: "Hesap 2 kaldır" }).click();
    await expect(settings.getByLabel("Hesap 2 sağlayıcı")).toHaveCount(0);

    // Görünüm + senkron ayarları kaydedilir; boş hesap kartı kaydedilmez
    await settings.getByLabel("Tema").selectOption("dark");
    await settings.getByLabel("Önbellek süresi (gün)").fill("60");
    await settings.getByLabel("Arka plan senkron aralığı (dakika)").fill("30");
    for (const name of [
      "Arka plan IMAP senkronu",
      "Yeni mail bildirimi",
      "Takip süresi dolunca bildir",
      "IMAP IDLE (pencere açıkken anlık güncelleme)",
      "Kapatınca tepsiye küçült",
    ]) {
      await settings.getByLabel(name).click();
    }
    await settings.getByRole("button", { name: "Kaydet" }).click();
    await expect(settings).toHaveCount(0);
    await expect(status(page)).toContainText("Ayarlar kaydedildi");
    const saved = ctx.settings();
    expect(saved).toMatchObject({
      theme: "dark",
      cacheDays: 60,
      syncIntervalMinutes: 30,
      backgroundSync: false,
      notifyNewMail: false,
      notifyTrackingDue: false,
      useIdle: false,
      minimizeToTray: false,
    });
    await expect.poll(() => page.evaluate(() => matchMedia("(prefers-color-scheme: dark)").matches)).toBe(true);
    expect(JSON.parse(fs.readFileSync(path.join(dir, "accounts.json"), "utf8"))).toEqual([]);
    await expect(page.locator(".account-name")).toHaveText("Hesap ekle");

    // Ayarlar yeniden açılınca kayıtlı değerler gelir; Esc kapatır
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await expect(settings.getByLabel("Tema")).toHaveValue("dark");
    await settings.getByLabel("Tema").selectOption("light");
    await settings.getByRole("button", { name: "Kaydet" }).click();
    await expect.poll(() => page.evaluate(() => matchMedia("(prefers-color-scheme: dark)").matches)).toBe(false);

    // Hakkında (sürüm), Yardım düğmesi
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await settings.getByRole("button", { name: "Hakkında" }).click();
    const about = page.getByRole("dialog", { name: "E-posta İstemcisi" });
    await expect(about).toContainText(/Sürüm \d+\.\d+\.\d+/);
    await about.getByRole("button", { name: "Kapat" }).click();
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await settings.getByRole("button", { name: "Yardım (F1)" }).click();
    await expect(help).toBeVisible();
    await page.keyboard.press("Escape");

    // Şablonlar: ekle (boş ad kaydedilemez), vazgeç, düzenle, sil
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await settings.getByRole("button", { name: "Şablonlar" }).click();
    const tpl = page.getByRole("dialog", { name: "Şablonlar" });
    await expect(tpl.getByRole("listitem")).toHaveCount(2);
    await tpl.getByRole("button", { name: "+ Yeni şablon" }).click();
    await tpl.getByRole("button", { name: "Vazgeç" }).click();
    await expect(tpl.getByLabel("Ad")).toHaveCount(0);
    await tpl.getByRole("button", { name: "+ Yeni şablon" }).click();
    await tpl.getByLabel("Ad").fill("");
    await expect(tpl.getByRole("button", { name: "Şablonu kaydet" })).toBeDisabled();
    await tpl.getByLabel("Ad").fill("Toplantı");
    await tpl.getByLabel("Konu").fill("Toplantı: {konu}");
    await tpl.getByLabel("Gövde").fill("Merhaba {ad}, uygun musunuz?");
    await tpl.getByRole("button", { name: "Şablonu kaydet" }).click();
    await expect(tpl.getByRole("listitem")).toHaveCount(3);
    await tpl.getByRole("button", { name: "Toplantı şablonunu düzenle" }).click();
    await tpl.getByLabel("Ad").fill("Toplantı daveti");
    await tpl.getByRole("button", { name: "Şablonu kaydet" }).click();
    await expect(tpl).toContainText("Toplantı daveti");
    await tpl.getByRole("button", { name: "Takip şablonunu sil" }).click();
    await expect(tpl.getByRole("listitem")).toHaveCount(2);
    await page.keyboard.press("Escape");
    await expect(tpl).toHaveCount(0);

    // Yedek: dışa aktar (iptal + kaydet), bozuk dosyayı içe aktarma hatası
    const out = path.join(dir, "yedek.json");
    const bad = path.join(dir, "bozuk.json");
    fs.writeFileSync(bad, "{ bozuk");
    await mockDialogs(app, [[bad]], ["", out]);
    await page.getByRole("button", { name: "Ayarlar" }).click();
    await settings.getByRole("button", { name: "Dışa aktar (JSON)" }).click(); // iptal
    await settings.getByRole("button", { name: "Dışa aktar (JSON)" }).click();
    await expect(settings.getByRole("status")).toHaveText("Yedek dışa aktarıldı");
    const backup = JSON.parse(fs.readFileSync(out, "utf8"));
    expect(backup.messages.length).toBe(1);
    expect(backup.templates.map((t: { name: string }) => t.name)).toContain("Toplantı daveti");
    await settings.getByRole("button", { name: "İçe aktar" }).click();
    await expect(settings.getByRole("status")).toContainText("İçe aktarılamadı: Yedek dosyası okunamadı");
    await settings.getByRole("button", { name: "Kapat" }).click();
  } finally {
    await ctx.close();
  }
});

test("klasörler, okuma, kısayollar, erteleme, takip, arşiv, çöp ve geri al", async () => {
  const ctx = await launch();
  const { page } = ctx;
  try {
    await importDemo(ctx);
    const nav = page.getByRole("navigation", { name: "Klasörler" });
    const folder = (name: string) => nav.getByRole("button", { name: new RegExp(`^${name}`) });
    const list = (name: string) => page.getByRole("list", { name });
    const row = (name: string, text: string) => list(name).getByRole("listitem").filter({ hasText: text });
    const inbox = list("Gelen Kutusu");
    const act = (name: string) => page.locator(".reader-actions").getByRole("button", { name, exact: true });

    await expect(inbox.getByRole("listitem")).toHaveCount(7);
    await expect(nav.getByRole("button", { name: /Birleşik/ })).toHaveCount(0); // tek hesap

    // Klavye: j / k / Enter
    await expect(reader(page)).toHaveText("E-posta istemcisine hoş geldiniz");
    await page.keyboard.press("j");
    await expect(reader(page)).toHaveText("Sprint 14 planlama toplantısı");
    await page.keyboard.press("k");
    await expect(reader(page)).toHaveText("E-posta istemcisine hoş geldiniz");
    await page.keyboard.press("j");
    await page.keyboard.press("Enter");
    await expect(page.locator(".mail-row").filter({ hasText: "Sprint 14" })).not.toHaveClass(/unread/);
    await expect(page.locator(".attachment-list")).toContainText("gundem.pdf");

    // Arama: / odaklar, filtreler, boş durum
    await page.keyboard.press("/");
    await expect(page.getByLabel("Mail ara")).toBeFocused();
    await page.keyboard.type("fatura");
    await expect(inbox.getByRole("listitem")).toHaveCount(1);
    await page.getByLabel("Mail ara").fill("zzzz-yok");
    await expect(inbox.getByRole("status")).toContainText("Eşleşen mail yok");
    await page.getByLabel("Mail ara").fill("");
    await expect(inbox.getByRole("listitem")).toHaveCount(7);

    // Klavye odağındaki satır Enter ile açılır
    await row("Gelen Kutusu", "Kahve").focus();
    await page.keyboard.press("Enter");
    await expect(reader(page)).toHaveText("Kahve molası?");

    // HTML mail: korumalı iframe, uzak görsel engelli
    await row("Gelen Kutusu", "Fatura").click();
    await expect(page.getByText("Güvenli HTML görünümü")).toBeVisible();
    await expect(page.frameLocator('iframe[title="Mail içeriği"]').getByText("12.500 TL")).toBeVisible();

    // Yıldız: okuyucu düğmesi ve liste düğmesi, Yıldızlı klasörü
    await expect(act("Yıldızı kaldır")).toHaveAttribute("aria-pressed", "true");
    await act("Yıldızı kaldır").click();
    await expect(act("Yıldızla")).toHaveAttribute("aria-pressed", "false");
    await row("Gelen Kutusu", "Kahve").getByRole("button", { name: "Yıldızla" }).click();
    await folder("Yıldızlı").click();
    await expect(list("Yıldızlı").getByRole("listitem")).toHaveCount(1);
    await expect(list("Yıldızlı")).toContainText("Kahve molası?");
    await folder("Gelen Kutusu").click();

    // Erteleme menüsü: Esc kapatır; Yarın 09:00 -> listeden çıkar, Geri al ile döner
    await row("Gelen Kutusu", "Tasarım").click();
    await page.getByRole("button", { name: "Ertele", exact: true }).click();
    await expect(page.getByRole("menu")).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(page.getByRole("menu")).toHaveCount(0);
    await page.getByRole("button", { name: "Ertele", exact: true }).click();
    await page.getByRole("menuitem", { name: "Yarın 09:00" }).click();
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(0);
    await expect(folder("Ertelenen")).toContainText("1");
    await expect(status(page)).toContainText("Mail ertelendi");
    await status(page).getByRole("button", { name: "Geri al" }).click();
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(1);
    await expect(folder("Ertelenen").locator(".nav-badge")).toHaveCount(0);
    // Özel tarih
    await row("Gelen Kutusu", "Tasarım").click();
    await page.getByRole("button", { name: "Ertele", exact: true }).click();
    await page.getByLabel("Özel tarih").fill("2099-01-01T09:00");
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(0);
    // Ertelenen klasörü: tarih notu, gelen kutusuna geri taşı
    await folder("Ertelenen").click();
    await row("Ertelenen", "Tasarım").click();
    await expect(page.locator(".reader-header")).toContainText("tarihinde gelen kutusuna döner");
    await act("Gelen kutusuna taşı").click();
    await expect(list("Ertelenen").getByRole("status")).toContainText("Ertelenen boş");
    await folder("Gelen Kutusu").click();
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(1);
    // Ctrl+Z ile erteleme geri alınır
    await row("Gelen Kutusu", "Tasarım").click();
    await page.getByRole("button", { name: "Ertele", exact: true }).click();
    await page.getByRole("menuitem", { name: "Gelecek hafta" }).click();
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(0);
    await page.keyboard.press("Control+z");
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(1);
    await row("Gelen Kutusu", "Tasarım").click();
    await page.getByRole("button", { name: "Ertele", exact: true }).click();
    await page.getByRole("menuitem", { name: /akşam 18:00/ }).click();
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(0);
    await status(page).getByRole("button", { name: "Geri al" }).click();
    await expect(row("Gelen Kutusu", "Tasarım")).toHaveCount(1);

    // Yanıt takibi: başlat, Takip klasörü + panel, bırak
    await row("Gelen Kutusu", "Tasarım").click();
    await act("Takip et").click();
    await expect(act("Takibi bırak")).toHaveAttribute("aria-pressed", "true");
    await folder("Takip").click();
    await expect(list("Takip").getByRole("listitem")).toHaveCount(2);
    await nav.locator(".track-item").filter({ hasText: "Teklif dosyası" }).click();
    await expect(reader(page)).toHaveText("Teklif dosyası");
    await expect(page.getByRole("list", { name: "Gönderilmiş" })).toBeVisible();
    await nav.locator(".track-item").filter({ hasText: "Tasarım" }).click();
    await expect(reader(page)).toHaveText("Tasarım geri bildirimi");
    await act("Takibi bırak").click();
    await expect(nav.locator(".track-item").filter({ hasText: "Tasarım" })).toHaveCount(0);

    // Arşiv: düğme + Ctrl+Z, kısayol e, Arşiv klasöründen gelen kutusuna taşı
    await row("Gelen Kutusu", "Kod incelemesi").click();
    await act("Arşivle").click();
    await expect(row("Gelen Kutusu", "Kod incelemesi")).toHaveCount(0);
    await page.keyboard.press("Control+z");
    await expect(status(page)).toContainText("Geri alındı");
    await row("Gelen Kutusu", "Kod incelemesi").click();
    await page.keyboard.press("e");
    await expect(row("Gelen Kutusu", "Kod incelemesi")).toHaveCount(0);
    await folder("Arşiv").click();
    await expect(list("Arşiv").getByRole("listitem")).toHaveCount(2);
    await row("Arşiv", "Bordro").click();
    await act("Gelen kutusuna taşı").click();
    await expect(list("Arşiv").getByRole("listitem")).toHaveCount(1);
    await folder("Gelen Kutusu").click();
    await expect(row("Gelen Kutusu", "Bordro")).toHaveCount(1);

    // Okunmadı (düğme + u), yıldız kısayolu s
    await row("Gelen Kutusu", "Bordro").click();
    await act("Okunmadı").click();
    await expect(status(page)).toContainText("Okunmadı işaretlendi");
    await expect(page.locator(".mail-row").filter({ hasText: "Bordro" })).toHaveClass(/unread/);
    await page.keyboard.press("s");
    await expect(act("Yıldızı kaldır")).toBeVisible();
    await page.keyboard.press("s");
    await expect(act("Yıldızla")).toBeVisible();

    // Sil -> Çöp; Geri yükle; Kalıcı sil + geri al; # kısayolu; Çöpü boşalt (onaylı)
    await row("Gelen Kutusu", "Kahve").click();
    await act("Sil").click();
    await expect(status(page)).toContainText("Çöpe taşındı");
    await folder("Çöp").click();
    await expect(list("Çöp").getByRole("listitem")).toHaveCount(2);
    await row("Çöp", "Son gün").click();
    await act("Geri yükle").click();
    await expect(list("Çöp").getByRole("listitem")).toHaveCount(1);
    await row("Çöp", "Kahve").click();
    await act("Kalıcı sil").click();
    await expect(status(page)).toContainText("Kalıcı silindi");
    await expect(list("Çöp").getByRole("status")).toContainText("Çöp boş");
    await status(page).getByRole("button", { name: "Geri al" }).click();
    await expect(list("Çöp").getByRole("listitem")).toHaveCount(1);
    await folder("Gelen Kutusu").click();
    await expect(row("Gelen Kutusu", "Son gün")).toHaveCount(1);
    await row("Gelen Kutusu", "Son gün").click();
    await page.keyboard.press("#");
    await expect(row("Gelen Kutusu", "Son gün")).toHaveCount(0);
    await page.getByRole("button", { name: "Ayarlar" }).click();
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    const empty = settings.getByRole("button", { name: "Çöpü boşalt" });
    await empty.click();
    await settings.getByRole("button", { name: "Emin misiniz? Kalıcı sil" }).click();
    await expect(status(page)).toContainText("2 mail kalıcı silindi");
    await settings.getByRole("button", { name: "Tümünü okundu işaretle" }).click();
    await expect(status(page)).toContainText("okundu işaretlendi");
    await settings.getByRole("button", { name: "Kapat" }).click();
    await expect(inbox.locator(".mail-row.unread")).toHaveCount(0);

    // Toplu işlemler: her eylem + geri al
    for (const action of ["Okunmadı", "Okundu", "Yıldızla", "Arşivle", "Ertele", "Sil"]) {
      await page.getByRole("button", { name: "Toplu seç" }).click();
      await inbox.getByRole("checkbox").nth(0).check();
      await inbox.getByRole("checkbox").nth(1).check();
      await page.locator(".bulk-bar").getByRole("button", { name: action, exact: true }).click();
      await expect(status(page)).toContainText("2 mail güncellendi");
      await expect(page.getByRole("button", { name: "Toplu seç" })).toBeVisible(); // seçim modu kapandı
      await status(page).getByRole("button", { name: "Geri al" }).click();
      await expect(status(page)).toContainText("Geri alındı");
    }
    await expect(inbox.getByRole("listitem")).toHaveCount(6);
    await page.getByRole("button", { name: "Toplu seç" }).click();
    await page.getByRole("button", { name: "Seçimi kapat" }).click();
    await expect(inbox.getByRole("checkbox")).toHaveCount(0);
  } finally {
    await ctx.close();
  }
});

test("yeni mail, yanıtla, ilet, şablon, ekler ve taslaklar", async () => {
  const ctx = await launch();
  const { app, page, dir } = ctx;
  try {
    await importDemo(ctx);
    const nav = page.getByRole("navigation", { name: "Klasörler" });
    const drafts = page.getByRole("list", { name: "Taslaklar" });

    // Yanıtla (r): değişiklik yoksa Esc taslak oluşturmaz
    await page.getByRole("list", { name: "Gelen Kutusu" }).getByRole("listitem").filter({ hasText: "Sprint 14" }).click();
    await page.keyboard.press("r");
    const reply = page.getByRole("dialog", { name: "Yanıtla" });
    await expect(reply.getByLabel("Kime")).toHaveValue("elif.kaya@ornek.com");
    await expect(reply.getByLabel("Konu")).toHaveValue("Re: Sprint 14 planlama toplantısı");
    await expect(reply.getByLabel("Kime")).toBeFocused();
    await page.keyboard.press("Escape");
    await expect(reply).toHaveCount(0);
    await expect(status(page)).not.toContainText("Taslak");

    // Yazılan yanıt Esc ile kaybolmaz: taslağa kaydedilir
    await page.locator(".reader-actions").getByRole("button", { name: "Yanıtla" }).click();
    await reply.getByLabel("Mesaj").press("Control+Home");
    await reply.getByLabel("Mesaj").pressSequentially("Olur, cuma uygun.");
    await page.locator(".modal-backdrop").click({ position: { x: 4, y: 4 } }); // arka plan kapatmaz
    await expect(reply).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(status(page)).toContainText("Taslak kaydedildi");
    await expect(drafts.getByRole("listitem")).toHaveCount(2);

    // Taslağı aç, düzenle, İptal
    await drafts.getByRole("listitem").filter({ hasText: "Re: Sprint 14" }).click();
    const draft = page.getByRole("dialog", { name: "Taslak düzenle" });
    await expect(draft.getByLabel("Mesaj")).toHaveValue(/^Olur, cuma uygun\./);
    await draft.getByRole("button", { name: "İptal" }).click();
    await expect(draft).toHaveCount(0);

    // İlet (f): alıcı boşken Gönder pasif
    await nav.getByRole("button", { name: /^Gelen Kutusu/ }).click();
    await page.getByRole("list", { name: "Gelen Kutusu" }).getByRole("listitem").filter({ hasText: "Kod incelemesi" }).click();
    await page.keyboard.press("f");
    const fwd = page.getByRole("dialog", { name: "İlet" });
    await expect(fwd.getByLabel("Konu")).toHaveValue("Fwd: Kod incelemesi: ödeme modülü");
    await expect(fwd.getByRole("button", { name: "Gönder", exact: true })).toBeDisabled();
    await expect(fwd.getByLabel("Mesaj")).toHaveValue(/İletilen mesaj/);
    await fwd.getByRole("button", { name: "İptal" }).click(); // İptal = vazgeç, taslak yok

    // Yeni mail: düğmeler (kenar çubuğu + c), şablon, takip süresi, okundu bildirimi, ekler
    await nav.getByRole("button", { name: "Yeni Mail" }).click();
    const compose = page.getByRole("dialog", { name: "Yeni mesaj" });
    await expect(compose).toBeVisible();
    await compose.getByRole("button", { name: "İptal" }).click();
    await page.keyboard.press("c");
    await compose.getByLabel("Kime").fill("deniz@ornek.com");
    await compose.getByLabel("Konu").fill("Proje");
    await compose.getByLabel("Şablon").selectOption({ label: "Teşekkür" });
    await expect(compose.getByLabel("Konu")).toHaveValue("Re: Proje");
    await expect(compose.getByLabel("Mesaj")).toHaveValue(/Teşekkürler, aldım/);
    await compose.getByLabel("Okundu bildirimi iste").check();
    await expect(compose.getByLabel("Takip süresi")).toHaveCount(0);
    await compose.getByLabel("Yanıt takibi başlat").check();
    await compose.getByLabel("Takip süresi").selectOption("7");
    const a = path.join(dir, "rapor.pdf");
    const b = path.join(dir, "tablo.xlsx");
    fs.writeFileSync(a, "pdf");
    fs.writeFileSync(b, "xlsx");
    await mockDialogs(app, [[a, b], []], []);
    await compose.getByRole("button", { name: "📎 Ek ekle" }).click();
    await expect(compose.locator(".attachment-row .badge")).toHaveCount(2);
    await compose.getByRole("button", { name: "📎 Ek ekle" }).click(); // iptal: değişmez
    await compose.getByRole("button", { name: "tablo.xlsx ekini kaldır" }).click();
    await expect(compose.locator(".attachment-row .badge")).toHaveText(["rapor.pdf×"]);
    await compose.getByRole("button", { name: "Taslak kaydet" }).click();
    await expect(drafts.getByRole("listitem")).toHaveCount(3);
    await expect(drafts.getByRole("listitem").filter({ hasText: "Re: Proje" })).toHaveCount(1);

    // Hesap yokken gönderim: hata modalda, yazılanlar korunur (Ctrl+Enter ile gönder)
    await drafts.getByRole("listitem").filter({ hasText: "Re: Proje" }).click();
    await draft.getByLabel("Mesaj").press("Control+Enter");
    await expect(draft.getByRole("alert")).toContainText("Hesap tanımlı değil");
    await expect(draft.getByLabel("Kime")).toHaveValue("deniz@ornek.com");
  } finally {
    await ctx.close();
  }
});

test("dar pencere / yüksek DPI (yakınlaştırma %150): kompakt klasör seçimi ve okuyucu", async () => {
  const ctx = await launch();
  const { app, page } = ctx;
  try {
    await importDemo(ctx);
    await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].webContents.setZoomFactor(1.5));
    const select = page.getByLabel("Klasör seç");
    await expect(select).toBeVisible();
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
    await select.selectOption("sent");
    await expect(page.getByRole("list", { name: "Gönderilmiş" }).getByRole("listitem")).toHaveCount(2);
    await page.getByRole("button", { name: "Yeni", exact: true }).click();
    await expect(page.getByRole("dialog", { name: "Yeni mesaj" })).toBeVisible();
    await page.keyboard.press("Escape");
    await page.getByRole("list", { name: "Gönderilmiş" }).getByRole("listitem").first().click();
    const back = page.getByRole("button", { name: "Gelen kutusuna dön" });
    await expect(back).toBeVisible();
    await back.click();
    await expect(back).toHaveCount(0);
  } finally {
    await ctx.close();
  }
});
