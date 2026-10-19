import { app, BrowserWindow, dialog, ipcMain, Menu, Notification, Tray, nativeImage, nativeTheme } from "electron";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import {
  applyProviderPreset,
  createAccountId,
  getAccount,
  listAccounts,
  listAccountsForUi,
  saveAccounts,
} from "./accounts";
import { getDb, upsertMany } from "./db";
import { sanitizeImportedMessages } from "./mailLogic";
import { restartIdleListeners, startIdleListeners, stopIdleListeners } from "./idleService";
import { markSeenOnServer, testConnection } from "./imapService";
import { accountCanSync } from "./imapAuth";
import { revokeOAuth, startGoogleOAuth } from "./oauthGmail";
import { attachmentSize, sendViaSmtp, verifySmtp } from "./smtpService";
import { restartBackgroundSync, runBackgroundSync, startBackgroundSync } from "./syncWorker";
import {
  appendMessage,
  bulkUpdate,
  deleteMessage,
  deleteTemplate,
  discardDraft,
  emptyTrash,
  exportMailbox,
  folderCounts,
  getMessage,
  getSettings,
  importMailbox,
  listMessages,
  listTemplates,
  markAllRead,
  saveSettings,
  saveTemplate,
  trackingItems,
  updateMessage,
} from "./store";
import type {
  Account,
  MailFolderView,
  MailMessage,
  MailTemplate,
  MailTracking,
  SearchFilters,
  SendMailInput,
} from "./types";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let quitting = false;

function resolveAppIconPath(): string | undefined {
  for (const candidate of [
    path.join(__dirname, "../build/icon.png"),
    // Paketli sürümde build/ yok; public/icon.png vite ile dist/ içine kopyalanır.
    // (Önceden exe'de tepsi ikonu boş kalıyor, tepsiye küçülen pencere geri açılamıyordu.)
    path.join(__dirname, "../dist/icon.png"),
    path.join(process.cwd(), "build/icon.png"),
  ]) {
    if (fs.existsSync(candidate)) return candidate;
  }
  return undefined;
}

function resolveAppIconImage() {
  const iconPath = resolveAppIconPath();
  if (iconPath) return nativeImage.createFromPath(iconPath);
  return nativeImage.createEmpty();
}

// Testler / taşınabilir kullanım: veri klasörü (mailbox.db, ayarlar, şifreli kimlik bilgileri) değiştirilebilir.
if (process.env.EPOSTA_DATA_DIR) app.setPath("userData", process.env.EPOSTA_DATA_DIR);

const gotLock = app.requestSingleInstanceLock();
if (!gotLock) {
  app.quit();
}

/** Tema ayarı: CSS'teki prefers-color-scheme Electron'un themeSource'unu izler. */
function applyTheme() {
  const theme = getSettings().theme;
  nativeTheme.themeSource = theme === "light" || theme === "dark" ? theme : "system";
}

function notify(title: string, body: string) {
  if (!Notification.isSupported()) return;
  new Notification({ title, body }).show();
}

function showMainWindow() {
  if (!mainWindow) createWindow();
  mainWindow?.show();
  mainWindow?.focus();
}

function createTray() {
  if (tray) return;
  tray = new Tray(resolveAppIconImage());
  tray.setToolTip("E-posta İstemcisi");
  tray.setContextMenu(
    Menu.buildFromTemplate([
      { label: "Göster", click: showMainWindow },
      { label: "Senkronize et", click: () => runBackgroundSync().catch(() => {}) },
      { type: "separator" },
      {
        label: "Çıkış",
        click: () => {
          quitting = true;
          app.quit();
        },
      },
    ])
  );
  tray.on("double-click", showMainWindow);
}

function createWindow() {
  const icon = resolveAppIconPath();
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 1024,
    minHeight: 640,
    title: "E-posta İstemcisi",
    ...(icon ? { icon } : {}),
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

  mainWindow.on("close", (e) => {
    if (getSettings().minimizeToTray && !quitting) {
      e.preventDefault();
      mainWindow?.hide();
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

function registerHandlers() {
  // Şifreler renderer'a gönderilmez (listAccountsForUi yalnızca hasPassword döner).
  ipcMain.handle("account:list", () => listAccountsForUi());
  ipcMain.handle("account:activeId", () => getAccount()?.id ?? null);
  ipcMain.handle("account:save", (_e, accounts: Account[], activeId?: string) =>
    saveAccounts(accounts, activeId)
  );
  ipcMain.handle("account:createId", () => createAccountId());
  ipcMain.handle("account:preset", (_e, provider: string) =>
    applyProviderPreset(provider as "gmail" | "outlook" | "custom")
  );
  ipcMain.handle("account:test", async (_e, account: Account & { password?: string }) => {
    // Şifre alanı boş bırakıldıysa kayıtlı şifreyle test edilir.
    const stored = account.id ? getAccount(account.id) : null;
    const full = { ...account, password: account.password || stored?.password || "" };
    const imap = await testConnection(full);
    if (!full.smtpServer) return imap;
    const smtp = await verifySmtp(full);
    return { ok: imap.ok && smtp.ok, message: `IMAP: ${imap.message} · ${smtp.message}` };
  });
  ipcMain.handle("oauth:google", async (_e, accountId: string, clientId: string, email?: string) => {
    const result = await startGoogleOAuth(accountId, clientId, email);
    const accounts = listAccounts();
    const idx = accounts.findIndex((a) => a.id === accountId);
    if (idx >= 0) {
      accounts[idx] = {
        ...accounts[idx],
        authMode: "oauth",
        googleClientId: clientId,
        provider: "gmail",
        ...applyProviderPreset("gmail"),
      };
      saveAccounts(accounts);
    }
    return result;
  });
  ipcMain.handle("oauth:revoke", (_e, accountId: string) => {
    revokeOAuth(accountId);
    return true;
  });

  ipcMain.handle("settings:get", () => getSettings());
  ipcMain.handle("settings:save", (_e, patch: unknown) => {
    const settings = saveSettings(patch as Partial<ReturnType<typeof getSettings>>);
    applyTheme();
    restartBackgroundSync();
    restartIdleListeners();
    return settings;
  });

  ipcMain.handle("mail:list", (_e, folder: MailFolderView, filters?: SearchFilters) =>
    listMessages(folder, filters ?? {})
  );
  ipcMain.handle("mail:counts", () => folderCounts());

  ipcMain.handle("mail:syncImap", async () => {
    const result = await runBackgroundSync();
    return { count: result.total, errors: result.errors };
  });

  ipcMain.handle("mail:send", async (_e, input: SendMailInput) => {
    const account = getAccount(input.accountId) ?? getAccount();
    if (!account) throw new Error("Hesap tanımlı değil");

    const from = account.email || account.displayName || "ben@yerel";
    const now = new Date().toISOString();
    const to = String(input.to ?? "").trim();
    const subject = String(input.subject ?? "").trim() || "(konu yok)";
    const body = String(input.body ?? "");
    const attachments = input.attachments ?? [];

    if (attachments.length > 0 && attachmentSize(attachments) > 25 * 1024 * 1024) {
      throw new Error("Ek dosyalar toplam 25 MB sınırını aşıyor");
    }

    if (!to) throw new Error("Alıcı adresi gerekli");
    // Önceden kimlik bilgisi yoksa mesaj hiç gönderilmeden "Gönderilenler"e yazılıyordu.
    if (!accountCanSync(account) || !account.smtpServer) {
      throw new Error(
        "Gönderim için hesap ayarları eksik (SMTP sunucu, e-posta ve şifre/OAuth). Mesajı taslak olarak kaydedebilirsiniz."
      );
    }
    await sendViaSmtp(account, {
      to,
      subject,
      body,
      bodyHtml: input.bodyHtml,
      attachments,
      requestReadReceipt: input.requestReadReceipt,
    });

    // Gönderilen taslak çöpe değil, doğrudan kaldırılır (kopyası artık Gönderilenler'de).
    if (input.draftId) discardDraft(input.draftId);

    const tracking: MailMessage["tracking"] =
      input.startTracking && input.trackingDays
        ? { waitingReply: true, startedAt: now, reminderDays: input.trackingDays }
        : null;

    const sent: MailMessage = {
      id: `${Date.now()}-sent`,
      accountId: account.id,
      folder: "sent",
      from,
      to,
      subject,
      body,
      bodyHtml: input.bodyHtml,
      read: true,
      starred: false,
      archived: false,
      date: now,
      inReplyTo: input.inReplyTo,
      snoozedUntil: null,
      tracking,
      readReceiptRequested: input.requestReadReceipt,
      attachments: attachments.map((a) => ({
        name: a.name,
        size: fs.existsSync(a.path) ? fs.statSync(a.path).size : 0,
        path: a.path,
      })),
    };

    appendMessage(sent);
    if (tracking) notify("Takip", `"${subject}" için yanıt takibi başlatıldı`);
    return sent;
  });

  ipcMain.handle("mail:saveDraft", (_e, input: SendMailInput & { id?: string }) => {
    const account = getAccount(input.accountId) ?? getAccount();
    const draft: MailMessage = {
      id: input.id ?? `draft-${Date.now()}`,
      accountId: account?.id ?? "local",
      folder: "drafts",
      from: account?.email || "taslak@yerel",
      to: String(input.to ?? ""),
      subject: String(input.subject ?? ""),
      body: String(input.body ?? ""),
      read: true,
      starred: false,
      archived: false,
      date: new Date().toISOString(),
      snoozedUntil: null,
      tracking: null,
    };
    appendMessage(draft);
    return draft;
  });

  ipcMain.handle("mail:markRead", async (_e, id: string, read = true) => {
    updateMessage(id, { read });
    if (read) {
      const msg = getMessage(id);
      const account = msg ? getAccount(msg.accountId) : null;
      if (msg && account && msg.remote) {
        await markSeenOnServer(account, id);
      }
    }
    return true;
  });

  ipcMain.handle("mail:markAllRead", (_e, folder: MailFolderView) => markAllRead(folder));
  ipcMain.handle("mail:emptyTrash", () => emptyTrash());

  ipcMain.handle("mail:toggleStar", (_e, id: string) => {
    const msg = getMessage(id);
    if (!msg) return false;
    updateMessage(id, { starred: !msg.starred });
    return true;
  });

  ipcMain.handle("mail:archive", (_e, id: string) => {
    updateMessage(id, { archived: true });
    return true;
  });

  ipcMain.handle("mail:delete", (_e, id: string) => deleteMessage(id));

  // Geri al / geri yükle: arayüzün işlem öncesi kopyaları olduğu gibi yazılır (doğrulanarak).
  ipcMain.handle("mail:restore", (_e, items: unknown) => {
    const valid = sanitizeImportedMessages(items);
    upsertMany(valid);
    return valid.length;
  });

  ipcMain.handle("mail:snooze", (_e, id: string, untilIso: string) => {
    updateMessage(id, { snoozedUntil: untilIso });
    return true;
  });

  ipcMain.handle("mail:track", (_e, id: string, tracking: MailTracking | null) => {
    updateMessage(id, { tracking });
    const msg = getMessage(id);
    if (tracking?.waitingReply && msg) {
      notify("Takip", `"${msg.subject}" için yanıt takibi başlatıldı`);
    }
    return true;
  });

  ipcMain.handle("mail:bulk", (_e, ids: string[], action: string, payload?: unknown) => {
    switch (action) {
      case "archive":
        bulkUpdate(ids, { archived: true });
        break;
      case "delete":
        for (const id of ids) deleteMessage(id);
        break;
      case "star":
        bulkUpdate(ids, { starred: true });
        break;
      case "read":
        bulkUpdate(ids, { read: true });
        break;
      case "unread":
        bulkUpdate(ids, { read: false });
        break;
      case "snooze":
        bulkUpdate(ids, { snoozedUntil: String(payload) });
        break;
      default:
        throw new Error(`Bilinmeyen toplu işlem: ${action}`);
    }
    return true;
  });

  ipcMain.handle("mail:trackingList", () => trackingItems());

  ipcMain.handle("templates:list", () => listTemplates());
  ipcMain.handle("templates:save", (_e, template: MailTemplate) => saveTemplate(template));
  ipcMain.handle("templates:delete", (_e, id: string) => {
    deleteTemplate(id);
    return true;
  });

  ipcMain.handle("dialog:pickAttachments", async () => {
    const result = await dialog.showOpenDialog(mainWindow!, {
      properties: ["openFile", "multiSelections"],
    });
    if (result.canceled) return [];
    return result.filePaths.map((p) => ({ name: path.basename(p), path: p }));
  });

  ipcMain.handle("data:export", async () => {
    const result = await dialog.showSaveDialog(mainWindow!, {
      defaultPath: "mailbox-yedek.json",
      filters: [{ name: "JSON", extensions: ["json"] }],
    });
    if (result.canceled || !result.filePath) return false;
    fs.writeFileSync(result.filePath, exportMailbox(), "utf8");
    return true;
  });

  ipcMain.handle("data:import", async () => {
    const result = await dialog.showOpenDialog(mainWindow!, {
      filters: [{ name: "JSON", extensions: ["json"] }],
      properties: ["openFile"],
    });
    if (result.canceled || !result.filePaths[0]) return 0;
    const json = fs.readFileSync(result.filePaths[0], "utf8");
    return importMailbox(json);
  });

  ipcMain.handle("app:version", () => app.getVersion());
}

if (gotLock) {
  app.on("second-instance", () => showMainWindow());

  app.whenReady().then(() => {
    getDb();
    applyTheme();
    registerHandlers();
    createWindow();
    createTray();
    startBackgroundSync();
    startIdleListeners();
  });

  app.on("before-quit", () => {
    quitting = true;
    stopIdleListeners();
  });

  app.on("window-all-closed", () => {
    if (!getSettings().minimizeToTray && process.platform !== "darwin") app.quit();
  });

  app.on("activate", () => {
    showMainWindow();
  });
}
