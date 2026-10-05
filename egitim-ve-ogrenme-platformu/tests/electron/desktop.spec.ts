import { _electron as electron, expect, test } from "@playwright/test";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

test("masaustu surumu sunucuyu baslatir, veriyi APPDATA altinda tutar", async () => {
  // DESKTOP_EXE verilirse paketlenmis exe (dist\...) test edilir, yoksa desktop\ kabugu + stage\.
  const exe = process.env.DESKTOP_EXE;
  const desktop = path.join(__dirname, "..", "..", "desktop");
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "ogrenim-e2e-"));
  const app = await electron.launch({
    ...(exe
      ? { executablePath: exe }
      : { executablePath: path.join(desktop, "node_modules", "electron", "dist", "electron.exe"), args: [desktop] }),
    env: { ...process.env, APP_DATA_DIR: dataDir },
  });
  try {
    const page = await app.firstWindow();
    await expect(page.getByRole("link", { name: /Kursları aç/ })).toBeVisible({ timeout: 60_000 });
    await page.goto(new URL("/ders", page.url()).toString());
    await page.getByRole("button", { name: "Dersi tamamla" }).click();
    // Ilk paketli acilista ilk POST yavas olabilir (yuk altinda 5 sn'yi asti)
    await expect(page.getByLabel("Kurs ilerlemesi")).toContainText("33%", { timeout: 30_000 });
    expect(fs.existsSync(path.join(dataDir, "ogrenim.db"))).toBe(true);
  } finally {
    await app.close();
    fs.rmSync(dataDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 300 });
  }
});
