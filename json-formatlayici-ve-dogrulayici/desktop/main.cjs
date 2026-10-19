// Electron kabugu: Next.js statik export'unu (out/) app:// protokolu ile pencerede acar.
const { app, BrowserWindow, protocol, net, session, shell } = require("electron");
const path = require("node:path");
const { pathToFileURL } = require("node:url");
const { resolveStaticFile } = require("./resolve.cjs");

const SCHEME = "app";
const ROOT = path.join(__dirname, "..", "out");
const START_URL = `${SCHEME}://local/lab`;

// Testler gercek kullanici verisine dokunmasin: profil (localStorage) ve indirme klasoru env ile yonlendirilebilir.
if (process.env.JSON_LAB_USER_DATA) app.setPath("userData", process.env.JSON_LAB_USER_DATA);

protocol.registerSchemesAsPrivileged([
  { scheme: SCHEME, privileges: { standard: true, secure: true, supportFetchAPI: true, corsEnabled: true } },
]);

function createWindow() {
  const win = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 720,
    minHeight: 480,
    backgroundColor: "#1e1e1e",
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, nodeIntegration: false, sandbox: true },
  });
  // Dis baglantilar varsayilan tarayicida acilir; uygulama penceresi app:// disina cikmaz.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:/i.test(url)) void shell.openExternal(url);
    return { action: "deny" };
  });
  win.webContents.on("will-navigate", (event, url) => {
    if (!url.startsWith(`${SCHEME}://`)) {
      event.preventDefault();
      if (/^https?:/i.test(url)) void shell.openExternal(url);
    }
  });
  void win.loadURL(START_URL);
}

app.whenReady().then(() => {
  protocol.handle(SCHEME, (request) => {
    const file = resolveStaticFile(ROOT, new URL(request.url).pathname);
    if (file) return net.fetch(pathToFileURL(file).toString());
    const notFound = resolveStaticFile(ROOT, "/404");
    return notFound
      ? net.fetch(pathToFileURL(notFound).toString()).then((r) => new Response(r.body, { status: 404, headers: r.headers }))
      : new Response("Bulunamadi", { status: 404 });
  });
  // Kaydet (indir): varsayilan olarak "Farkli kaydet" penceresi; testte dogrudan klasore yazilir.
  const downloadDir = process.env.JSON_LAB_DOWNLOAD_DIR;
  if (downloadDir) {
    session.defaultSession.on("will-download", (_e, item) => item.setSavePath(path.join(downloadDir, item.getFilename())));
  }
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => app.quit());
