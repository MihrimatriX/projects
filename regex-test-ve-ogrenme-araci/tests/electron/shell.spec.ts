import { _electron as electron, expect, test, type ElectronApplication, type Page } from "@playwright/test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// Masaustu kabugu (Electron) uctan uca. DESKTOP_EXE verilirse paketlenmis exe test edilir,
// yoksa kaynak kabuk + out klasoru. Profil gecici klasorde (gercek %APPDATA% verisine dokunulmaz).

const userData = fs.mkdtempSync(path.join(os.tmpdir(), "regex-lab-e2e-"));

async function launch(): Promise<{ app: ElectronApplication; page: Page }> {
  const exe = process.env.DESKTOP_EXE;
  const env = { ...process.env, REGEX_LAB_USER_DATA: userData } as Record<string, string>;
  const app = await electron.launch(exe ? { executablePath: exe, env } : { args: [path.join(__dirname, "..", "..")], env });
  const page = await app.firstWindow();
  await page.locator("html[data-ready]").waitFor({ state: "attached" });
  return { app, page };
}

async function setPattern(page: Page, text: string) {
  await page.getByRole("textbox", { name: "Regex pattern" }).click();
  await page.keyboard.press("Control+a");
  await page.keyboard.insertText(text);
}

test.describe.configure({ mode: "serial" });
test.afterAll(() => fs.rmSync(userData, { recursive: true, force: true }));

test("laboratuvar: eşleşme, gruplar, worker, kopyala, yardım, debugger", async () => {
  const { app, page } = await launch();
  try {
    await expect(page).toHaveURL(/app:\/\/local\/lab/);
    await expect(page.locator("tbody tr").filter({ hasText: "@" })).toHaveCount(2, { timeout: 15_000 });
    // Paylasim baglantisi app:// adresinde anlamsiz: masaustunde gizli.
    await expect(page.getByRole("button", { name: "Paylaş" })).toHaveCount(0);

    // Riskli kalip Web Worker'da eslestirilir (app:// altinda worker yuklenebilmeli)
    await setPattern(page, "(a+)+");
    await expect(page.getByText(/ReDoS riski (orta|yüksek) · [1-9]\d* eşleşme/)).toBeVisible({ timeout: 10_000 });
    await expect(page.getByText("zaman aşımı")).toHaveCount(0);

    await setPattern(page, "(\\w+)@(\\w+)");
    await expect(page.locator("tbody tr").first()).toContainText("$1 support");
    await page.locator("tbody tr").nth(1).click();
    await expect(page.locator("tbody tr").nth(1)).toHaveAttribute("aria-selected", "true");

    // Sistem panosu paylasilir: once saklanir, sonra geri yazilir.
    const original = await app.evaluate(({ clipboard }) => clipboard.readText());
    await page.getByRole("button", { name: "Kopyala", exact: true }).click();
    await expect.poll(() => app.evaluate(({ clipboard }) => clipboard.readText())).toBe("/(\\\\w+)@(\\\\w+)/g");
    await page.getByRole("button", { name: "JSON kopyala" }).click();
    await expect.poll(() => app.evaluate(({ clipboard }) => clipboard.readText())).toContain('"matches"');
    await app.evaluate(({ clipboard }, text) => clipboard.writeText(text), original);

    await page.locator("body").press("F1");
    const help = page.getByRole("dialog", { name: "Klavye kısayolları" });
    await expect(help).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(help).toBeHidden();

    await page.getByRole("button", { name: "AST", exact: true }).click();
    await page.getByRole("button", { name: "Adım", exact: true }).click();
    await page.getByRole("button", { name: "İleri →" }).click();
    await expect(page.getByText(/Adım 2 \//)).toBeVisible();

    await page.getByLabel("Tüm şablonlar").selectOption("uuid");
    // Sablon sonucu gelince gecmise yazilir (ilk degerlendirme worker ile biraz surebilir).
    await expect(page.getByLabel("Geçmiş kalıplar")).toContainText("[0-9a-fA-F]{8}");
  } finally {
    await app.close();
  }
});

test("oturum yeniden açılışta korunur; cheatsheet, ana sayfa ve 404", async () => {
  const { app, page } = await launch();
  try {
    await expect(page.getByLabel("Geçmiş kalıplar")).toBeVisible();
    await expect(page.getByText(/ReDoS riski düşük · [1-9]\d* eşleşme/)).toBeVisible();
    await expect(page.getByRole("textbox", { name: "Regex pattern" })).toContainText("[0-9a-fA-F]{8}");

    await page.getByRole("link", { name: "Cheatsheet" }).click();
    await page.getByLabel("Cheatsheet'te ara").fill("rakam");
    await page.getByRole("button", { name: "Laboratuvarda dene" }).first().click();
    await expect(page).toHaveURL(/\/lab\?p=/);
    await expect(page.getByText(/[1-9]\d* eşleşme/)).toBeVisible();

    await page.getByRole("link", { name: "Ana sayfa" }).click();
    await expect(page.getByRole("heading", { name: /Pattern yaz/ })).toBeVisible();

    await page.goto("app://local/olmayan-sayfa");
    await expect(page.getByText(/404|bulunamadı|could not be found/i).first()).toBeVisible();
  } finally {
    await app.close();
  }
});
