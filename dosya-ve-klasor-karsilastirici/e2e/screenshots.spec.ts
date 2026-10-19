import { expect, test } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";
import { appRoot, launch, write } from "./helpers";

// README görüntüleri: `$env:DK_SCREENSHOTS=1; npx playwright test screenshots` -> docs/*.png
// Örnek veri göreli yollarla açılır (cwd = geçici klasör), ekranda kullanıcı adı / gerçek yol görünmez.
test.skip(!process.env.DK_SCREENSHOTS, "Yalnızca DK_SCREENSHOTS=1 ile");

const V1 = `import { readConfig } from "./config";

export function greet(name: string): string {
  return "Merhaba, " + name;
}

export function total(items: number[]): number {
  let sum = 0;
  for (const i of items) sum += i;
  return sum;
}

export const VERSION = "1.0.0";
`;

const V2 = `import { readConfig } from "./config";
import { log } from "./log";

export function greet(name: string, polite = true): string {
  return (polite ? "Merhaba, " : "Selam, ") + name;
}

export function total(items: number[]): number {
  return items.reduce((a, b) => a + b, 0);
}

export const VERSION = "1.1.0";
`;

test("README ekran görüntüleri", async () => {
  const demo = fs.mkdtempSync(path.join(os.tmpdir(), "dk-demo-"));
  const docs = path.join(appRoot, "docs");
  fs.mkdirSync(docs, { recursive: true });
  const left = "ornek/v1";
  const right = "ornek/v2";
  write(path.join(demo, left, "src", "app.ts"), V1);
  write(path.join(demo, right, "src", "app.ts"), V2);
  write(path.join(demo, left, "src", "config.ts"), "export const readConfig = () => ({});\n");
  write(path.join(demo, right, "src", "config.ts"), "export const readConfig = () => ({});\n");
  write(path.join(demo, right, "src", "log.ts"), "export const log = console.log;\n");
  write(path.join(demo, left, "README.md"), "# Ornek\n");
  write(path.join(demo, right, "README.md"), "# Ornek proje\n");
  write(path.join(demo, left, "eski-notlar.txt"), "kaldirildi\n");
  write(path.join(demo, left, "package.json"), '{ "version": "1.0.0" }\n');
  write(path.join(demo, right, "package.json"), '{ "version": "1.1.0" }\n');
  write(path.join(demo, "uc", "base.txt"), "renk = mavi\nboyut = 12\ntema = koyu\n");
  write(path.join(demo, "uc", "sol.txt"), "renk = yesil\nboyut = 12\ntema = koyu\n");
  write(path.join(demo, "uc", "sag.txt"), "renk = kirmizi\nboyut = 14\ntema = koyu\n");

  const ctx = await launch({ lastLeftPath: left, lastRightPath: right }, demo);
  const { app, page } = ctx;
  try {
    await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].setContentSize(1280, 800));
    await page.keyboard.press("F5");
    await page.getByRole("tree").getByText("app.ts").click();
    await expect(page.locator(".monaco-diff-editor")).toBeVisible({ timeout: 20_000 });
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(docs, "ekran.png") });

    // 3-yönlü birleştirme
    await page.getByLabel("Sol dosya yolu").fill("uc/sol.txt");
    await page.getByLabel("Sağ dosya yolu").fill("uc/sag.txt");
    await page.keyboard.press("F5");
    await page.keyboard.press("Control+,");
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    await settings.getByRole("button", { name: "Diff" }).click();
    await settings.getByLabel("Base yolu").fill("uc/base.txt");
    await settings.getByLabel("Base yolu").blur();
    await page.keyboard.press("Escape");
    await page.getByRole("tab", { name: "3-Yönlü Birleştir" }).click();
    await page.locator(".conflict-row").first().getByRole("button", { name: "Sol Al" }).click();
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(docs, "ekran-uc-yonlu.png") });

    // Açık tema
    await page.keyboard.press("Control+,");
    await settings.getByRole("button", { name: "Genel" }).click();
    await settings.getByLabel("Tema").selectOption("light");
    await page.keyboard.press("Escape");
    await page.getByLabel("Sol dosya yolu").fill(`${left}/src/app.ts`);
    await page.getByLabel("Sağ dosya yolu").fill(`${right}/src/app.ts`);
    await page.keyboard.press("F5");
    await page.getByRole("tab", { name: "Satır İçi" }).click();
    await expect(page.locator(".monaco-diff-editor")).toBeVisible({ timeout: 20_000 });
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(docs, "ekran-acik-tema.png") });
  } finally {
    await ctx.close();
    fs.rmSync(demo, { recursive: true, force: true });
  }
});
