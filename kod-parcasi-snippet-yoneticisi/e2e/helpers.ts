import { _electron as electron, type ElectronApplication, type Page } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

export const appRoot = path.resolve(fileURLToPath(new URL("..", import.meta.url)));

export type Ctx = {
  app: ElectronApplication;
  page: Page;
  dir: string;
  dataFile: string;
  data: () => Array<Record<string, unknown>>;
  clipboard: () => Promise<string>;
  close: () => Promise<void>;
};

/**
 * Derlenmiş uygulamayı ayrı `--user-data-dir` ile başlatır: kullanıcının gerçek
 * %AppData%\kod-parcasi-snippet-yoneticisi\snippets.json dosyasına dokunulmaz. Pano içeriği geri yüklenir.
 */
export async function launch(seed?: unknown[]): Promise<Ctx> {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "snip-ui-"));
  const userData = path.join(dir, "userData");
  fs.mkdirSync(userData);
  const dataFile = path.join(userData, "snippets.json");
  if (seed) fs.writeFileSync(dataFile, JSON.stringify(seed));

  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.VITE_DEV_SERVER_URL;

  const app = await electron.launch({ args: [appRoot, `--user-data-dir=${userData}`], env });
  const savedClipboard = await app.evaluate(({ clipboard }) => clipboard.readText());
  const page = await app.firstWindow();
  await page.waitForSelector(".app-shell");
  return {
    app,
    page,
    dir,
    dataFile,
    data: () => JSON.parse(fs.readFileSync(dataFile, "utf8")),
    clipboard: () => app.evaluate(({ clipboard }) => clipboard.readText()),
    close: async () => {
      await app.evaluate(({ clipboard }, text) => clipboard.writeText(text), savedClipboard);
      await app.close();
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

/** Yerel aç/kaydet diyaloglarını sahte yanıtlarla değiştirir (kuyruk boşsa iptal). */
export async function mockDialogs(app: ElectronApplication, open: string[], save: string[]) {
  await app.evaluate(
    ({ dialog }, { open, save }) => {
      dialog.showOpenDialog = (async () => {
        const p = open.shift();
        return p ? { canceled: false, filePaths: [p] } : { canceled: true, filePaths: [] };
      }) as typeof dialog.showOpenDialog;
      dialog.showSaveDialog = (async () => {
        const p = save.shift();
        return p ? { canceled: false, filePath: p } : { canceled: true, filePath: "" };
      }) as typeof dialog.showSaveDialog;
    },
    { open, save }
  );
}

export const today = () => new Date().toISOString();
