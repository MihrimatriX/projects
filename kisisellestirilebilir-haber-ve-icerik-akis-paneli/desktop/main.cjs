// Masaustu kabugu: Next.js standalone sunucusunu (server.js) Electron'un node'u ile bos bir yerel
// portta baslatir, hazir olunca pencerede acar, pencere kapaninca sunucuyu kapatir.
const { app, BrowserWindow, dialog, shell } = require("electron");
const { spawn } = require("child_process");
const fs = require("fs");
const net = require("net");
const path = require("path");

const TITLE = "Haber Akış Paneli";
const DB_FILE = "haber.db";

const appDir = app.isPackaged ? path.join(process.resourcesPath, "server") : path.join(__dirname, "stage");
// Veriler %APPDATA%\Haber Akis Paneli altinda; APP_DATA_DIR testlerin gercek veriye dokunmamasi icin.
if (process.env.APP_DATA_DIR) app.setPath("userData", path.resolve(process.env.APP_DATA_DIR));
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

function prepareData() {
  fs.mkdirSync(dataDir, { recursive: true });
  const db = path.join(dataDir, DB_FILE);
  // Ilk acilista semasi kurulmus bos sablon kopyalanir; mevcut veri asla ezilmez.
  if (!fs.existsSync(db)) fs.copyFileSync(path.join(appDir, "template.db"), db);
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
    },
  });
  server.on("exit", (code) => {
    server = null;
    if (!app.isQuitting) {
      dialog.showErrorBox(TITLE, `Sunucu beklenmedik şekilde kapandı (kod ${code}).\nAyrıntılar: ${path.join(dataDir, "server.log")}`);
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
      // henuz dinlemiyor
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
  const db = prepareData();
  const port = await freePort();
  const origin = `http://127.0.0.1:${port}`;
  startServer(port, db);

  win = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 720,
    minHeight: 480,
    title: TITLE,
    autoHideMenuBar: true,
    show: false,
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  // Uygulama disi baglantilar varsayilan tarayicida acilir
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith(origin)) return { action: "allow" };
    if (/^https?:/.test(url)) void shell.openExternal(url);
    return { action: "deny" };
  });
  win.webContents.on("will-navigate", (e, url) => {
    if (!url.startsWith(origin)) {
      e.preventDefault();
      if (/^https?:/.test(url)) void shell.openExternal(url);
    }
  });
  win.on("closed", () => {
    win = null;
  });

  await waitForServer(origin);
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
      dialog.showErrorBox(TITLE, `Uygulama başlatılamadı: ${err.message}`);
      app.quit();
    }),
  );
}
