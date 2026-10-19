import { expect, test, type Page } from "@playwright/test";

const card = (page: Page, name: string) => page.getByRole("article").getByRole("heading", { name });

test("katalog arama ve kategori filtresi", async ({ page }) => {
  await page.goto("/katalog");
  await expect(card(page, "Flutter Temelleri")).toBeVisible();

  const search = page.getByRole("searchbox", { name: "Kurs ara" });
  // Arama aciklamada da gecer: "webhook" yalnizca Stripe kursunun aciklamasinda var.
  await search.fill("webhook");
  await expect(card(page, "Stripe Checkout Temelleri")).toBeVisible();
  await expect(card(page, "Flutter Temelleri")).toHaveCount(0);

  await search.fill("olmayan kurs");
  await expect(page.getByText("Bu filtrelerle kurs bulunamadı.")).toBeVisible();

  await page.getByRole("button", { name: "Temizle" }).click();
  await page.getByRole("button", { name: "Veri" }).click();
  await expect(card(page, "SQLite ile MVP Veri Modeli")).toBeVisible();
  await expect(card(page, "Flutter Temelleri")).toHaveCount(0);
});

test("olmayan kurs icin anlasilir hata", async ({ page }) => {
  await page.goto("/course/olmayan-kurs");
  await expect(page.getByText("Kurs bulunamadı.")).toBeVisible();
});

test("egitmen taslagina modul ekle ve kaldir", async ({ page }) => {
  await page.goto("/egitmen");
  await page.getByPlaceholder("Örn. State yönetimi pratiği").fill("Test modülü");
  await page.getByRole("button", { name: "Modül ekle" }).click();
  await expect(page.getByText("Test modülü")).toBeVisible();
  await page.getByRole("button", { name: "Test modülü modülünü kaldır" }).click();
  await expect(page.getByText("Test modülü")).toHaveCount(0);
});
