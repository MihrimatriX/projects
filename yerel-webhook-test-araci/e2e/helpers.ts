import { _electron as electron, expect, type ElectronApplication, type Page } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

export const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));

export type Ctx = {
  app: ElectronApplication;
  page: Page;
  dir: string;
  port: () => Promise<number>;
  hookUrl: (index?: number) => Promise<string>;
  copied: () => Promise<string[]>;
  close: () => Promise<void>;
};

/** Derlenmiş uygulamayı geçici veri klasörüyle (HOOKYEREL_DATA_DIR) açar; gerçek hookyerel.db'ye dokunmaz. */
export async function launch(): Promise<Ctx> {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "hook-ui-"));
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.VITE_DEV_SERVER_URL;
  env.HOOKYEREL_DATA_DIR = dir;

  const app = await electron.launch({ args: [root], env });
  const page = await app.firstWindow();
  const badge = page.locator(".titlebar-badge");
  await expect(badge).toHaveText(/127\.0\.0\.1:\d+/);
  // Pano: sistem panosu (diğer uygulamalar) yerine sayfa içinde kaydedilir.
  await page.evaluate(() => {
    const w = window as unknown as { __copied: string[] };
    w.__copied = [];
    navigator.clipboard.writeText = async (t: string) => {
      w.__copied.push(t);
    };
  });
  const port = async () => Number((await badge.textContent())!.split(":")[1]);
  return {
    app,
    page,
    dir,
    port,
    hookUrl: async (index = 0) =>
      `http://127.0.0.1:${await port()}/hook/${(await page.locator(".hook-id").nth(index).textContent())!.trim()}`,
    copied: () => page.evaluate(() => (window as unknown as { __copied: string[] }).__copied),
    close: async () => {
      await app.close();
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

/** Yerel kaydet diyaloğunu ana süreçte sahte yanıtla değiştirir (gerçek pencere açılmaz). */
export async function mockSaveDialog(app: ElectronApplication, save: string[]) {
  await app.evaluate(({ dialog }, save) => {
    dialog.showSaveDialog = (async () => {
      const p = save.shift();
      return p ? { canceled: false, filePath: p } : { canceled: true, filePath: "" };
    }) as typeof dialog.showSaveDialog;
  }, save);
}
