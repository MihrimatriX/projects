// Masaüstü kabuğu: Next standalone sunucusunu (server.js) Electron'un node'u ile boş bir yerel portta
// başlatır, hazır olunca pencerede açar, pencere kapanınca (bekleyen tuval kaydı yazıldıktan sonra) kapatır.
const { app, BrowserWindow, dialog, shell } = require("electron");
const { spawn } = require("child_process");
const fs = require("fs");
const net = require("net");
const path = require("path");

const APP_NAME = "Görsel Not";
const appDir = app.isPackaged
  ? path.join(process.resourcesPath, "server")
  : path.join(__dirname, "stage");
// %APPDATA%/Gorsel Not: veritabanı ve sunucu günlüğü
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
  const db = path.join(dataDir, "panolar.db");
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
    width: 1360,
    height: 860,
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

  // Kapatmadan önce tuvalin 2 sn'lik otomatik kayıt beklemesi hemen yazılır (en fazla 5 sn beklenir).
  let flushed = false;
  win.on("close", (e) => {
    if (flushed) return;
    e.preventDefault();
    const flush = win.webContents
      .executeJavaScript("window.__flushBoardSave ? window.__flushBoardSave() : null")
      .catch(() => null);
    Promise.race([flush, new Promise((r) => setTimeout(r, 5000))]).then(() => {
      flushed = true;
      if (win) win.close();
    });
  });
  // Kayıt yine de başarısızsa sayfa kapanmayı engeller; kullanıcıya sorulur.
  win.webContents.on("will-prevent-unload", (e) => {
    const choice = dialog.showMessageBoxSync(win, {
      type: "warning",
      buttons: ["Yine de kapat", "Vazgeç"],
      defaultId: 1,
      cancelId: 1,
      title: APP_NAME,
      message: "Son değişiklikler kaydedilemedi.",
      detail: "Kapatırsanız son değişiklikler kaybolabilir.",
    });
    if (choice === 0) e.preventDefault();
    else flushed = false;
  });
  win.on("closed", () => {
    win = null;
  });

  await waitForServer(`${origin}/api/boards`);
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
