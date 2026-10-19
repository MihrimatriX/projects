import { _electron as electron, expect, test, type ElectronApplication, type Page } from "@playwright/test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// Masaustu kabugu (Electron) uctan uca: tum ekranlar ve ana kontroller.
// DESKTOP_EXE verilirse paketlenmis exe (dist\...) test edilir, yoksa kaynak kabuk + out\.
// Profil ve indirmeler gecici klasorde tutulur (gercek %APPDATA% verisine dokunulmaz).

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "json-lab-e2e-"));
const userData = path.join(tmp, "profil");
const downloads = path.join(tmp, "indirilen");
fs.mkdirSync(downloads, { recursive: true });

async function launch(): Promise<{ app: ElectronApplication; page: Page }> {
  const exe = process.env.DESKTOP_EXE;
  const env = { ...process.env, JSON_LAB_USER_DATA: userData, JSON_LAB_DOWNLOAD_DIR: downloads } as Record<string, string>;
  const app = await electron.launch(
    exe ? { executablePath: exe, env } : { args: [path.join(__dirname, "..", "..")], env }
  );
  const page = await app.firstWindow();
  await page.locator("html[data-ready]").waitFor({ state: "attached" });
  return { app, page };
}

test.describe.configure({ mode: "serial" });
test.afterAll(() => fs.rmSync(tmp, { recursive: true, force: true }));

test("laboratuvar: format, ayarlar, ağaç, pano, yardım, onar, dosya aç/kaydet", async () => {
  const { app, page } = await launch();
  try {
    await expect(page).toHaveURL(/app:\/\/local\/lab/);
    await expect(page).toHaveTitle(/JSON Formatlayıcı/);
    const bar = await page.locator(".toolbar").evaluate((el) => el.scrollWidth - el.clientWidth);
    expect(bar).toBe(0);

    // Paylasim baglantisi app:// adresinde anlamsiz: masaustunde gizli.
    await expect(page.getByTestId("btn-share")).toHaveCount(0);

    await page.getByTestId("btn-demo").click();
    await expect(page.getByText("Geçerli JSON")).toBeVisible({ timeout: 15_000 });
    await page.getByRole("button", { name: "Minify" }).click();
    await expect.poll(() => page.locator(".cm-line").count()).toBe(1);
    await page.getByLabel("Format girintisi").selectOption("4");
    await page.getByTestId("btn-format").click();
    await expect(page.locator(".cm-content")).toContainText('    "uygulama"');
    await page.getByRole("button", { name: "Sırala" }).click();
    await expect(page.locator(".cm-line").nth(1)).toContainText('"aktif"');

    const tree = page.locator(".panel-tree");
    await tree.getByRole("button", { name: "Genişlet" }).click();
    await expect(tree.getByText('"Örnek Kullanıcı"')).toBeVisible();

    // Sistem panosu paylasilir: testten once saklanir, sonra geri yazilir.
    const original = await app.evaluate(({ clipboard }) => clipboard.readText());
    await page.getByTestId("btn-copy").click();
    await expect(page.getByTestId("notice")).toHaveText(/panoya kopyalandı/);
    expect(await app.evaluate(({ clipboard }) => clipboard.readText())).toContain('"uygulama"');
    await page.getByTestId("btn-ts").click();
    await expect.poll(() => app.evaluate(({ clipboard }) => clipboard.readText())).toContain("export type Root");
    await app.evaluate(({ clipboard }, text) => clipboard.writeText(text), original);

    await page.locator("body").press("F1");
    const help = page.getByRole("dialog", { name: "Klavye kısayolları" });
    await expect(help).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(help).toBeHidden();

    await page.locator(".cm-content").click();
    await page.keyboard.press("Control+a");
    await page.keyboard.insertText("{'a': 1,}");
    await expect(page.getByRole("button", { name: /Hata: satır/ })).toBeVisible();
    await page.getByTestId("btn-repair").click();
    await expect(page.getByText("Geçerli JSON")).toBeVisible();

    const chooser = page.waitForEvent("filechooser");
    await page.getByTestId("btn-open").click();
    await (await chooser).setFiles({ name: "masaustu.json", mimeType: "application/json", buffer: Buffer.from('{"masaustu":true}') });
    await expect(page.locator(".panel-meta")).toHaveText("masaustu.json");

    await page.getByTestId("btn-save").click();
    const saved = path.join(downloads, "masaustu.json");
    await expect.poll(() => fs.existsSync(saved) && fs.readFileSync(saved, "utf8")).toBe('{"masaustu":true}');
    await page.waitForTimeout(800); // taslak otomatik kaydi
  } finally {
    await app.close();
  }
});

test("taslak ve ayarlar yeniden açılışta korunur; diğer ekranlar çalışır", async () => {
  const { app, page } = await launch();
  try {
    await expect(page.locator(".cm-content")).toContainText('"masaustu"');
    await expect(page.getByLabel("Format girintisi")).toHaveValue("4");

    const nav = page.getByRole("navigation", { name: "Ekran gezintisi" });
    await nav.getByRole("link", { name: "JSONPath" }).click();
    await expect(page).toHaveURL(/\/jsonpath/);
    await page.getByLabel("JSONPath sorgusu").fill("$.masaustu");
    await page.getByRole("button", { name: "Sorgula" }).click();
    await expect(page.locator(".result-list li.pass")).toHaveText(["true"]);

    await nav.getByRole("link", { name: "Şema" }).click();
    await expect(page).toHaveURL(/\/schema/);
    await page.getByRole("button", { name: "Örnek şema" }).click();
    await expect(page.getByText(/şema hatası/)).toBeVisible();

    await nav.getByRole("link", { name: "Diff" }).click();
    await expect(page).toHaveURL(/\/diff/);
    await page.getByLabel("Sol JSON").fill('{"a":1}');
    await page.getByLabel("Sağ JSON").fill('{"a":2}');
    await page.getByTestId("btn-diff").click();
    await expect(page.getByTestId("diff-summary")).toHaveText("+0 −0 ~1");

    await nav.getByRole("link", { name: "Dosya" }).click();
    await expect(page).toHaveURL(/\/file/);
    await expect(page.getByLabel("JSON önizleme")).toContainText('"masaustu"');

    await nav.getByRole("link", { name: "Ekranlar" }).click();
    await expect(page.getByRole("heading", { name: "JSON Formatlayıcı" })).toBeVisible();
    await page.getByRole("link", { name: /Ana Laboratuvar/ }).click();
    await expect(page).toHaveURL(/\/lab/);

    // Statik export'ta olmayan rota 404 sayfasina duser, pencere bos kalmaz.
    await page.goto("app://local/olmayan-sayfa");
    await expect(page.getByText(/404|bulunamadı/i).first()).toBeVisible();
  } finally {
    await app.close();
  }
});
