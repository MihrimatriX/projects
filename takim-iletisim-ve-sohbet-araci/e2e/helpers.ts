import { expect, type Browser, type Page } from "@playwright/test";

export async function login(page: Page, email = "mehmet@acme.local", password = "demo1234") {
  await page.goto("/login");
  await page.getByLabel("E-posta").fill(email);
  await page.getByLabel("Şifre").fill(password);
  await page.getByRole("button", { name: "Giriş yap" }).click();
  await expect(page).toHaveURL(/\/chat/, { timeout: 30000 });
  await expect(page.getByRole("feed")).toBeVisible({ timeout: 30000 });
}

/** Her test kendi kullanıcısını açar: ad/hesap silme gibi işlemler demo hesaplarını etkilemez. */
export async function register(page: Page, name: string) {
  const email = `${name.toLowerCase().replace(/[^a-z0-9]/g, "")}${Date.now()}${Math.floor(Math.random() * 1000)}@test.local`;
  await page.goto("/login");
  await page.getByRole("button", { name: "Kayıt", exact: true }).click();
  await page.getByLabel("Adınız").fill(name);
  await page.getByLabel("E-posta").fill(email);
  await page.getByLabel("Şifre").fill("test1234");
  await page.getByRole("button", { name: "Kayıt ol" }).click();
  await expect(page.getByRole("feed")).toBeVisible({ timeout: 30000 });
  return email;
}

export async function newUserPage(browser: Browser, email?: string) {
  const page = await (await browser.newContext()).newPage();
  await login(page, email);
  return page;
}

export function channelButton(page: Page, name: string) {
  // Okunmamış rozeti ada eklenebilir ("genel 2")
  return page
    .getByRole("complementary", { name: "Kanal listesi" })
    .getByRole("button", { name: new RegExp(`^${name}( \\d+)?$`) });
}

export async function openChannel(page: Page, name: string, heading = `# ${name}`) {
  await channelButton(page, name).click();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText(heading);
}

export async function send(page: Page, text: string) {
  await page.getByLabel("Mesaj yaz").first().fill(text); // ilk kutu ana akış; thread kutusu sonra gelir
  await page.getByRole("button", { name: "Gönder" }).click();
  await expect(page.getByRole("feed").getByText(text)).toBeVisible();
}

export function bubble(page: Page, text: string) {
  return page.getByRole("feed").getByRole("article").filter({ hasText: text });
}

export const uid = () => `${Date.now().toString(36)}${Math.floor(Math.random() * 1e4)}`;
