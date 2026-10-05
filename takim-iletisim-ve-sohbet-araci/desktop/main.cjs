// Masaüstü kabuğu: paketlenmiş Next + Socket.IO sunucusunu (server.cjs) Electron'un node'u ile
// boş bir yerel portta başlatır, hazır olunca pencerede açar, pencere kapanınca sunucuyu kapatır.
const { app, BrowserWindow, dialog, shell } = require("electron");
const { spawn } = require("child_process");
const crypto = require("crypto");
const fs = require("fs");
const net = require("net");
const path = require("path");

const appDir = app.isPackaged
  ? path.join(process.resourcesPath, "server")
  : path.join(__dirname, "stage");
// %APPDATA%/Takim Sohbet: veritabanı, yüklenen dosyalar ve sunucu günlüğü.
// TAKIM_SOHBET_DATA verilirse (testler) gerçek kullanıcı verisine dokunulmaz.
if (process.env.TAKIM_SOHBET_DATA) app.setPath("userData", process.env.TAKIM_SOHBET_DATA);
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

function dbUrl(file) {
  return `file:${file.replace(/\\/g, "/")}`;
}

// Kuruluma özel rastgele anahtar: ilk açılışta üretilir ('wx' ile asla ezilmez), sonra hep aynısı okunur.
// Şifre özetleri bu anahtarla tuzlanır; dosya silinirse mevcut şifreler geçersiz olur.
function loadSecret() {
  const file = path.join(dataDir, "secret.key");
  try {
    fs.writeFileSync(file, crypto.randomBytes(32).toString("hex"), { flag: "wx" });
  } catch (err) {
    if (err.code !== "EEXIST") throw err;
  }
  return fs.readFileSync(file, "utf8").trim();
}

function runNode(script, env) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [script], {
      cwd: appDir,
      windowsHide: true,
      stdio: "ignore",
      env: { ...process.env, ELECTRON_RUN_AS_NODE: "1", ...env },
    });
    child.on("error", reject);
    child.on("exit", (code) =>
      code === 0 ? resolve() : reject(new Error(`Demo verisi yüklenemedi (kod ${code})`)),
    );
  });
}

async function prepareData(secret) {
  fs.mkdirSync(path.join(dataDir, "uploads"), { recursive: true });
  const db = path.join(dataDir, "sohbet.db");
  if (fs.existsSync(db)) return db; // mevcut veri asla ezilmez
  // İlk açılış: boş şema kopyalanır, demo kullanıcılar bu kurulumun anahtarıyla eklenir.
  // Geçici dosyada hazırlanıp sonra yeniden adlandırılır; yarım kalan kurulum bir sonraki açılışta tekrarlanır.
  const tmp = `${db}.yeni`;
  fs.copyFileSync(path.join(appDir, "template.db"), tmp);
  await runNode(path.join(appDir, "seed.cjs"), { DATABASE_URL: dbUrl(tmp), SESSION_SECRET: secret });
  fs.renameSync(tmp, db);
  return db;
}

function startServer(port, db, secret) {
  const nextConfig = JSON.parse(
    fs.readFileSync(path.join(appDir, ".next", "required-server-files.json"), "utf8"),
  ).config;
  const log = fs.openSync(path.join(dataDir, "server.log"), "w");
  server = spawn(process.execPath, [path.join(appDir, "server.cjs")], {
    cwd: appDir,
    windowsHide: true,
    stdio: ["ignore", log, log],
    env: {
      ...process.env,
      ELECTRON_RUN_AS_NODE: "1",
      NODE_ENV: "production",
      __NEXT_PRIVATE_STANDALONE_CONFIG: JSON.stringify(nextConfig),
      PORT: String(port),
      HOSTNAME: "localhost",
      LISTEN_HOST: "127.0.0.1",
      NEXT_PUBLIC_APP_URL: `http://localhost:${port}`,
      DATABASE_URL: dbUrl(db),
      UPLOAD_DIR: path.join(dataDir, "uploads"),
      SESSION_SECRET: secret,
    },
  });
  server.on("exit", (code) => {
    server = null;
    if (!app.isQuitting) {
      dialog.showErrorBox(
        "Takım Sohbet",
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
  const secret = loadSecret();
  const db = await prepareData(secret);
  const port = await freePort();
  const origin = `http://localhost:${port}`;
  startServer(port, db, secret);

  win = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 720,
    minHeight: 480,
    title: "Takım Sohbet",
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

  await waitForServer(`${origin}/login`);
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
      dialog.showErrorBox("Takım Sohbet", `Uygulama başlatılamadı: ${err.message}`);
      app.quit();
    }),
  );
}
