import { expect, test, type Page } from "@playwright/test";

// Sira onemli (workers: 1): ayni e2e veritabanini paylasirlar. Feed'ler yerel fikstur sunucusundan gelir.
const FIXTURES = "http://127.0.0.1:3214";

const sidebar = (page: Page) => page.getByRole("complementary", { name: "Feed listesi" });
const articles = (page: Page) => page.getByRole("listbox", { name: "Makaleler" });

async function openAll(page: Page) {
  await page.goto("/");
  await expect(sidebar(page).getByText("Yerel Teknoloji")).toBeVisible({ timeout: 30_000 });
  await sidebar(page).getByRole("button", { name: "Tümü", exact: true }).click();
}

async function addFeedViaModal(page: Page, url: string) {
  await sidebar(page).getByRole("button", { name: "+ RSS ekle" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Feed URL").fill(url);
  await dialog.getByRole("button", { name: "Ekle", exact: true }).click();
  return dialog;
}

test("ilk acilista varsayilan feed yuklenir; makale guvenli okunur ve yildizlanir", async ({ page }) => {
  await openAll(page);
  await articles(page).getByRole("option", { name: /Yapay zeka çipleri/ }).click();
  const reader = page.getByRole("main", { name: "Okuyucu" });
  await expect(reader.getByRole("heading", { name: "Yapay zeka çipleri yerelleşiyor" })).toBeVisible();
  await expect(reader.locator(".reader-prose strong")).toHaveText("çipler");
  await expect(reader.locator(".reader-prose script")).toHaveCount(0);

  const star = reader.getByRole("button", { name: "Yıldızla (S)" });
  const before = await star.getAttribute("aria-pressed");
  await star.click();
  await expect(star).toHaveAttribute("aria-pressed", before === "true" ? "false" : "true");
  await star.click();
  await expect(star).toHaveAttribute("aria-pressed", before ?? "false");
});

test("feed ekleme ve Turkce arama", async ({ page }) => {
  await openAll(page);
  const dialog = await addFeedViaModal(page, `${FIXTURES}/bilim.xml`);
  await expect(dialog).toHaveCount(0);
  await expect(sidebar(page).getByText("Yerel Bilim")).toBeVisible();

  await page.getByRole("searchbox", { name: "Makale ara" }).fill("KUYRUKLU");
  await expect(articles(page).getByRole("option")).toHaveCount(1);
  await expect(articles(page).getByRole("option")).toContainText("Kuyruklu yıldız gözlemi");
});

test("erisilemeyen ya da gecersiz feed eklenmez, hata modalda gosterilir", async ({ page }) => {
  await openAll(page);
  const dialog = await addFeedViaModal(page, `${FIXTURES}/hata.xml`);
  await expect(dialog.getByText(/HTTP 500/)).toBeVisible();
  await dialog.getByLabel("Feed URL").fill(`${FIXTURES}/bozuk.xml`);
  await dialog.getByRole("button", { name: "Ekle", exact: true }).click();
  await expect(dialog.getByText(/RSS\/Atom/)).toBeVisible();
  await dialog.getByRole("button", { name: "İptal" }).click();
  await expect(sidebar(page).getByText("hata.xml")).toHaveCount(0);
});

test("OPML ice aktarmada cevrimdisi feed korunur ve hata isareti gorunur", async ({ page }) => {
  await openAll(page);
  const opml = `<?xml version="1.0"?><opml version="1.0"><body>
    <outline text="Kapalı Kaynak" xmlUrl="${FIXTURES}/hata.xml" category="Diğer" />
  </body></opml>`;
  await sidebar(page)
    .locator('input[type="file"]')
    .setInputFiles({ name: "abonelikler.opml", mimeType: "text/xml", buffer: Buffer.from(opml) });
  await expect(page.getByRole("status").filter({ hasText: "içe aktarıldı" })).toContainText("1 feed indirilemedi");
  await expect(sidebar(page).getByLabel(/Güncellenemedi: Feed indirilemedi \(HTTP 500\)/)).toBeVisible();
});

test("tumunu okundu isaretle", async ({ page }) => {
  await page.goto("/");
  await expect(sidebar(page).getByText("Yerel Teknoloji")).toBeVisible({ timeout: 30_000 });
  const markAll = page.getByRole("button", { name: "Tümünü okundu işaretle" });
  await expect(articles(page).getByRole("option").first()).toBeVisible();
  await markAll.click();
  await expect(page.getByText("Henüz makale yok.")).toBeVisible();
  await expect(sidebar(page).locator(".unread-badge")).toHaveCount(0);
  await expect(markAll).toBeDisabled();
});
