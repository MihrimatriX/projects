import { expect, test, type Page } from "@playwright/test";
import fs from "fs";
import path from "path";
import { launch, mockDialogs, today } from "./helpers";

// Arayüz envanteri: docs/arayuz-testi.md.

const SEED = [
  { id: "s1", title: "Selamlama", code: "console.log('merhaba {{year}}')", language: "javascript", tags: ["js"], folder: "Web" },
  { id: "s2", title: "Liste üreteci", code: "[x * 2 for x in xs]", language: "python", tags: ["py"], folder: "Betik", lastUsedAt: today() },
  { id: "s3", title: "Rust okuma", code: "let s = std::fs::read_to_string(p)?;", language: "rust", tags: ["rs", "io"], folder: "" },
];

const selectedTitle = (page: Page) => page.getByRole("listbox", { name: "Snippet listesi" }).locator("[aria-selected=true] .snippet-title");

test("ana pencere: boş durum, oluştur, düzenle, kısayollar, filtreler, liste klavyesi, kopyala, çoğalt, sil", async () => {
  const ctx = await launch();
  const { page } = ctx;
  let answer = true;
  page.on("dialog", (d) => void (answer ? d.accept() : d.dismiss()));
  try {
    // Boş durum
    await expect(page.getByText("İlk snippet'inizi oluşturun")).toBeVisible();
    await expect(page.locator(".toolbar-search kbd")).toContainText("Alt+Shift+S");
    await page.getByRole("button", { name: "Boş snippet" }).click();
    await expect(page.getByLabel("Snippet başlığı")).toHaveValue("Yeni snippet");
    await expect(page.getByLabel("Kaydedilmemiş değişiklik")).toHaveCount(0);

    // Tüm alanları doldur, Ctrl+S
    await page.getByLabel("Snippet başlığı").fill("Fetch yardımcı");
    await expect(page.getByLabel("Kaydedilmemiş değişiklik")).toBeVisible();
    await page.getByLabel("Etiketler").fill("#js, util,  ");
    await page.getByLabel("Programlama dili").fill("typescript");
    await page.getByLabel("Klasör").fill("  Web ");
    await page.getByLabel("Açıklama").fill("API çağrısı");
    await page.getByLabel("Kod alanı").fill("fetch('/api/{{date}}')");
    await page.keyboard.press("Control+s");
    await expect(page.getByRole("status")).toHaveText("Kaydedildi");
    await expect(page.getByLabel("Kaydedilmemiş değişiklik")).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Kaydet" })).toBeDisabled();
    await expect(page.locator(".editor-meta")).toContainText("TYPESCRIPT · Son düzenleme: bugün");
    await expect.poll(() => ctx.data()[0]).toMatchObject({
      title: "Fetch yardımcı",
      tags: ["js", "util"],
      language: "typescript",
      folder: "Web",
      description: "API çağrısı",
    });

    // Ctrl+N + Kaydet düğmesi
    await page.keyboard.press("Control+n");
    await page.getByLabel("Snippet başlığı").fill("Python betik");
    await page.getByLabel("Programlama dili").fill("python");
    await page.getByLabel("Klasör").fill("Betik");
    await page.getByLabel("Etiketler").fill("#py");
    await page.getByRole("button", { name: "Kaydet" }).click();
    await expect.poll(() => ctx.data().length).toBe(2);

    // Kaydedilmemiş değişiklik: reddedilirse yeni snippet açılmaz / seçim değişmez
    const list = page.getByRole("listbox", { name: "Snippet listesi" });
    await page.getByLabel("Snippet başlığı").fill("Python betik 2");
    answer = false;
    await page.keyboard.press("Control+n");
    await list.getByText("Fetch yardımcı").click();
    await expect(page.getByLabel("Snippet başlığı")).toHaveValue("Python betik 2");
    expect(ctx.data().length).toBe(2);
    answer = true;
    await page.keyboard.press("Control+s");
    await expect.poll(() => ctx.data().map((s) => s.title)).toContain("Python betik 2");

    // Klasör ve etiket filtreleri
    const sidebar = page.locator(".sidebar");
    await sidebar.getByRole("button", { name: "Betik" }).click();
    await expect(list.getByRole("option")).toHaveCount(1);
    await sidebar.getByRole("button", { name: "Tümü" }).first().click();
    await expect(list.getByRole("option")).toHaveCount(2);
    await page.getByRole("group", { name: "Etiket filtresi" }).getByRole("button", { name: "#util" }).click();
    await expect(list.getByRole("option")).toHaveCount(1);
    await expect(list.getByText("Fetch yardımcı")).toBeVisible();
    await page.getByRole("group", { name: "Etiket filtresi" }).getByRole("button", { name: "Tümü" }).click();

    // Arama (Ctrl+F odaklar), boş sonuç
    await page.getByLabel("Kod alanı").click();
    await page.keyboard.press("Control+f");
    await expect(page.getByLabel("Snippet ara")).toBeFocused();
    await page.keyboard.type("PYTHON");
    await expect(list.getByRole("option")).toHaveCount(1);
    await page.getByLabel("Snippet ara").fill("bulunamaz-xyz");
    await expect(page.getByText("Eşleşen snippet yok")).toBeVisible();
    await page.getByLabel("Snippet ara").fill("");

    // Liste klavye gezinmesi
    await list.getByText("Fetch yardımcı").click();
    await list.focus();
    await page.keyboard.press("Home");
    const first = await selectedTitle(page).textContent();
    await page.keyboard.press("ArrowDown");
    await expect(selectedTitle(page)).not.toHaveText(first!);
    await page.keyboard.press("ArrowUp");
    await expect(selectedTitle(page)).toHaveText(first!);
    await page.keyboard.press("End");
    await expect(selectedTitle(page)).not.toHaveText(first!);

    // Kopyala: yer tutucu genişler
    await list.getByText("Fetch yardımcı").click();
    await page.getByRole("button", { name: "Kopyala" }).click();
    await expect(page.getByRole("status")).toHaveText("Panoya kopyalandı");
    await expect.poll(ctx.clipboard).toMatch(/^fetch\('\/api\/\d{4}-\d{2}-\d{2}'\)$/);
    await expect.poll(() => ctx.data().find((s) => s.title === "Fetch yardımcı")?.lastUsedAt).toBeTruthy();

    // Çoğalt
    await page.getByRole("button", { name: "Çoğalt" }).click();
    await expect(page.getByLabel("Snippet başlığı")).toHaveValue("Fetch yardımcı (kopya)");
    await expect(page.getByRole("status")).toHaveText("Kopya oluşturuldu");

    // Sil: önce vazgeç, sonra onayla
    answer = false;
    await page.getByRole("button", { name: "Sil" }).click();
    await expect(list.getByText("Fetch yardımcı (kopya)")).toBeVisible();
    answer = true;
    await page.getByRole("button", { name: "Sil" }).click();
    await expect(list.getByText("Fetch yardımcı (kopya)")).toHaveCount(0);
    await expect(page.getByText("Bir snippet seçin")).toBeVisible();
    await expect(page.getByRole("status")).toHaveText("Silindi");
    await expect.poll(() => ctx.data().length).toBe(2);
  } finally {
    await ctx.close();
  }
});

test("Import / Export: sekmeler, dışa aktar, dosya seç, sürükle-bırak, diyalog, hata, kapatma", async () => {
  const ctx = await launch(SEED);
  const { app, page, dir } = ctx;
  try {
    const modal = page.getByRole("dialog", { name: "Import / Export" });
    const open = async () => {
      await page.getByRole("button", { name: "Import / Export" }).click();
      await expect(modal).toBeVisible();
    };

    // Kapatma yolları: ✕, İptal, Esc, arka plan; Ctrl+E açar
    await open();
    await modal.getByRole("button", { name: "Kapat" }).click();
    await expect(modal).toHaveCount(0);
    await page.keyboard.press("Control+e");
    await modal.getByRole("button", { name: "İptal" }).click();
    await expect(modal).toHaveCount(0);
    await open();
    await page.keyboard.press("Escape");
    await expect(modal).toHaveCount(0);
    await open();
    await page.locator(".modal-backdrop").click({ position: { x: 5, y: 5 } });
    await expect(modal).toHaveCount(0);

    // Export sekmesi: sayılar, iptal, kaydet
    await open();
    await modal.getByRole("tab", { name: "Export" }).click();
    await expect(modal.getByRole("tab", { name: "Export" })).toHaveAttribute("aria-selected", "true");
    await expect(modal.locator(".stat-num")).toHaveText(["3", "4", "2"]);
    const out = path.join(dir, "disari.json");
    await mockDialogs(app, [], ["", out]);
    await modal.getByRole("button", { name: "Dışa aktar" }).click();
    await expect(modal.getByRole("status")).toHaveText("Dışa aktarma iptal edildi");
    await modal.getByRole("button", { name: "Dışa aktar" }).click();
    await expect(modal.getByRole("status")).toHaveText("JSON dosyası kaydedildi");
    expect(JSON.parse(fs.readFileSync(out, "utf8")).map((s: { id: string }) => s.id)).toEqual(["s1", "s2", "s3"]);

    // Import: dosya seç (gizli input) -> özet -> içe aktar (var olan id atlanır)
    await modal.getByRole("tab", { name: "Import" }).click();
    const incoming = path.join(dir, "gelen.json");
    fs.writeFileSync(incoming, JSON.stringify([SEED[0], { title: "Yeni gelen", code: "x", tags: ["yeni"], folder: "Arşiv" }]));
    await modal.getByLabel("JSON dosyası seç").setInputFiles(incoming);
    await expect(modal.getByRole("heading", { name: "Doğrulama özeti" })).toBeVisible();
    await expect(modal.locator(".summary .stat-num")).toHaveText(["2", "2", "2"]);
    await modal.getByRole("button", { name: "Import et" }).click();
    await expect(modal.getByRole("status")).toHaveText("1 snippet import edildi");
    await expect(page.getByRole("listbox", { name: "Snippet listesi" }).getByText("Yeni gelen")).toBeVisible();
    expect(ctx.data()).toHaveLength(4);

    // Geçersiz dosya -> hata kutusu
    const bad = path.join(dir, "bozuk.json");
    fs.writeFileSync(bad, "{ bu json değil");
    await modal.getByLabel("JSON dosyası seç").setInputFiles(bad);
    await expect(modal.getByRole("alert")).toContainText("Import hatası");

    // Sürükle-bırak (dosya içeriği arayüzde okunur)
    const zone = modal.locator(".drop-zone");
    await zone.dispatchEvent("dragover");
    await expect(zone).toHaveClass(/dragover/);
    await zone.dispatchEvent("dragleave");
    await expect(zone).not.toHaveClass(/dragover/);
    const dt = await page.evaluateHandle(() => {
      const d = new DataTransfer();
      d.items.add(new File([JSON.stringify([{ id: "drop1", title: "Bırakılan", code: "y" }])], "drop.json", { type: "application/json" }));
      return d;
    });
    await zone.dispatchEvent("drop", { dataTransfer: dt });
    await expect(modal.getByRole("alert")).toHaveCount(0);
    await expect(modal.locator(".summary .stat-num").first()).toHaveText("1");
    await modal.getByRole("button", { name: "Import et" }).click();
    await expect(modal.getByRole("status")).toHaveText("1 snippet import edildi");

    // Dosya seçilmeden Import et -> yerel diyalog (önce iptal, sonra dosya)
    const viaDialog = path.join(dir, "diyalog.json");
    fs.writeFileSync(viaDialog, JSON.stringify([{ id: "d1", title: "Diyalogdan", code: "z" }]));
    await mockDialogs(app, ["", viaDialog], []);
    await modal.getByRole("button", { name: "Import et" }).click();
    await expect(modal.getByRole("status")).toHaveText("Yeni snippet eklenmedi");
    await modal.getByRole("button", { name: "Import et" }).click();
    await expect(modal.getByRole("status")).toHaveText("1 snippet import edildi");
    expect(ctx.data().map((s) => s.id)).toContain("d1");
    // Klavye ile dosya seçiciyi açan bırakma alanı odaklanabilir
    await zone.focus();
    await expect(zone).toBeFocused();
  } finally {
    await ctx.close();
  }
});

test("arama paleti: son kullanılanlar, arama, oklar, Enter kopyalar, Ctrl+Enter düzenler, Esc, yeni snippet", async () => {
  const ctx = await launch(SEED);
  const { app, page } = ctx;
  const paletteVisible = () =>
    app.evaluate(({ BrowserWindow }) =>
      BrowserWindow.getAllWindows().some((w) => w.webContents.getURL().includes("#palette") && w.isVisible())
    );
  try {
    const [palette] = await Promise.all([
      app.waitForEvent("window"),
      page.getByRole("button", { name: "Palet" }).click(),
    ]);
    await palette.waitForSelector(".palette");
    const input = palette.getByLabel("Palet araması");
    await expect(input).toBeFocused();
    const results = palette.getByRole("listbox", { name: "Arama sonuçları" });
    // Boş sorgu: yalnızca son kullanılanlar
    await expect(results.getByRole("option")).toHaveCount(1);
    await expect(results.getByText("Liste üreteci")).toBeVisible();

    // Arama + oklar
    await input.fill("s");
    await expect(results.getByRole("option")).toHaveCount(3);
    await expect(results.getByRole("option").nth(0)).toHaveAttribute("aria-selected", "true");
    await input.press("ArrowDown");
    await expect(results.getByRole("option").nth(1)).toHaveAttribute("aria-selected", "true");
    await input.press("ArrowUp");
    await input.press("ArrowUp");
    await expect(results.getByRole("option").nth(0)).toHaveAttribute("aria-selected", "true");

    // Enter kopyalar (yer tutucu genişler) ve paleti gizler. Arama gecikmesini beklemeden Enter:
    // eski sonuç listesinin ilk öğesi değil, güncel sorgunun sonucu kopyalanmalı.
    await input.fill("selam");
    await input.press("Enter");
    await expect.poll(ctx.clipboard).toBe(`console.log('merhaba ${new Date().getFullYear()}')`);
    await expect.poll(paletteVisible).toBe(false);

    // Yeniden aç (aynı pencere), fareyle tıklayınca kopyalar
    await page.getByRole("button", { name: "Palet" }).click();
    await expect.poll(paletteVisible).toBe(true);
    await input.fill("rust");
    // Palet odağı kaybedince gizlenir; otomasyonda pencere odağına bağlı kalmamak için olay doğrudan gönderilir.
    await results.getByText("Rust okuma").dispatchEvent("click");
    await expect.poll(ctx.clipboard).toContain("read_to_string");

    // Ctrl+Enter: ana pencerede düzenle
    await page.getByRole("button", { name: "Palet" }).click();
    await input.fill("liste");
    await expect(results.getByRole("option")).toHaveCount(1);
    await input.press("Control+Enter");
    await expect(page.getByLabel("Snippet başlığı")).toHaveValue("Liste üreteci");
    await expect.poll(paletteVisible).toBe(false);

    // Esc gizler
    await page.getByRole("button", { name: "Palet" }).click();
    await expect.poll(paletteVisible).toBe(true);
    await input.press("Escape");
    await expect.poll(paletteVisible).toBe(false);

    // Sonuç yok -> sorgu başlığıyla yeni snippet, ana pencerede seçili
    await page.getByRole("button", { name: "Palet" }).click();
    await input.fill("Docker temizlik");
    await expect(palette.getByText("Sonuç yok")).toBeVisible();
    await palette.getByRole("button", { name: "“Docker temizlik” adıyla yeni snippet oluştur" }).dispatchEvent("click");
    await expect(page.getByLabel("Snippet başlığı")).toHaveValue("Docker temizlik");
    await expect.poll(() => ctx.data().map((s) => s.title)).toContain("Docker temizlik");
  } finally {
    await ctx.close();
  }
});
