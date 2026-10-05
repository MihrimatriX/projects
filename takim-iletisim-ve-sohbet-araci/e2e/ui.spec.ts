// Arayüz envanteri: her ekran ve kontrol gerçek tarayıcıda (docs/arayuz-testi.md tablosu bu dosyayı izler)
import { expect, test } from "@playwright/test";
import fs from "fs";
import {
  bubble,
  channelButton,
  login,
  newUserPage,
  openChannel,
  register,
  send,
  uid,
} from "./helpers";

test.describe("Giriş ekranı", () => {
  test("sekmeler, hatalı şifre uyarısı ve oturumsuz yönlendirme", async ({ page }) => {
    await page.goto("/chat");
    await expect(page).toHaveURL(/\/login/);
    const giris = page.getByRole("button", { name: "Giriş", exact: true });
    const kayit = page.getByRole("button", { name: "Kayıt", exact: true });
    await expect(giris).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByLabel("Adınız")).toHaveCount(0);
    await kayit.click();
    await expect(kayit).toHaveAttribute("aria-pressed", "true");
    await expect(page.getByLabel("Adınız")).toBeVisible();
    await giris.click();

    await page.getByLabel("E-posta").fill("mehmet@acme.local");
    await page.getByLabel("Şifre").fill("yanlis-sifre");
    await page.getByRole("button", { name: "Giriş yap" }).click();
    await expect(page.getByRole("alert").filter({ hasText: "Geçersiz e-posta veya şifre" })).toBeVisible();
    await expect(page).toHaveURL(/\/login/);
  });

  test("kayıt olan kullanıcı tüm genel kanallara katılır", async ({ page }) => {
    await register(page, "Deniz");
    for (const ch of ["genel", "geliştirme", "tasarım"]) {
      await expect(channelButton(page, ch)).toBeVisible();
    }
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(/^# /);
  });
});

test.describe("Sohbet ekranı", () => {
  test("kanal filtreleme, oluşturma, yinelenen ad hatası, Alt+ok gezinme", async ({ page }) => {
    await login(page);
    const filter = page.getByLabel("Kanal ara");
    await filter.fill("tas");
    await expect(channelButton(page, "tasarım")).toBeVisible();
    await expect(channelButton(page, "genel")).toHaveCount(0);
    await filter.fill("");

    const name = `ui-${uid()}`;
    await page.getByLabel("Yeni kanal adı").fill(name);
    await page.getByRole("button", { name: "Kanal oluştur" }).click();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText(`# ${name}`);
    await expect(page.getByText("Bu kanalda henüz mesaj yok")).toBeVisible();

    await page.getByLabel("Yeni kanal adı").fill(name);
    await page.getByRole("button", { name: "Kanal oluştur" }).click();
    await expect(page.getByRole("alert").filter({ hasText: "Kanal zaten var" })).toBeVisible();

    await openChannel(page, "genel");
    // Kanallar ada göre sıralı: geliştirme, genel, tasarım, ...
    await page.keyboard.press("Alt+ArrowDown");
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("# tasarım");
    await page.keyboard.press("Alt+ArrowUp");
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("# genel");

    // Son açılan kanal yeniden yüklemede hatırlanır
    await openChannel(page, "tasarım");
    await page.reload();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("# tasarım");
  });

  test("Enter/Shift+Enter, markdown ve mention gösterimi", async ({ page }) => {
    await login(page);
    await openChannel(page, "geliştirme");
    const box = page.getByLabel("Mesaj yaz");
    const id = uid();
    await box.fill(`**kalin${id}** ve @Ayşe`);
    await box.press("Shift+Enter");
    await expect(box).toHaveValue(`**kalin${id}** ve @Ayşe\n`);
    await box.press("Enter");
    const b = bubble(page, `kalin${id}`);
    await expect(b.locator("strong")).toHaveText(`kalin${id}`);
    await expect(box).toHaveValue("");
    await expect(page.getByRole("button", { name: "Gönder" })).toBeDisabled();
  });

  test("düzenlemeden Esc ile vazgeçme, silmeyi iptal ve onaylama", async ({ page }) => {
    await login(page);
    await openChannel(page, "geliştirme");
    const text = `silinecek ${uid()}`;
    await send(page, text);
    const b = bubble(page, text);

    await b.hover();
    await b.getByRole("button", { name: "Düzenle" }).click();
    await page.getByLabel("Mesajı düzenle").fill("vazgeçilen");
    await page.getByLabel("Mesajı düzenle").press("Escape");
    await expect(page.getByLabel("Mesajı düzenle")).toHaveCount(0);
    await expect(b).toContainText(text);

    page.once("dialog", (d) => d.dismiss());
    await b.hover();
    await b.getByRole("button", { name: "Sil" }).click();
    await expect(b).toBeVisible();

    page.once("dialog", (d) => d.accept());
    await b.hover();
    await b.getByRole("button", { name: "Sil" }).click();
    await expect(b).toHaveCount(0);
  });

  test("thread: yanıt, yanıt düzenleme/silme, sayaç ve kapatma", async ({ page }) => {
    await login(page);
    await openChannel(page, "geliştirme");
    const text = `thread kökü ${uid()}`;
    await send(page, text);
    const b = bubble(page, text);
    await b.hover();
    await b.getByRole("button", { name: "Thread aç" }).click();
    const thread = page.getByRole("complementary", { name: "Thread" });
    await expect(thread.getByText("İlk yanıtı sen yaz")).toBeVisible();

    await thread.getByLabel("Mesaj yaz").fill("ilk yanıt");
    await thread.getByLabel("Mesaj yaz").press("Enter");
    await expect(b.getByText("1 yanıt")).toBeVisible();
    const reply = thread.getByRole("article").filter({ hasText: "ilk yanıt" });
    // Esc düzenleme kutusunda yalnızca düzenlemeyi bırakır, thread'i kapatmaz
    await reply.hover();
    await reply.getByRole("button", { name: "Düzenle" }).click();
    await thread.getByLabel("Mesajı düzenle").press("Escape");
    await expect(thread.getByLabel("Mesajı düzenle")).toHaveCount(0);
    await expect(thread).toBeVisible();
    await reply.hover();
    await reply.getByRole("button", { name: "Düzenle" }).click();
    await thread.getByLabel("Mesajı düzenle").fill("düzeltilmiş yanıt");
    await thread.getByLabel("Mesajı düzenle").press("Enter");
    await expect(thread.getByText("düzeltilmiş yanıt")).toBeVisible();

    page.once("dialog", (d) => d.accept());
    const edited = thread.getByRole("article").filter({ hasText: "düzeltilmiş yanıt" });
    await edited.hover();
    await edited.getByRole("button", { name: "Sil" }).click();
    await expect(edited).toHaveCount(0);
    await expect(b.getByText("1 yanıt")).toHaveCount(0);

    await thread.getByRole("button", { name: "Thread kapat" }).click();
    await expect(thread).toHaveCount(0);
    await expect(page.getByRole("complementary", { name: "Üyeler" })).toBeVisible();

    await b.getByRole("button", { name: "Thread aç" }).click({ force: true });
    await expect(thread).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(thread).toHaveCount(0);
  });

  test("dosya eki: seç, kaldır, gönder ve indir", async ({ page }) => {
    await login(page);
    await openChannel(page, "geliştirme");
    const name = `not-${uid()}.txt`;
    const file = { name, mimeType: "text/plain", buffer: Buffer.from("ek içeriği") };
    await page.getByLabel("Dosya ekle").setInputFiles(file);
    await expect(page.getByText(`📎 ${name}`)).toBeVisible();
    await page.getByRole("button", { name: "Kaldır" }).click();
    await expect(page.getByText(`📎 ${name}`)).toHaveCount(0);

    await page.getByLabel("Dosya ekle").setInputFiles(file);
    await page.getByRole("button", { name: "Gönder" }).click();
    const link = page.getByRole("feed").getByRole("link", { name: new RegExp(name) });
    await expect(link).toBeVisible();
    const res = await page.request.get((await link.getAttribute("href"))!);
    expect(res.status()).toBe(200);
    expect(res.headers()["content-disposition"]).toContain("attachment");
    expect(await res.text()).toBe("ek içeriği");
  });

  test("hızlı arama: sonuç yok, fareyle seçim, Esc; kısayol listesi", async ({ page }) => {
    await login(page);
    await openChannel(page, "geliştirme");
    const token = `bulunacak${uid()}`;
    await send(page, token);
    await openChannel(page, "genel");

    await page.getByRole("button", { name: "Hızlı arama (Ctrl+K)" }).click();
    const dialog = page.getByRole("dialog", { name: "Hızlı arama" });
    await dialog.getByRole("combobox").fill("yokboyleşey123");
    await expect(dialog.getByText("Sonuç bulunamadı")).toBeVisible();
    await dialog.getByRole("combobox").fill(token);
    await dialog.getByRole("option").filter({ hasText: token }).click();
    await expect(dialog).toBeHidden();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("# geliştirme");

    await page.keyboard.press("Control+k");
    await expect(dialog).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(dialog).toBeHidden();

    await page.keyboard.press("Control+/");
    const help = page.getByRole("dialog", { name: "Klavye kısayolları" });
    await expect(help.getByText("Önceki / sonraki kanal")).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(help).toBeHidden();
    await page.getByRole("button", { name: "Kısayollar (Ctrl+/)" }).click();
    await help.getByRole("button", { name: "Kapat" }).click();
    await expect(help).toBeHidden();
  });

  test("50'den fazla mesajda 'Daha eski mesajları yükle'", async ({ page }) => {
    await login(page);
    const name = `sayfa-${uid()}`;
    const created = await page.request.post("/api/channels", { data: { name } });
    const { channel } = await created.json();
    for (let i = 1; i <= 55; i++) {
      await page.request.post(`/api/channels/${channel.id}/messages`, { data: { content: `kayıt ${i}.` } });
    }
    await page.reload();
    await openChannel(page, name);
    await expect(page.getByRole("feed").getByText("kayıt 55.")).toBeVisible();
    await expect(page.getByRole("feed").getByText("kayıt 1.", { exact: true })).toHaveCount(0);
    await page.getByRole("button", { name: "Daha eski mesajları yükle" }).click();
    await expect(page.getByRole("feed").getByText("kayıt 1.", { exact: true })).toBeVisible();
    await expect(page.getByRole("button", { name: "Daha eski mesajları yükle" })).toHaveCount(0);
  });

  test("dar ekranda menü düğmesi kanal listesini açar", async ({ page }) => {
    await page.setViewportSize({ width: 600, height: 800 });
    await login(page);
    await page.getByRole("button", { name: "Menüyü aç" }).click();
    await channelButton(page, "tasarım").click();
    await expect(page.getByRole("heading", { level: 1 })).toHaveText("# tasarım");
  });
});

test.describe("Çok kullanıcılı anlık akış", () => {
  test("DM, okunmamış rozeti, yazıyor göstergesi ve anlık düzenleme/silme", async ({ browser }) => {
    const mehmet = await newUserPage(browser);
    const can = await newUserPage(browser, "can@acme.local");
    await openChannel(can, "genel");

    await expect(mehmet.getByRole("complementary", { name: "Üyeler" })).toContainText("Mehmet (sen)");
    // Mehmet Can'a DM açar; Can'ın kenar çubuğunda DM anlık belirir ve okunmamış sayısı görünür
    await mehmet.getByRole("complementary", { name: "Üyeler" }).getByRole("button", { name: "Can" }).click();
    await expect(mehmet.getByRole("heading", { level: 1 })).toHaveText("Can");
    const dm = `özel ${uid()}`;
    await send(mehmet, dm);
    await expect(channelButton(can, "Mehmet")).toHaveText(/Mehmet\s*\d+/);
    await channelButton(can, "Mehmet").click();
    await expect(can.getByRole("feed").getByText(dm)).toBeVisible();

    // Aktif olmayan kanala gelen mesaj rozet olarak görünür
    await openChannel(can, "genel");
    await openChannel(mehmet, "tasarım");
    await send(mehmet, `rozet ${uid()}`);
    await expect(channelButton(can, "tasarım")).toHaveText(/tasarım\s*\d+/);

    // Yazıyor göstergesi
    await openChannel(can, "tasarım");
    await mehmet.getByLabel("Mesaj yaz").pressSequentially("yazıyorum");
    await expect(can.getByText("Mehmet yazıyor")).toBeVisible();
    await mehmet.getByLabel("Mesaj yaz").fill("");

    // Düzenleme ve silme diğer kullanıcıya anlık yansır
    const text = `canlı ${uid()}`;
    await send(mehmet, text);
    await expect(can.getByRole("feed").getByText(text)).toBeVisible();
    const own = bubble(mehmet, text);
    await own.hover();
    await own.getByRole("button", { name: "Düzenle" }).click();
    await mehmet.getByLabel("Mesajı düzenle").fill(`${text} v2`);
    await mehmet.getByLabel("Mesajı düzenle").press("Enter");
    await expect(bubble(can, `${text} v2`).getByText("(düzenlendi)")).toBeVisible();
    // Başkasının mesajında düzenle/sil yok
    await expect(bubble(can, `${text} v2`).getByRole("button", { name: "Sil" })).toHaveCount(0);

    mehmet.once("dialog", (d) => d.accept());
    await own.hover();
    await own.getByRole("button", { name: "Sil" }).click();
    await expect(can.getByRole("feed").getByText(`${text} v2`)).toHaveCount(0);
  });

  test("başkasının açtığı kanal kenar çubuğunda anlık görünür", async ({ browser }) => {
    const mehmet = await newUserPage(browser);
    const ayse = await newUserPage(browser, "ayse@acme.local");
    const name = `canli-${uid()}`;
    await mehmet.getByLabel("Yeni kanal adı").fill(name);
    await mehmet.getByRole("button", { name: "Kanal oluştur" }).click();
    await expect(channelButton(ayse, name)).toBeVisible();
  });
});

test.describe("Ayarlar ekranı", () => {
  test("profil adı, tema kalıcılığı, sohbete dönüş", async ({ page }) => {
    await register(page, "Profil");
    await page.getByRole("link", { name: "Ayarlar" }).click();
    await expect(page.getByRole("heading", { name: "Ayarlar" })).toBeVisible();
    await expect(page.getByLabel("Sunucu URL")).toHaveValue(/http:\/\/localhost:\d+/);

    const save = page.getByRole("button", { name: "Kaydet" });
    await expect(save).toBeDisabled();
    // 2 karakterden kısa ad tarayıcı doğrulamasında kalır, istek gitmez
    await page.getByLabel("Görünen ad").fill("X");
    await save.click();
    expect(await page.getByLabel("Görünen ad").evaluate((e) => (e as HTMLInputElement).validity.valid)).toBe(false);
    await page.getByLabel("Görünen ad").fill("Profil Yeni");
    await save.click();
    await expect(page.getByRole("status")).toHaveText("Görünen ad kaydedildi");

    await page.getByLabel("Tema").selectOption("light");
    await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
    await page.reload();
    await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
    await expect(page.getByLabel("Tema")).toHaveValue("light");
    await page.getByLabel("Tema").selectOption("dark");
    await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

    await page.getByRole("link", { name: "Sohbete dön" }).click();
    await expect(page.getByRole("feed")).toBeVisible();
    const text = `yeni adla ${uid()}`;
    await send(page, text);
    await expect(bubble(page, text)).toContainText("Profil Yeni");
  });

  test("webhook: oluştur, iki farklı kanala test mesajı, kopyala, sil", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await login(page);
    await page.goto("/settings");
    const hooks = [
      { name: `CI ${uid()}`, channel: "#geliştirme" },
      { name: `Deploy ${uid()}`, channel: "#tasarım" },
    ];
    for (const h of hooks) {
      await page.getByLabel("Yeni webhook").fill(h.name);
      await page.getByLabel("Webhook kanalı").selectOption({ label: h.channel });
      await page.getByRole("button", { name: "Webhook oluştur" }).click();
      await expect(page.getByRole("group", { name: `${h.name} webhook` })).toBeVisible();
    }
    for (const h of hooks) {
      const g = page.getByRole("group", { name: `${h.name} webhook` });
      const sent = page.waitForResponse((r) => r.url().includes("/api/webhooks/"));
      await g.getByRole("button", { name: "Test" }).click();
      expect((await sent).status()).toBe(201);
      await expect(page.getByRole("status")).toHaveText("Test mesajı kanala gönderildi");
    }
    const g = page.getByRole("group", { name: `${hooks[1].name} webhook` });
    await page.bringToFront(); // pano API'si odaklı belge ister (paralel işçilerde odak kayabilir)
    await g.getByRole("button", { name: "Kopyala" }).click();
    await expect(page.getByRole("status")).toHaveText("Webhook URL kopyalandı");
    const url = await g.getByRole("textbox").inputValue();
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(url);

    page.once("dialog", (d) => d.accept());
    await g.getByRole("button", { name: "Sil" }).click();
    await expect(g).toHaveCount(0);
    const res = await page.request.post(url, { data: { text: "silinmiş" } });
    expect(res.ok()).toBe(false);

    await page.getByRole("link", { name: "Sohbete dön" }).click();
    await openChannel(page, "tasarım");
    await expect(page.getByRole("feed").getByText(`[${hooks[1].name}]`).first()).toBeVisible();
  });

  test("KVKK: dışa aktarma, hesap silme onayı, çıkış", async ({ page }) => {
    const email = await register(page, "Silinecek");
    await send(page, `kişisel ${uid()}`);
    await page.goto("/settings");

    const download = page.waitForEvent("download");
    await page.getByRole("link", { name: "Verilerimi dışa aktar" }).click();
    const file = await (await download).path();
    const data = JSON.parse(fs.readFileSync(file, "utf8"));
    expect(data.format).toBe("kvkk-export-v1");
    expect(data.user.email).toBe(email);
    expect(data.messageCount).toBe(1);

    const del = page.getByRole("button", { name: "Hesabımı sil" });
    await expect(del).toBeDisabled();
    await page.getByLabel("Hesap silme").fill("baska@test.local");
    await expect(del).toBeDisabled();
    await page.getByLabel("Hesap silme").fill(email);
    page.once("dialog", (d) => d.dismiss());
    await del.click();
    await expect(page).toHaveURL(/\/settings/);

    page.once("dialog", (d) => d.accept());
    await del.click();
    await expect(page).toHaveURL(/\/login/);
    await page.getByLabel("E-posta").fill(email);
    await page.getByLabel("Şifre").fill("test1234");
    await page.getByRole("button", { name: "Giriş yap" }).click();
    await expect(page.getByRole("alert").filter({ hasText: "Geçersiz e-posta veya şifre" })).toBeVisible();
  });

  test("çıkış yapınca korumalı sayfalar girişe yönlendirir", async ({ page }) => {
    await register(page, "Cikis");
    await page.goto("/settings");
    await page.getByRole("button", { name: "Çıkış yap" }).click();
    await expect(page).toHaveURL(/\/login/);
    await page.goto("/settings");
    await expect(page).toHaveURL(/\/login/);
    const api = await page.request.get("/api/channels");
    expect(api.status()).toBe(401);
  });
});
