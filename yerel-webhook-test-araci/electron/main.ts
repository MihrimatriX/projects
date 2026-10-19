import { app, BrowserWindow, dialog, ipcMain } from "electron";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import {
  clearRequests,
  createEndpoint,
  deleteEndpoint,
  deleteMockRule,
  deleteRequest,
  getEndpointBySlug,
  getRawRequest,
  getSettings,
  insertRequest,
  listEndpoints,
  listMockRules,
  listRequests,
  saveSettings,
  upsertMockRule,
} from "./db";
import { createHookServer } from "./hookServer";
import { verifyWebhookSignature } from "./signature";
import { isLoopbackHost } from "./server-utils";
import type { ExportPayload, MockRule, ReplayResult } from "../src/types";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Testler / taşınabilir kullanım: veritabanı klasörü (hookyerel.db) değiştirilebilir.
if (process.env.HOOKYEREL_DATA_DIR) app.setPath("userData", process.env.HOOKYEREL_DATA_DIR);

let mainWindow: BrowserWindow | null = null;

const hookServer = createHookServer({
  resolveEndpoint(slug) {
    // /hook/<slug> ilgili endpoint'e yazılır; slug'sız istekler ilk endpoint'e düşer
    if (slug) return getEndpointBySlug(slug)?.id ?? null;
    return (listEndpoints()[0] ?? createEndpoint()).id;
  },
  mockRules: (endpointId) => listMockRules(endpointId),
  record(endpointId, req, body) {
    const rawHeaders = Object.fromEntries(
      Object.entries(req.headers).map(([k, v]) => [k, String(v ?? "")])
    );
    const entry = insertRequest(endpointId, req.method ?? "GET", req.url ?? "/", rawHeaders, body);
    mainWindow?.webContents.send("webhook:request", entry);
  },
  maxBodyBytes: () => getSettings().maxBodyBytes,
});

const serverPort = () => hookServer.status().port || getSettings().defaultPort;

function createWindow() {
  const iconPath = path.join(__dirname, "..", "assets", "icon.png");
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 960,
    minHeight: 640,
    title: "HookYerel — Yerel Webhook Test",
    icon: fs.existsSync(iconPath) ? iconPath : undefined,
    webPreferences: {
      preload: path.join(
        __dirname,
        fs.existsSync(path.join(__dirname, "preload.mjs")) ? "preload.mjs" : "preload.js"
      ),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (process.env.VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(path.join(__dirname, "../dist/index.html"));
  }

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

ipcMain.handle("server:start", (_event, port?: number) => {
  const settings = getSettings();
  return hookServer.start(port === undefined || port === null ? settings.defaultPort : Number(port));
});
ipcMain.handle("server:stop", () => {
  hookServer.stop();
  return hookServer.status();
});
ipcMain.handle("server:status", () => hookServer.status());

ipcMain.handle("settings:get", () => getSettings());
ipcMain.handle("settings:set", (_event, partial) => saveSettings(partial));

ipcMain.handle("endpoints:getAll", () => listEndpoints());
ipcMain.handle("endpoints:create", () => createEndpoint());
ipcMain.handle("endpoints:delete", (_event, id: string) => deleteEndpoint(id));

ipcMain.handle("requests:getAll", () => listRequests());
ipcMain.handle("requests:clear", (_event, endpointId?: string) => {
  clearRequests(endpointId);
  return true;
});
ipcMain.handle("requests:delete", (_event, id: string) => deleteRequest(id));

ipcMain.handle("requests:export", async () => {
  const payload: ExportPayload = {
    exportedAt: new Date().toISOString(),
    warning:
      "Bu dışa aktarım hassas veri içerebilir. Paylaşmadan önce maskeleme yapın; üretim sırlarını dışa aktarmayın.",
    endpoints: listEndpoints(),
    requests: listRequests(),
  };
  const result = await dialog.showSaveDialog({
    title: "İstek günlüğünü dışa aktar",
    defaultPath: `hookyerel-export-${Date.now()}.json`,
    filters: [{ name: "JSON", extensions: ["json"] }],
  });
  if (result.canceled || !result.filePath) return { ok: false };
  fs.writeFileSync(result.filePath, JSON.stringify(payload, null, 2), "utf8");
  return { ok: true, path: result.filePath };
});

ipcMain.handle("requests:replay", (_event, id: string, targetUrl?: string): Promise<ReplayResult> => {
  const req = listRequests().find((r) => r.id === id);
  const raw = getRawRequest(id);
  if (!req || !raw) return Promise.resolve({ ok: false, error: "İstek bulunamadı" });

  let url: URL;
  try {
    url = new URL(targetUrl ?? `http://127.0.0.1:${serverPort()}${req.url}`);
  } catch {
    return Promise.resolve({ ok: false, error: "Geçersiz hedef URL" });
  }
  if (!isLoopbackHost(url.hostname)) {
    return Promise.resolve({ ok: false, error: "Replay yalnızca localhost için izinli" });
  }

  return new Promise((resolve) => {
    const headers = { ...raw.headers };
    delete headers["host"];
    delete headers["content-length"];

    const outbound = http.request(
      {
        hostname: url.hostname.replace(/^[|]$/g, ""),
        port: url.port || serverPort(),
        path: url.pathname + url.search,
        method: req.method,
        headers,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          resolve({
            ok: true,
            statusCode: res.statusCode,
            body: Buffer.concat(chunks).toString("utf8").slice(0, 4000),
          });
        });
      }
    );

    outbound.on("error", (err) => resolve({ ok: false, error: err.message }));
    if (raw.body && !["GET", "HEAD"].includes(req.method.toUpperCase())) {
      outbound.write(raw.body);
    }
    outbound.end();
  });
});

ipcMain.handle("mockRules:list", (_event, endpointId?: string) => listMockRules(endpointId));
ipcMain.handle("mockRules:save", (_event, rule: MockRule) => upsertMockRule(rule));
ipcMain.handle("mockRules:delete", (_event, id: string) => deleteMockRule(id));

ipcMain.handle("signature:verify", (_event, input) => {
  const raw = getRawRequest(input.requestId);
  if (!raw) return { valid: false, message: "İstek bulunamadı" };
  return verifyWebhookSignature(input.preset, input.secret, raw.body, raw.headers);
});

app.whenReady().then(async () => {
  // Açılışta sunucu otomatik başlar (Ayarlar > "Açılışta sunucuyu başlat"); hata durumu arayüzde gösterilir.
  const settings = getSettings();
  if (settings.autoStart) await hookServer.start(settings.defaultPort);
  createWindow();
});

app.on("window-all-closed", () => {
  hookServer.stop();
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createWindow();
});
