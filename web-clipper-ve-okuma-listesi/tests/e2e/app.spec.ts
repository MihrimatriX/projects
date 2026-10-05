import { test, expect } from "@playwright/test";

test("home page loads", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Tüm makaleler" })).toBeVisible();
});

test("settings page loads", async ({ page }) => {
  await page.goto("/settings");
  await expect(page.getByRole("heading", { name: "Ayarlar" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Chrome eklentisi" })).toBeVisible();
});

test("import page loads", async ({ page }) => {
  await page.goto("/import");
  await expect(page.getByRole("heading", { name: "İçe Aktar" })).toBeVisible();
});
