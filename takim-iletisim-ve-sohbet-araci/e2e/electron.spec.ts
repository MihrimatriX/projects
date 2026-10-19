// Masaüstü kabuğu (desktop/main.cjs): publish.ps1'in hazırladığı desktop/stage ile açılış, kuruluma özel
// anahtar, ilk açılış demo verisi ve giriş. Veri klasörü geçicidir (TAKIM_SOHBET_DATA); %APPDATA%'ya dokunulmaz.
import { _electron as electron, expect, test } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";

const desktop = path.join(__dirname, "..", "desktop");
const exe = path.join(desktop, "node_modules", "electron", "dist", "electron.exe");

test("masaüstü kabuğu: ilk açılış, anahtar, demo girişi", async () => {
  test.skip(
    !fs.existsSync(path.join(desktop, "stage", "server.cjs")) || !fs.existsSync(exe),
    "Önce .\\publish.ps1 çalıştırın (desktop/stage ve Electron gerekli)",
  );
  test.setTimeout(120000);
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "takim-sohbet-electron-"));
  const app = await electron.launch({
    executablePath: exe,
    args: [path.join(desktop, "main.cjs")],
    env: { ...process.env, TAKIM_SOHBET_DATA: dataDir },
  });
  try {
    const win = await app.firstWindow();
    await expect(win.getByRole("button", { name: "Giriş yap" })).toBeVisible({ timeout: 60000 });
    await win.waitForLoadState();
    expect(await win.title()).toBe("Takım Sohbet");

    const secret = fs.readFileSync(path.join(dataDir, "secret.key"), "utf8");
    expect(secret).toMatch(/^[0-9a-f]{64}$/);
    expect(fs.existsSync(path.join(dataDir, "sohbet.db"))).toBe(true);

    await win.getByLabel("E-posta").fill("mehmet@acme.local");
    await win.getByLabel("Şifre").fill("demo1234");
    await win.getByRole("button", { name: "Giriş yap" }).click();
    await expect(win.getByRole("feed").getByText("Deploy tamam.", { exact: false })).toBeVisible({ timeout: 30000 });
    await win.getByLabel("Mesaj yaz").fill("Masaüstünden merhaba");
    await win.getByLabel("Mesaj yaz").press("Enter");
    await expect(win.getByRole("feed").getByText("Masaüstünden merhaba")).toBeVisible();
  } finally {
    await app.close();
    fs.rmSync(dataDir, { recursive: true, force: true, maxRetries: 5, retryDelay: 500 });
  }
});
