import { expect, test, type Page } from "@playwright/test";

// Tum ekranlar ve kontroller gercek tarayicida (Chromium, uretim derlemesi) denenir.
// Her test kendi tarayici baglamini (bos localStorage) kullanir.

const rows = (page: Page) => page.locator("tbody tr");
const clipboard = (page: Page) => page.evaluate(() => navigator.clipboard.readText());
const status = (page: Page) => page.getByRole("status").filter({ hasText: /eşleşme|Pattern girin|Syntax|Test metni/ }).first();

async function go(page: Page, url: string) {
  await page.goto(url);
  await page.locator("html[data-ready]").waitFor({ state: "attached" });
}

async function setPattern(page: Page, text: string) {
  await page.getByRole("textbox", { name: "Regex pattern" }).click();
  await page.keyboard.press("Control+a");
  await page.keyboard.insertText(text);
}

async function setTestText(page: Page, text: string) {
  await page.getByRole("textbox", { name: "Test metni" }).click();
  await page.keyboard.press("Control+a");
  await page.keyboard.insertText(text);
}

test.describe("Ana sayfa", () => {
  test("ekran bağlantıları laboratuvar ve cheatsheet'i açar", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: /Pattern yaz/i })).toBeVisible();
    await page.getByRole("link", { name: /^Laboratuvar Canlı/ }).click();
    await expect(page).toHaveURL(/\/lab$/);
    await page.goto("/");
    await page.getByRole("link", { name: /^Cheatsheet/ }).click();
    await expect(page).toHaveURL(/\/cheatsheet$/);
    await page.goto("/");
    await page.getByRole("link", { name: "Laboratuvara git", exact: true }).click();
    await expect(page).toHaveURL(/\/lab$/);
  });
});

test.describe("Laboratuvar", () => {
  test("üç çalışma alanı yan yana, başlık taşmıyor, varsayılan e-posta eşleşmeleri", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/lab");
    for (const name of ["Regex pattern", "Test metni"]) {
      await expect(page.getByRole("textbox", { name })).toBeVisible();
    }
    await expect(page.getByRole("table", { name: "Yakalama grupları" })).toBeVisible();
    // Test metni paneli pattern'in altinda, sonuc paneli sagda (eski hatada test metni sag uste kayiyordu).
    const pat = (await page.getByRole("textbox", { name: "Regex pattern" }).boundingBox())!;
    const txt = (await page.getByRole("textbox", { name: "Test metni" }).boundingBox())!;
    expect(txt.y).toBeGreaterThan(pat.y + 50);
    expect(Math.abs(txt.x - pat.x)).toBeLessThan(40);
    const overflow = await page.locator("header").first().evaluate((el) => el.scrollWidth - el.clientWidth);
    expect(overflow).toBe(0);

    await expect(rows(page).filter({ hasText: "@" })).toHaveCount(2);
    await expect(status(page)).toHaveText(/ReDoS riski düşük · 2 eşleşme/);
  });

  test("eşleşme satırı seçilir; yakalama grupları ($1, adlı grup) gösterilir", async ({ page }) => {
    await go(page, "/lab");
    await expect(rows(page)).toHaveCount(2);
    await rows(page).nth(1).click();
    await expect(rows(page).nth(1)).toHaveAttribute("aria-selected", "true");
    await expect(rows(page).nth(0)).toHaveAttribute("aria-selected", "false");
    await rows(page).nth(0).focus();
    await page.keyboard.press("Enter");
    await expect(rows(page).nth(0)).toHaveAttribute("aria-selected", "true");

    await setPattern(page, "(?<kullanici>[\\w.]+)@(\\w+)");
    await expect(rows(page).first()).toContainText("<kullanici> support");
    await expect(rows(page).first()).toContainText("$2 masterstudio");
  });

  test("bayraklar: g kapatılınca tek eşleşme, i büyük harfi yakalar", async ({ page }) => {
    await go(page, "/lab");
    const g = page.getByRole("button", { name: "g bayrağı", exact: true });
    await expect(g).toHaveAttribute("aria-pressed", "true");
    await g.click();
    await expect(g).toHaveAttribute("aria-pressed", "false");
    await expect(rows(page)).toHaveCount(1);
    await g.click();

    await setPattern(page, "destek");
    await expect(page.getByText("Eşleşme yok")).toBeVisible();
    await page.getByRole("button", { name: "i bayrağı", exact: true }).click();
    await expect(rows(page)).toHaveCount(1);
    for (const f of ["m", "s", "u", "y"]) {
      const b = page.getByRole("button", { name: `${f} bayrağı`, exact: true });
      await b.click();
      await expect(b).toHaveAttribute("aria-pressed", "true");
      await b.click();
    }
  });

  test("hatalı pattern: durum, tablo ve debugger uyarısı", async ({ page }) => {
    await go(page, "/lab");
    await setPattern(page, "(abc");
    await expect(status(page)).toHaveText(/Syntax hatası/);
    await expect(page.getByText(/^Syntax hatası:/)).toBeVisible();
    await expect(page.getByText("Debugger Kullanılamıyor")).toBeVisible();
  });

  test("şablon çipleri, tüm şablonlar listesi ve geçmiş", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/lab");
    for (const chip of ["URL", "Tarih TR", "Telefon", "IPv4", "E-posta"]) {
      await page.getByRole("button", { name: chip, exact: true }).click();
      await expect(rows(page).first()).not.toContainText("Eşleşme yok");
      await expect(status(page)).toHaveText(/[1-9]\d* eşleşme/);
    }
    await page.getByLabel("Tüm şablonlar").selectOption("uuid");
    await expect(status(page)).toHaveText(/[1-9]\d* eşleşme/);

    const history = page.getByLabel("Geçmiş kalıplar");
    await expect(history).toBeVisible();
    const firstEntry = await history.locator("option").nth(1).getAttribute("value");
    await history.selectOption(firstEntry!);
    await expect(status(page)).toHaveText(/eşleşme/);
    await history.selectOption("__clear");
    await expect(history).toHaveCount(0);
  });

  test("replace önizleme ve sonucu kopyala", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await go(page, "/lab");
    await page.getByLabel("Replace önizleme").fill("<$&>");
    await expect(page.getByTestId("replace-result")).toContainText("<support@masterstudio.dev>");
    await page.getByRole("button", { name: "Sonucu kopyala" }).click();
    await expect.poll(() => clipboard(page)).toContain("<sales@example.com>");
  });

  test("kopyala düğmesi ve kısayolları panoya yazar", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await go(page, "/lab");
    await setPattern(page, "a\"b");
    await page.getByRole("button", { name: "Kopyala", exact: true }).click();
    await expect(page.getByRole("button", { name: "Kopyalandı" })).toBeVisible();
    await expect.poll(() => clipboard(page)).toBe('/a\\"b/g');

    await setPattern(page, "\\w+@\\w+");
    await page.locator("body").press("Control+Shift+C");
    await expect.poll(() => clipboard(page)).toBe("/\\\\w+@\\\\w+/g");
    await page.locator("body").press("Control+Shift+M");
    await expect.poll(async () => JSON.parse(await clipboard(page)).matches.length).toBe(2);
    await page.evaluate(() => navigator.clipboard.writeText(""));
    await page.getByRole("button", { name: "JSON kopyala" }).click();
    await expect.poll(async () => JSON.parse(await clipboard(page)).pattern).toBe("\\w+@\\w+");
  });

  test("paylaş: kişisel veri uyarısı, bağlantı kalıbı ve metni geri yükler", async ({ page, context }) => {
    await context.grantPermissions(["clipboard-read", "clipboard-write"]);
    await go(page, "/lab");
    await page.getByRole("button", { name: "Paylaş" }).click();
    await expect(page.getByText(/2 e-posta adresi tespit edildi/)).toBeVisible();
    await page.getByRole("button", { name: "İptal" }).click();
    await expect(page.getByText(/tespit edildi/)).toBeHidden();

    await setTestText(page, "kod: AB-12, CD-34");
    await setPattern(page, "[A-Z]{2}-\\d+");
    await page.getByRole("button", { name: "Paylaş" }).click();
    await expect.poll(() => clipboard(page)).toContain("/lab?s=");
    const url = await clipboard(page);

    const other = await context.newPage();
    await go(other, url);
    await expect(other.getByRole("textbox", { name: "Regex pattern" })).toHaveText("[A-Z]{2}-\\d+");
    await expect(other.locator("tbody tr")).toHaveCount(2);
  });

  test("ReDoS uyarısı gösterilir, kapatılır; büyük metin worker'da eşleşir", async ({ page }) => {
    await go(page, "/lab");
    await setPattern(page, "(a+)+$");
    const alert = page.getByRole("alert").filter({ hasText: "Skor" });
    await expect(alert).toBeVisible();
    await page.getByRole("button", { name: "Uyarıyı kapat" }).click();
    await expect(alert).toBeHidden();

    await setPattern(page, "\\d+");
    await setTestText(page, "12 ".repeat(3000));
    await expect(status(page)).toHaveText(/3000 eşleşme/, { timeout: 20_000 });
  });

  test("debugger sekmeleri: adım (düğme + F10), AST, açıklama", async ({ page }) => {
    await go(page, "/lab");
    await page.getByRole("button", { name: "Adım", exact: true }).click();
    await expect(page.getByText("Adım Adım Debugger")).toBeVisible();
    await expect(page.getByText(/Adım 1 \//)).toBeVisible();
    await page.getByRole("button", { name: "İleri →" }).click();
    await expect(page.getByText(/Adım 2 \//)).toBeVisible();
    await page.locator("body").press("F10");
    await expect(page.getByText(/Adım 3 \//)).toBeVisible();
    await page.locator("body").press("Shift+F10");
    await expect(page.getByText(/Adım 2 \//)).toBeVisible();

    const ast = page.getByRole("button", { name: "AST", exact: true });
    await ast.click();
    await expect(ast).toHaveAttribute("aria-pressed", "true");
    const explain = page.getByRole("button", { name: "Açıklama", exact: true });
    await explain.click();
    await expect(explain).toHaveAttribute("aria-pressed", "true");
  });

  test("yardım: ? düğmesi, F1, Esc, arka plan", async ({ page }) => {
    await go(page, "/lab");
    const dialog = page.getByRole("dialog", { name: "Klavye kısayolları" });
    await page.getByRole("button", { name: /Yardım/ }).click();
    await expect(dialog).toBeVisible();
    await expect(dialog.getByText("Ctrl+Shift+M")).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(dialog).toBeHidden();
    await page.locator("body").press("F1");
    await expect(dialog).toBeVisible();
    await page.mouse.click(5, 5);
    await expect(dialog).toBeHidden();
  });

  test("şablon yükleme editörde Ctrl+Z ile geri alınır", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/lab");
    await setPattern(page, "abc");
    await page.getByRole("button", { name: "IPv4", exact: true }).click();
    await expect(page.getByRole("textbox", { name: "Regex pattern" })).not.toHaveText("abc");
    await page.getByRole("textbox", { name: "Regex pattern" }).click();
    await page.keyboard.press("Control+z");
    await expect(page.getByRole("textbox", { name: "Regex pattern" })).toHaveText("abc");
  });

  test("oturum geri yükleme (hızlı yeniden yükleme dahil) ve Temizle", async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 800 });
    await go(page, "/lab");
    await page.getByLabel("Tüm şablonlar").selectOption("tckn");
    await expect(rows(page).filter({ hasText: "12345678902" })).toHaveCount(1);
    await page.reload(); // 500 ms beklemeden: pagehide'da yazilmali
    await page.locator("html[data-ready]").waitFor({ state: "attached" });
    await expect(rows(page).filter({ hasText: "10000000000" })).toHaveCount(1);

    await page.getByRole("button", { name: "Temizle" }).click();
    await expect(page.getByText("Pattern girin — üstteki şablonlardan birini deneyin")).toBeVisible();
    await expect(page.getByRole("button", { name: "JSON kopyala" })).toBeDisabled();
    await page.locator("body").press("Control+Enter");
    await expect(page.getByText("Pattern girin — üstteki şablonlardan birini deneyin")).toBeVisible();
  });

  test("dar ekranda Pattern / Test / Sonuç sekmeleri", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 800 });
    await go(page, "/lab");
    const tabs = page.getByRole("tablist", { name: "Panel sekmeleri" });
    await expect(page.getByRole("textbox", { name: "Regex pattern" })).toBeVisible();
    await tabs.getByRole("tab", { name: "Test" }).click();
    await expect(page.getByRole("textbox", { name: "Test metni" })).toBeVisible();
    await expect(page.getByRole("textbox", { name: "Regex pattern" })).toBeHidden();
    await tabs.getByRole("tab", { name: "Sonuç" }).click();
    await expect(page.getByRole("table", { name: "Yakalama grupları" })).toBeVisible();
    await expect(tabs.getByRole("tab", { name: "Sonuç" })).toHaveAttribute("aria-selected", "true");
  });

  test("alt bilgi: Ana sayfa bağlantısı", async ({ page }) => {
    await go(page, "/lab");
    await page.getByRole("link", { name: "Ana sayfa" }).click();
    await expect(page).toHaveURL(/\/$/);
  });
});

test.describe("Cheatsheet", () => {
  test("arama süzer, sonuç yok mesajı, laboratuvarda dene örnek metinle eşleşir", async ({ page }) => {
    await go(page, "/cheatsheet");
    const search = page.getByLabel("Cheatsheet'te ara");
    const cards = page.getByRole("button", { name: "Laboratuvarda dene" });
    const total = await cards.count();
    await search.fill("lookahead");
    await expect.poll(() => cards.count()).toBeLessThan(total);
    await search.fill("zzzz-yok");
    await expect(page.getByText(/için sonuç yok/)).toBeVisible();
    await search.fill("rakam");
    await cards.first().click();
    await expect(page).toHaveURL(/\/lab\?p=/);
    await expect(status(page)).toHaveText(/[1-9]\d* eşleşme/);

    await page.getByRole("link", { name: "Cheatsheet" }).click();
    await page.getByRole("link", { name: "← Laboratuvara dön" }).click();
    await expect(page).toHaveURL(/\/lab$/);
  });
});

test("ekran görüntüleri (UPDATE_SCREENSHOTS=1)", async ({ page }) => {
  test.skip(!process.env.UPDATE_SCREENSHOTS, "yalnızca istenince");
  await page.setViewportSize({ width: 1280, height: 800 });
  await go(page, "/lab");
  await setPattern(page, "(?<kullanici>[\\w.+-]+)@(?<alan>[\\w-]+)\\.(\\w{2,})");
  await page.getByLabel("Replace önizleme").fill("$<kullanici> [at] $<alan>");
  await expect(rows(page)).toHaveCount(2);
  await page.screenshot({ path: "docs/ekran.png" });
  await page.getByRole("button", { name: "Açıklama", exact: true }).click();
  await setPattern(page, "(a+)+$");
  await expect(status(page)).toHaveText(/ReDoS riski (orta|yüksek)/);
  await page.screenshot({ path: "docs/ekran-redos.png" });
  await go(page, "/cheatsheet");
  await page.screenshot({ path: "docs/ekran-cheatsheet.png" });
});
