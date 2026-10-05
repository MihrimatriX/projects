// Masaüstü kabuğu: Next standalone sunucusunu (server.js) Electron'un node'u ile boş bir yerel portta
// başlatır, hazır olunca pencerede açar, pencere kapanınca sunucuyu kapatır.
const { app, BrowserWindow, dialog, shell } = require("electron");
const { spawn } = require("child_process");
const fs = require("fs");
const net = require("net");
const path = require("path");

const APP_NAME = "Kayıtlı Okuma";
const appDir = app.isPackaged
  ? path.join(process.resourcesPath, "server")
  : path.join(__dirname, "stage");
// %APPDATA%/Kayitli Okuma: veritabanı ve sunucu günlüğü
const dataDir = app.getPath("userData");

let server = null;
let win = null;

function freePort() {
  return new Promise((resolve, reject) => {
    const s = net.createServer();
    s.unref();
    s.on("error", reject);
    s.listen(0, "127.0.0.1", () => {
      const { port } = s.address();
      s.close(() => resolve(port));
    });
  });
}

// İlk açılışta şeması kurulu boş şablon kopyalanır; mevcut veri asla ezilmez.
function prepareDb() {
  const db = path.join(dataDir, "okuma.db");
  if (!fs.existsSync(db)) {
    const tmp = `${db}.yeni`;
    fs.copyFileSync(path.join(appDir, "template.db"), tmp);
    fs.renameSync(tmp, db);
  }
  return db;
}

function startServer(port, db) {
  const log = fs.openSync(path.join(dataDir, "server.log"), "w");
  server = spawn(process.execPath, [path.join(appDir, "server.js")], {
    cwd: appDir,
    windowsHide: true,
    stdio: ["ignore", log, log],
    env: {
      ...process.env,
      ELECTRON_RUN_AS_NODE: "1",
      NODE_ENV: "production",
      PORT: String(port),
      HOSTNAME: "127.0.0.1",
      DATABASE_URL: `file:${db.replace(/\\/g, "/")}`,
      NEXT_PUBLIC_APP_URL: `http://127.0.0.1:${port}`,
      NEXT_TELEMETRY_DISABLED: "1",
    },
  });
  server.on("exit", (code) => {
    server = null;
    if (!app.isQuitting) {
      dialog.showErrorBox(
        APP_NAME,
        `Sunucu beklenmedik şekilde kapandı (kod ${code}).\nAyrıntılar: ${path.join(dataDir, "server.log")}`,
      );
      app.quit();
    }
  });
}

async function waitForServer(url, timeoutMs = 60000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!server) throw new Error("Sunucu başlatılamadı");
    try {
      const res = await fetch(url);
      if (res.status < 500) return;
    } catch {
      // henüz dinlemiyor
    }
    await new Promise((r) => setTimeout(r, 300));
  }
  throw new Error("Sunucu zamanında yanıt vermedi");
}

function stopServer() {
  app.isQuitting = true;
  if (server) server.kill();
}

async function main() {
  fs.mkdirSync(dataDir, { recursive: true });
  const db = prepareDb();
  const port = await freePort();
  const origin = `http://127.0.0.1:${port}`;
  startServer(port, db);

  win = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 720,
    minHeight: 480,
    title: APP_NAME,
    autoHideMenuBar: true,
    show: false,
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  // Uygulama dışı bağlantılar varsayılan tarayıcıda açılır
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith(origin)) return { action: "allow" };
    if (/^https?:/.test(url)) shell.openExternal(url);
    return { action: "deny" };
  });
  win.webContents.on("will-navigate", (e, url) => {
    if (!url.startsWith(origin)) {
      e.preventDefault();
      if (/^https?:/.test(url)) shell.openExternal(url);
    }
  });

  win.on("closed", () => {
    win = null;
  });

  await waitForServer(`${origin}/api/stats`);
  await win.loadURL(origin);
  win.show();
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (win) {
      if (win.isMinimized()) win.restore();
      win.focus();
    }
  });
  app.on("window-all-closed", () => app.quit());
  app.on("before-quit", stopServer);
  app.on("will-quit", stopServer);
  app.whenReady().then(() =>
    main().catch((err) => {
      stopServer();
      dialog.showErrorBox(APP_NAME, `Uygulama başlatılamadı: ${err.message}`);
      app.quit();
    }),
  );
}
