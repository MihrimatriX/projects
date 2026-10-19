import { expect, test, type Page } from "@playwright/test";

// Tum ekranlar ve kontroller gercek tarayicida (Chromium) denenir. Her test kendi tarayici
// baglamini (bos localStorage) kullanir; gercek kullanici verisine dokunulmaz.

const editor = (page: Page) => page.locator(".cm-content");
const lineCount = (page: Page) => page.locator(".cm-line").count();
const clipboard = (page: Page) => page.evaluate(() => navigator.clipboard.readText());

/** Sayfayi acar ve istemci tarafi hazir olana (hydration + AppInit) kadar bekler. */
async function go(page: Page, url: string) {
  await page.goto(url);
  await page.locator("html[data-ready]").waitFor({ state: "attached" });
}

async function typeJson(page: Page, text: string) {
  await editor(page).click();
  await page.keyboard.press("Control+a");
  await page.keyboard.insertText(text);
}

async function openLabWithDemo(page: Page) {
  await go(page, "/lab");
  await page.getByTestId("btn-demo").click();
  await expect(page.getByText("Geçerli JSON")).toBeVisible({ timeout: 10_000 });
}

/** Arac cubugu 1280 px'de tasmamali (tum butonlar gorunur). */
async function expectToolbarFits(page: Page) {
  const overflow = await page.locator(".toolbar").evaluate((el) => {
    const actions = el.querySelector(".toolbar-actions");
    return {
      bar: el.scrollWidth - el.clientWidth,
      actions: actions ? actions.scrollWidth - actions.clientWidth : 0,
    };
  });
  expect(overflow).toEqual({ bar: 0, actions: 0 });
}

test.describe("Başlatıcı ve gezinti", () => {
  test("ekran kartları her ekranı açar", async ({ page }) => {
    await go(page, "/");
    await expect(page.getByRole("heading", { name: "JSON Formatlayıcı" })).toBeVisible();
    for (const [name, url] of [
      [/Ana Laboratuvar/, /\/lab$/],
      [/JSONPath \/ jq-lite/, /\/jsonpath$/],
      [/Şema Doğrulama/, /\/schema$/],
      [/Diff Görünümü/, /\/diff$/],
      [/Dosya Entegrasyonu/, /\/file$/],
    ] as const) {
      await page.getByRole("link", { name }).click();
      await expect(page).toHaveURL(url, { timeout: 20_000 }); // dev sunucu ilk derleme
      await page.goBack();
    }
  });

  test("araç çubuğu gezintisi her ekranda çalışır ve taşmaz", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/lab");
    const nav = page.getByRole("navigation", { name: "Ekran gezintisi" });
    for (const [label, url] of [
      ["JSONPath", /\/jsonpath$/],
      ["Şema", /\/schema$/],
      ["Diff", /\/diff$/],
      ["Dosya", /\/file$/],
      ["Lab", /\/lab$/],
    ] as const) {
      await nav.getByRole("link", { name: label, exact: true }).click();
      await expect(page).toHaveURL(url);
      await expectToolbarFits(page);
    }
    await nav.getByRole("link", { name: "Ekranlar" }).click();
    await expect(page).toHaveURL(/\/$/);
  });
});

test.describe("Laboratuvar", () => {
  test("boş durum: düğmeler devre dışı, ağaç ipucu gösterilir", async ({ page }) => {
    await go(page, "/lab");
    await expect(page.getByText("Bekliyor")).toBeVisible();
    for (const name of ["Format", "Minify", "Sırala", "Kaydet", "Temizle", "Kopyala", "TS tipi", "Paylaş"]) {
      await expect(page.getByRole("button", { name, exact: true })).toBeDisabled();
    }
    await expect(page.getByText("JSON girin veya yapıştırın")).toBeVisible();
    await expect(page.getByText("- node")).toBeVisible();
  });

  test("format / minify / sırala düğmeleri, girinti ayarı ve kısayollar", async ({ page }) => {
    await openLabWithDemo(page);
    await page.getByRole("button", { name: "Minify" }).click();
    await expect.poll(() => lineCount(page)).toBe(1);
    await page.getByRole("button", { name: "Format", exact: true }).click();
    await expect.poll(() => lineCount(page)).toBeGreaterThan(10);
    await expect(editor(page)).toContainText('  "uygulama"');

    await page.getByLabel("Format girintisi").selectOption("4");
    await page.getByRole("button", { name: "Format", exact: true }).click();
    await expect(editor(page)).toContainText('    "uygulama"');

    await page.getByRole("button", { name: "Sırala" }).click();
    await expect(page.locator(".cm-line").nth(1)).toContainText('"aktif"');

    // Kisayollar: Ctrl+Shift+M / Ctrl+Shift+F
    await page.locator("body").press("Control+Shift+M");
    await expect.poll(() => lineCount(page)).toBe(1);
    await page.locator("body").press("Control+Shift+F");
    await expect.poll(() => lineCount(page)).toBeGreaterThan(10);

    // Girinti tercihi kalici
    await page.reload();
    await page.locator("html[data-ready]").waitFor({ state: "attached" });
    await expect(page.getByLabel("Format girintisi")).toHaveValue("4");
  });

  test("editörde geri al (Ctrl+Z) format işlemini geri alır", async ({ page }) => {
    await go(page, "/lab");
    await typeJson(page, '{"a":1,"b":[1,2]}');
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
    await page.getByRole("button", { name: "Format", exact: true }).click();
    await expect.poll(() => lineCount(page)).toBeGreaterThan(1);
    await editor(page).click();
    await page.keyboard.press("Control+z");
    await expect.poll(() => lineCount(page)).toBe(1);
    await expect(editor(page)).toHaveText('{"a":1,"b":[1,2]}');
  });

  test("ağaç: arama, genişlet/daralt, klavye ile aç-kapa, yol kopyalama", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await openLabWithDemo(page);
    const tree = page.locator(".panel-tree");
    await expect(tree.getByText("3 anahtar")).toBeVisible();

    await tree.getByRole("button", { name: "Genişlet" }).click();
    await expect(tree.getByText('"Örnek Kullanıcı"')).toBeVisible();
    await tree.getByRole("button", { name: "Daralt" }).click();
    await expect(tree.getByText('"Örnek Kullanıcı"')).toBeHidden();

    const branch = tree.getByRole("button", { name: /gelistirici/ }).first();
    await expect(branch).toHaveAttribute("aria-expanded", "false");
    await branch.focus();
    await page.keyboard.press("Enter");
    await expect(branch).toHaveAttribute("aria-expanded", "true");
    await expect(tree.getByText('"Örnek Kullanıcı"')).toBeVisible();

    await tree.getByLabel("Ağaçta ara").fill("surum");
    await expect(tree.locator(".border-dashed")).toHaveCount(1);

    await tree.getByRole("button", { name: "gelistirici: JSONPath kopyala", exact: true }).click();
    await expect.poll(() => clipboard(page)).toBe("$.gelistirici");
    await tree.getByRole("button", { name: "surum: değeri kopyala", exact: true }).click();
    await expect.poll(() => clipboard(page)).toBe("1.1.0");
  });

  test("kopyala, TS tipi ve paylaşım bağlantısı panoya yazılır; bağlantı içeriği açar", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await go(page, "/lab");
    await typeJson(page, '{"ad":"paylas","n":2}');
    await expect(page.getByText("Geçerli JSON")).toBeVisible();

    await page.getByTestId("btn-copy").click();
    await expect(page.getByTestId("notice")).toHaveText(/panoya kopyalandı/);
    await expect.poll(() => clipboard(page)).toBe('{"ad":"paylas","n":2}');

    await page.getByTestId("btn-ts").click();
    await expect.poll(() => clipboard(page)).toContain("ad: string;");

    await page.getByTestId("btn-share").click();
    const url = await clipboard(page);
    expect(url).toContain("/lab#d=");

    const other = await context.newPage();
    await other.goto(url);
    await other.locator("html[data-ready]").waitFor({ state: "attached" });
    await expect(other.locator(".cm-content")).toContainText('"paylas"');
    await expect(other.getByText("Geçerli JSON")).toBeVisible();
  });

  test("yardım: ? düğmesi, F1, Esc ve arka plan tıklaması", async ({ page }) => {
    await go(page, "/lab");
    const dialog = page.getByRole("dialog", { name: "Klavye kısayolları" });
    await page.getByRole("button", { name: /Yardım/ }).click();
    await expect(dialog).toBeVisible();
    await expect(dialog.getByText("Ctrl+Shift+K")).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(dialog).toBeHidden();

    await page.locator("body").press("F1");
    await expect(dialog).toBeVisible();
    await dialog.getByRole("button", { name: "Kapat" }).click();
    await expect(dialog).toBeHidden();

    await page.locator("body").press("F1");
    await page.locator(".modal-overlay").click({ position: { x: 5, y: 5 } });
    await expect(dialog).toBeHidden();
  });

  test("hatalı JSON: rozet hata panelini açar, Onar düzeltir", async ({ page }) => {
    await go(page, "/lab");
    await typeJson(page, "{'a': 1, \"b\": [1,2,],}");
    const badge = page.getByRole("button", { name: /Hata: satır 1/ });
    await expect(badge).toBeVisible();
    await expect(page.getByText("Geçerli JSON gerekli")).toBeVisible();
    await expect(page.locator(".error-panel-body")).toBeVisible();
    await page.getByTestId("btn-repair").click();
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
  });

  test("giriş modu (NDJSON) ve JSONC ayarı çalışır ve kalıcıdır", async ({ page }) => {
    await go(page, "/lab");
    await typeJson(page, '{"a":1}\n{"b":2}');
    await expect(page.getByRole("button", { name: /Hata:/ })).toBeVisible();
    await page.getByLabel("Giriş modu").selectOption("ndjson");
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
    await expect(page.getByRole("button", { name: "Sırala" })).toBeDisabled();
    await page.getByRole("button", { name: "Temizle" }).click();
    await expect(page.getByLabel("Giriş modu")).toHaveValue("json");

    await typeJson(page, '{\n  // yorum\n  "a": 1\n}');
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
    await page.getByLabel("JSONC").uncheck();
    await expect(page.getByRole("button", { name: /Hata:/ })).toBeVisible();
    await page.reload();
    await page.locator("html[data-ready]").waitFor({ state: "attached" });
    await expect(page.getByLabel("JSONC")).not.toBeChecked();
    await page.getByLabel("JSONC").check();
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
  });

  test("dosya aç, kaydet (indir), taslak geri yüklenir, temizle", async ({ page }) => {
    await go(page, "/lab");
    const chooser = page.waitForEvent("filechooser");
    await page.getByTestId("btn-open").click();
    await (await chooser).setFiles({
      name: "ornek.json",
      mimeType: "application/json",
      buffer: Buffer.from('{"ad":"deneme","sayi":3}'),
    });
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
    await expect(page.locator(".panel-meta")).toHaveText("ornek.json");

    const download = page.waitForEvent("download");
    await page.getByTestId("btn-save").click();
    expect((await download).suggestedFilename()).toBe("ornek.json");

    const download2 = page.waitForEvent("download");
    await page.locator("body").press("Control+s");
    expect((await download2).suggestedFilename()).toBe("ornek.json");

    await page.waitForTimeout(800); // taslak otomatik kaydi (500 ms gecikme)
    await page.reload();
    await page.locator("html[data-ready]").waitFor({ state: "attached" });
    await expect(page.getByText("Geçerli JSON")).toBeVisible();
    await page.getByTestId("btn-clear").click();
    await expect(page.getByText("Bekliyor")).toBeVisible();
    await page.waitForTimeout(800);
    await page.reload();
    await page.locator("html[data-ready]").waitFor({ state: "attached" });
    await expect(page.getByText("Bekliyor")).toBeVisible();
  });

  test("sürükle-bırak dosya yükler; 5 MB üstü için onay penceresi", async ({ page }) => {
    await go(page, "/lab");
    const drop = (content: string) =>
      page.evaluate((text) => {
        const dt = new DataTransfer();
        dt.items.add(new File([text], "birakilan.json", { type: "application/json" }));
        window.dispatchEvent(new DragEvent("dragover", { dataTransfer: dt, cancelable: true }));
        window.dispatchEvent(new DragEvent("drop", { dataTransfer: dt, cancelable: true }));
      }, content);

    await drop('{"surukle":true}');
    await expect(page.locator(".panel-meta")).toHaveText("birakilan.json");
    await expect(page.getByText("Geçerli JSON")).toBeVisible();

    const big = JSON.stringify({ veri: "x".repeat(5 * 1024 * 1024 + 10) });
    await drop(big);
    const modal = page.getByRole("dialog", { name: "Büyük dosya uyarısı" });
    await expect(modal).toBeVisible();
    await modal.getByRole("button", { name: "İptal" }).click();
    await expect(modal).toBeHidden();
    await drop(big);
    await modal.getByRole("button", { name: "Yine de yükle" }).click();
    await expect(modal).toBeHidden();
    await expect(page.getByText("Geçerli JSON")).toBeVisible({ timeout: 20_000 });
  });

  test("ayırıcı klavye ile paneli yeniden boyutlandırır", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/lab");
    const left = page.locator(".panel-editor");
    const before = (await left.boundingBox())!.width;
    await page.getByRole("separator", { name: "Panel genişliğini ayarla" }).focus();
    await page.keyboard.press("ArrowRight");
    await page.keyboard.press("ArrowRight");
    await expect.poll(async () => (await left.boundingBox())!.width).toBeGreaterThan(before + 40);
  });

  test("dar ekranda Editör/Ağaç sekmeleri", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 800 });
    await openLabWithDemo(page);
    const tabbar = page.locator(".mobile-tabbar");
    await expect(page.locator(".panel-tree")).toBeHidden();
    await tabbar.getByRole("button", { name: "Ağaç" }).click();
    await expect(page.locator(".panel-tree")).toBeVisible();
    await expect(page.locator(".panel-editor")).toBeHidden();
    await tabbar.getByRole("button", { name: "Editör" }).click();
    await expect(page.locator(".panel-editor")).toBeVisible();
  });
});

test.describe("JSONPath", () => {
  test("sorgu, Enter, eşleşme yok, hata ve sonucu editöre yazma", async ({ page }) => {
    await go(page, "/jsonpath");
    await expect(page.getByText("Sorgu çalıştırın")).toBeVisible();
    await page.getByRole("button", { name: "Sorgula" }).click();
    const results = page.locator(".result-list li.pass");
    await expect(results).toHaveCount(2);
    await expect(page.getByText("2 sonuç")).toBeVisible();

    const query = page.getByLabel("JSONPath sorgusu");
    await query.fill("$.store.bisiklet.renk");
    await query.press("Enter");
    await expect(results).toHaveCount(1);
    await expect(results.first()).toHaveText('"kırmızı"');

    await query.fill(".store.book | .[] | .price");
    await query.press("Enter");
    await expect(results).toHaveCount(2);
    await expect(results.first()).toHaveText("42.5");

    await query.fill("$.yok");
    await query.press("Enter");
    await expect(page.getByText("Eşleşme yok")).toBeVisible();
    await expect(page.getByText("0 sonuç")).toBeVisible();

    await page.getByLabel("Kaynak JSON").fill("{bozuk");
    await page.getByRole("button", { name: "Sorgula" }).click();
    await expect(page.getByText("Geçersiz JSON")).toBeVisible();

    await page.getByLabel("Kaynak JSON").fill('{"liste":[{"ad":"x"},{"ad":"y"}]}');
    await query.fill("$.liste[*].ad");
    await page.getByRole("button", { name: "Sorgula" }).click();
    await expect(results).toHaveCount(2);
    await page.getByRole("button", { name: "Sonucu editöre yaz" }).click();
    await page.getByRole("navigation", { name: "Ekran gezintisi" }).getByRole("link", { name: "Lab", exact: true }).click();
    await expect(page.locator(".cm-content")).toContainText('"x"');
  });
});

test.describe("Şema", () => {
  test("şema boşken Doğrula devre dışı; örnek şema, hata listesi ve Ctrl+Enter", async ({ page }) => {
    await openLabWithDemo(page);
    await page.getByRole("navigation", { name: "Ekran gezintisi" }).getByRole("link", { name: "Şema" }).click();
    const validate = page.getByRole("button", { name: "Doğrula" });
    await expect(validate).toBeDisabled();
    await expect(page.getByText("Şema girin ya da Örnek şema ile başlayın.")).toBeVisible();

    await page.getByRole("button", { name: "Örnek şema" }).click();
    await expect(page.getByText("Şema geçerli")).toBeVisible();

    await page.getByLabel("JSON verisi").fill('{"uygulama": 5}');
    await validate.click();
    await expect(page.getByText(/şema hatası/)).toBeVisible();
    await expect(page.locator(".result-list li.fail")).not.toHaveCount(0);

    await page.getByLabel("JSON verisi").fill('{"uygulama":"a","surum":"1"}');
    await page.getByLabel("JSON verisi").press("Control+Enter");
    await expect(page.getByText("Şema geçerli")).toBeVisible();
  });
});

test.describe("Diff", () => {
  test("karşılaştır: özet, gerçek satır vurgusu, hata, fark yok, yer değiştir", async ({ page }) => {
    await go(page, "/diff");
    await expect(page.getByTestId("btn-diff")).toBeDisabled();

    await page.getByLabel("Sol JSON").fill('{"a":1,"b":2,"c":3}');
    await page.getByLabel("Sağ JSON").fill('{"a":1,"b":5,"d":4}');
    await page.getByTestId("btn-diff").click();
    await expect(page.getByTestId("diff-summary")).toHaveText("+1 −1 ~1");
    await expect(page.getByText("3 değişiklik")).toBeVisible();
    // "b" ve "c" satirlari solda silindi, "b" ve "d" sagda eklendi; "a" satiri isaretlenmez.
    await expect(page.locator(".diff-line.remove")).toHaveCount(2);
    await expect(page.locator(".diff-line.add")).toHaveCount(2);
    await expect(page.getByRole("list", { name: "Değişen yollar" }).locator("li")).toHaveCount(3);

    await page.getByRole("button", { name: /Değiştir/ }).click();
    await expect(page.getByLabel("Sol JSON")).toHaveValue('{"a":1,"b":5,"d":4}');
    await expect(page.getByTestId("diff-summary")).toBeHidden(); // metin degisti, sonuc eskidi

    await page.getByLabel("Sağ JSON").fill("{bozuk");
    await page.getByTestId("btn-diff").click();
    await expect(page.locator(".diff-error")).toContainText("Sağ JSON geçersiz");

    await page.getByLabel("Sağ JSON").fill('{"a":1,"b":5,"d":4}');
    await page.getByTestId("btn-diff").click();
    await expect(page.getByTestId("diff-summary")).toHaveText("Fark yok");
  });

  test("Sol/Sağ = editör laboratuvardaki JSON'u alır", async ({ page }) => {
    await openLabWithDemo(page);
    await page.getByRole("navigation", { name: "Ekran gezintisi" }).getByRole("link", { name: "Diff" }).click();
    await page.getByRole("button", { name: "Sol = editör" }).click();
    await page.getByRole("button", { name: "Sağ = editör" }).click();
    await expect(page.getByLabel("Sol JSON")).toHaveValue(/uygulama/);
    await page.getByTestId("btn-diff").click();
    await expect(page.getByTestId("diff-summary")).toHaveText("Fark yok");
  });
});

test.describe("Dosya", () => {
  test("boş durum, aç, önizleme, kaydet", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/file");
    await expect(page.getByText("Dosya seçilmedi")).toBeVisible();
    await expect(page.getByText("Açılan dosyalar burada listelenir.")).toBeVisible();
    await expect(page.getByText("JSON önizlemesi için dosya açın")).toBeVisible();
    await expect(page.getByRole("button", { name: "Kaydet" })).toBeDisabled();

    const chooser = page.waitForEvent("filechooser");
    await page.getByTestId("btn-tauri-open").click();
    await (await chooser).setFiles({ name: "veri.json", mimeType: "application/json", buffer: Buffer.from('{\n  "x": 1\n}') });
    await expect(page.locator(".active-file-name")).toHaveText("veri.json");
    await expect(page.getByText("3 satır")).toBeVisible();
    await expect(page.getByLabel("JSON önizleme")).toContainText('"x": 1');

    const download = page.waitForEvent("download");
    await page.getByRole("button", { name: "Kaydet" }).click();
    expect((await download).suggestedFilename()).toBe("veri.json");

    // Dis degisiklik izleme yalnizca Tauri surumunde var; web/Electron'da dugme gosterilmez.
    await expect(page.getByRole("button", { name: "İzle" })).toHaveCount(0);
  });

  test("dar ekranda Dosyalar/Önizleme sekmeleri", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 800 });
    await go(page, "/file");
    const tabbar = page.locator(".mobile-tabbar");
    await expect(page.locator(".preview-panel")).toBeHidden();
    await tabbar.getByRole("button", { name: "Önizleme" }).click();
    await expect(page.locator(".preview-panel")).toBeVisible();
    await tabbar.getByRole("button", { name: "Dosyalar" }).click();
    await expect(page.locator(".file-panel")).toBeVisible();
  });
});

test("ekran görüntüleri (UPDATE_SCREENSHOTS=1)", async ({ page }) => {
  test.skip(!process.env.UPDATE_SCREENSHOTS, "yalnızca istenince");
  await page.setViewportSize({ width: 1280, height: 800 });
  await openLabWithDemo(page);
  await page.locator(".panel-tree").getByRole("button", { name: "Genişlet" }).click();
  await page.screenshot({ path: "docs/ekran.png" });
  await go(page, "/diff");
  await page.getByLabel("Sol JSON").fill(JSON.stringify({ ad: "Örnek", surum: "1.0", etiketler: ["a", "b"], aktif: true }));
  await page.getByLabel("Sağ JSON").fill(JSON.stringify({ ad: "Örnek", surum: "1.1", etiketler: ["a", "b", "c"], yeni: 1 }));
  await page.getByTestId("btn-diff").click();
  await page.screenshot({ path: "docs/ekran-diff.png" });
  await go(page, "/jsonpath");
  await page.getByRole("button", { name: "Sorgula" }).click();
  await page.screenshot({ path: "docs/ekran-jsonpath.png" });
});
