import {
  app,
  BrowserWindow,
  clipboard,
  dialog,
  globalShortcut,
  ipcMain,
  nativeImage,
} from "electron";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

import { expandPlaceholders } from "./placeholders";
import {
  loadSnippets as loadFrom,
  mergeImport as mergeInto,
  normalizeSnippet,
  parseImportJson,
  saveSnippets as saveTo,
  searchSnippets,
  type Snippet,
} from "./snippetStore";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let mainWindow: BrowserWindow | null = null;
let paletteWindow: BrowserWindow | null = null;
let hotkeyOk = false;

// Tüm snippet'ler userData altındaki tek bir JSON dosyasında tutulur; her IPC çağrısı dosyayı baştan okur/yazar
function snippetsPath() {
  return path.join(app.getPath("userData"), "snippets.json");
}

function iconPath() {
  const root = process.env.APP_ROOT ?? path.join(__dirname, "..");
  // Paketli uygulamada assets/ yok; Vite publicDir (assets) içeriğini dist/ altına kopyalar.
  const candidates = ["assets/app.ico", "assets/icon.png", "dist/app.ico", "dist/icon.png"].map((p) =>
    path.join(root, p)
  );
  return candidates.find((p) => fs.existsSync(p));
}

const loadSnippets = () => loadFrom(snippetsPath());
const saveSnippets = (snippets: Snippet[]) => saveTo(snippetsPath(), snippets);
const mergeImport = (incoming: Partial<Snippet>[]) => mergeInto(snippetsPath(), incoming);

function getPreloadPath() {
  const js = path.join(__dirname, "preload.js");
  const mjs = path.join(__dirname, "preload.mjs");
  if (fs.existsSync(js)) return js;
  if (fs.existsSync(mjs)) return mjs;
  return js;
}

function windowIcon() {
  const p = iconPath();
  return p ? nativeImage.createFromPath(p) : undefined;
}

function loadWindowContent(win: BrowserWindow, hash = "", query: Record<string, string> = {}) {
  const suffix = hash ? `#${hash}` : "";
  if (process.env.VITE_DEV_SERVER_URL) {
    const qs = new URLSearchParams(query).toString();
    win.loadURL(`${process.env.VITE_DEV_SERVER_URL}${qs ? `?${qs}` : ""}${suffix}`);
  } else {
    win.loadFile(path.join(__dirname, "../dist/index.html"), { hash: hash.replace(/^#/, ""), query });
  }
}

/** selectId: paletten "düzenle" ile açılışta seçilecek snippet (URL sorgusu ile iletilir). */
function createMainWindow(selectId?: string) {
  const isWin = process.platform === "win32";
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    show: false,
    title: "Kod Snippet Yöneticisi",
    icon: windowIcon(),
    backgroundColor: "#0d1117",
    ...(isWin
      ? {
          titleBarStyle: "hidden" as const,
          titleBarOverlay: {
            color: "#161b22",
            symbolColor: "#e6edf3",
            height: 36,
          },
        }
      : {}),
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  loadWindowContent(mainWindow, "", selectId ? { select: selectId } : {});
  mainWindow.once("ready-to-show", () => mainWindow?.show());

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

function createPaletteWindow() {
  if (paletteWindow && !paletteWindow.isDestroyed()) {
    paletteWindow.show();
    paletteWindow.focus();
    paletteWindow.webContents.send("palette:focus");
    return;
  }

  paletteWindow = new BrowserWindow({
    width: 640,
    height: 480,
    frame: false,
    transparent: false,
    backgroundColor: "#161b22",
    resizable: false,
    alwaysOnTop: true,
    show: false,
    skipTaskbar: true,
    icon: windowIcon(),
    roundedCorners: true,
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  loadWindowContent(paletteWindow, "palette");

  paletteWindow.once("ready-to-show", () => {
    paletteWindow?.show();
    paletteWindow?.focus();
    paletteWindow?.webContents.send("palette:focus");
  });

  // Palet odağı kaybedince kapatılmaz, gizlenir — kısayola tekrar basınca anında görünür
  paletteWindow.on("blur", () => {
    paletteWindow?.hide();
  });

  paletteWindow.on("closed", () => {
    paletteWindow = null;
  });
}

// Global kısayol: uygulama arka plandayken de palet penceresini açar
function registerHotkey() {
  globalShortcut.unregisterAll();
  hotkeyOk = globalShortcut.register("Alt+Shift+S", () => {
    createPaletteWindow();
  });
  if (!hotkeyOk) console.warn("Alt+Shift+S kısayolu kaydedilemedi");
}

function showMainWithSnippet(id: string) {
  // Yeni pencereye IPC mesajı yüklenmeden ulaşmaz; seçim URL sorgusuyla iletilir.
  if (!mainWindow) createMainWindow(id);
  else mainWindow.webContents.send("main:select-snippet", id);
  mainWindow?.show();
  mainWindow?.focus();
}

ipcMain.handle("snippets:getAll", () => loadSnippets());

ipcMain.handle("snippets:getRecent", (_event, limit = 20) =>
  loadSnippets()
    .filter((s) => s.lastUsedAt)
    .sort((a, b) => (b.lastUsedAt ?? "").localeCompare(a.lastUsedAt ?? ""))
    .slice(0, limit)
);

ipcMain.handle("snippets:get", (_event, id: string) => loadSnippets().find((s) => s.id === id) ?? null);

ipcMain.handle("snippets:create", (_event, input: Partial<Snippet>) => {
  const now = new Date().toISOString();
  const snippet = normalizeSnippet({
    id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    ...input,
    createdAt: now,
    updatedAt: now,
    lastUsedAt: null,
  });
  const all = loadSnippets();
  all.unshift(snippet);
  saveSnippets(all);
  return snippet;
});

ipcMain.handle("snippets:update", (_event, id: string, input: Partial<Snippet>) => {
  const all = loadSnippets();
  const idx = all.findIndex((s) => s.id === id);
  if (idx < 0) return null;
  all[idx] = normalizeSnippet({
    ...all[idx],
    ...input,
    id: all[idx].id,
    updatedAt: new Date().toISOString(),
  });
  saveSnippets(all);
  return all[idx];
});

ipcMain.handle("snippets:delete", (_event, id: string) => {
  saveSnippets(loadSnippets().filter((s) => s.id !== id));
  return true;
});

ipcMain.handle("snippets:search", (_event, query: string) => searchSnippets(loadSnippets(), query));

ipcMain.handle("snippets:copy", (_event, id: string) => {
  const snippet = loadSnippets().find((s) => s.id === id);
  if (!snippet) return false;
  clipboard.writeText(expandPlaceholders(snippet.code));
  const all = loadSnippets();
  const idx = all.findIndex((s) => s.id === id);
  if (idx >= 0) {
    all[idx].lastUsedAt = new Date().toISOString();
    saveSnippets(all);
  }
  return true;
});

ipcMain.handle("snippets:export", async () => {
  const win = BrowserWindow.getFocusedWindow() ?? mainWindow;
  const result = await dialog.showSaveDialog(win!, {
    title: "Snippet arşivini dışa aktar",
    defaultPath: "snippets-export.json",
    filters: [{ name: "JSON", extensions: ["json"] }],
  });
  if (result.canceled || !result.filePath) return false;
  fs.writeFileSync(result.filePath, JSON.stringify(loadSnippets(), null, 2), "utf8");
  return true;
});

ipcMain.handle("snippets:import", async () => {
  const win = BrowserWindow.getFocusedWindow() ?? mainWindow;
  const result = await dialog.showOpenDialog(win!, {
    title: "Snippet arşivini içe aktar",
    filters: [{ name: "JSON", extensions: ["json"] }],
    properties: ["openFile"],
  });
  if (result.canceled || !result.filePaths[0]) return { imported: 0 };
  return { imported: mergeImport(parseImportJson(fs.readFileSync(result.filePaths[0], "utf8"))) };
});

// Sürüklenen/seçilen dosyanın içeriği arayüzde okunur; yol gerekmez (sanal dosyalarda da çalışır).
ipcMain.handle("snippets:importText", (_event, raw: string) => ({
  imported: mergeImport(parseImportJson(String(raw))),
}));

ipcMain.handle("app:showPalette", () => createPaletteWindow());

// Kısayol başka uygulamada kayıtlıysa arayüz kullanıcıyı uyarır.
ipcMain.handle("app:hotkeyOk", () => hotkeyOk);

ipcMain.handle("app:hidePalette", () => {
  paletteWindow?.hide();
});

ipcMain.handle("app:editSnippet", (_event, id: string) => {
  showMainWithSnippet(id);
});

// Tek örnek: ikinci açılış yeni pencere/kısayol çakışması yerine mevcut pencereyi öne getirir.
if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (!mainWindow) createMainWindow();
    if (mainWindow?.isMinimized()) mainWindow.restore();
    mainWindow?.show();
    mainWindow?.focus();
  });

  app.whenReady().then(() => {
    process.env.APP_ROOT = path.join(__dirname, "..");
    createMainWindow();
    registerHotkey();
  });
}

app.on("will-quit", () => {
  globalShortcut.unregisterAll();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  else mainWindow?.show();
});
