import { expect, test } from "@playwright/test";
import { bubble, login, newUserPage, openChannel, send } from "./helpers";

test("demo giriş ve mesaj gönderme", async ({ page }) => {
  await login(page);
  await expect(page.getByText("genel").first()).toBeVisible();
  await send(page, `E2E test mesajı ${Date.now()}`);
});

test("mesaj diğer kullanıcıya anlık ulaşır", async ({ browser }) => {
  const mehmet = await newUserPage(browser);
  const ayse = await newUserPage(browser, "ayse@acme.local");

  const text = `Anlık mesaj ${Date.now()}`;
  await send(mehmet, text);
  await expect(ayse.getByRole("feed").getByText(text)).toBeVisible();
});

test("thread yanıtı ve mesaj düzenleme", async ({ page }) => {
  await login(page);
  // Paralel testler diğer kanallara yazar; bu kanalda akış kaymaz
  await openChannel(page, "tasarım");
  const text = `Düzenlenecek ${Date.now()}`;
  await send(page, text);

  const b = bubble(page, text);
  await b.hover();
  await b.getByRole("button", { name: "Düzenle" }).click();
  const editor = page.getByLabel("Mesajı düzenle");
  await editor.fill(`${text} (yeni)`);
  await editor.press("Enter");
  await expect(b.getByText(`${text} (yeni)`)).toBeVisible();
  await expect(b.getByText("(düzenlendi)")).toBeVisible();

  await b.hover();
  await b.getByRole("button", { name: "Thread aç" }).click();
  const thread = page.getByRole("complementary", { name: "Thread" });
  await thread.getByLabel("Mesaj yaz").fill("Thread yanıtı");
  await thread.getByRole("button", { name: "Yanıtla" }).click();
  await expect(thread.getByText("Thread yanıtı")).toBeVisible();
  await expect(b.getByText("1 yanıt")).toBeVisible();
});

test("Ctrl+K arama ve klavyeyle sonuca gitme, kanal taslağı", async ({ page }) => {
  await login(page);
  await openChannel(page, "genel");
  const token = `aranacak${Date.now()}`;
  await send(page, token);

  // Başka kanala geç; yazılan taslak kanala özel kalmalı
  await openChannel(page, "tasarım");
  await page.getByLabel("Mesaj yaz").fill("yarım taslak");
  await openChannel(page, "genel");
  await expect(page.getByLabel("Mesaj yaz")).toHaveValue("");
  await openChannel(page, "tasarım");
  await expect(page.getByLabel("Mesaj yaz")).toHaveValue("yarım taslak");

  await page.keyboard.press("Control+k");
  const dialog = page.getByRole("dialog", { name: "Hızlı arama" });
  await dialog.getByRole("combobox").fill(token);
  await expect(dialog.getByRole("option").first()).toContainText(token);
  await page.keyboard.press("Enter");
  await expect(dialog).toBeHidden();
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("# genel");
  await expect(page.getByRole("feed").getByText(token)).toBeVisible();
});
