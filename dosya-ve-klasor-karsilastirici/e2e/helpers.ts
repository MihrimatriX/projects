import { _electron as electron, type ElectronApplication, type Page } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

export const appRoot = path.resolve(fileURLToPath(new URL("..", import.meta.url)));

export type Ctx = {
  app: ElectronApplication;
  page: Page;
  tmp: string;
  settingsFile: string;
  settings: () => Record<string, unknown>;
  close: () => Promise<void>;
};

/**
 * Derlenmiş uygulamayı geçici %LocalAppData% / %AppData% ile başlatır (gerçek profile dokunmaz).
 * `seed` settings.json'a yazılır; `cwd` göreli yollarla ekran görüntüsü almak için.
 */
export async function launch(seed: Record<string, unknown> = {}, cwd?: string): Promise<Ctx> {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "dk-ui-"));
  const settingsDir = path.join(tmp, "local", "DosyaKarsilastirici");
  fs.mkdirSync(settingsDir, { recursive: true });
  const settingsFile = path.join(settingsDir, "settings.json");
  fs.writeFileSync(settingsFile, JSON.stringify(seed));

  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.VITE_DEV_SERVER_URL;
  env.LOCALAPPDATA = path.join(tmp, "local");
  env.APPDATA = path.join(tmp, "roaming");

  const app = await electron.launch({ args: [appRoot], env, cwd: cwd ?? appRoot });
  const page = await app.firstWindow();
  await page.waitForSelector(".app");
  return {
    app,
    page,
    tmp,
    settingsFile,
    settings: () => JSON.parse(fs.readFileSync(settingsFile, "utf8")),
    close: async () => {
      await app.close();
      fs.rmSync(tmp, { recursive: true, force: true });
    },
  };
}

/** Yerel aç/kaydet diyaloglarını ana süreçte sahte yanıtlarla değiştirir (gerçek pencere açılmaz). */
export async function mockDialogs(app: ElectronApplication, open: string[], save: string[]) {
  await app.evaluate(
    ({ dialog, shell }, { open, save }) => {
      const g = globalThis as unknown as { revealed: string[] };
      g.revealed = [];
      dialog.showOpenDialog = (async () => {
        const p = open.shift();
        return p ? { canceled: false, filePaths: [p] } : { canceled: true, filePaths: [] };
      }) as typeof dialog.showOpenDialog;
      dialog.showSaveDialog = (async () => {
        const p = save.shift();
        return p ? { canceled: false, filePath: p } : { canceled: true, filePath: "" };
      }) as typeof dialog.showSaveDialog;
      shell.showItemInFolder = (p: string) => {
        g.revealed.push(p);
      };
    },
    { open, save }
  );
}

export async function revealed(app: ElectronApplication): Promise<string[]> {
  return app.evaluate(() => (globalThis as unknown as { revealed: string[] }).revealed);
}

export function write(file: string, content: string | Buffer) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, content);
}
