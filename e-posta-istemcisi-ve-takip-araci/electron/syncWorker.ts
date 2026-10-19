import { BrowserWindow, Notification } from "electron";
import { listAccounts } from "./accounts";
import { accountCanSync } from "./imapAuth";
import { syncAllAccounts } from "./imapService";
import {
  getSettings,
  mergeInboxForAccount,
  processOverdueTracking,
  wakeSnoozed,
} from "./store";

let syncTimer: ReturnType<typeof setInterval> | null = null;
let syncing = false;

function notify(title: string, body: string) {
  if (!Notification.isSupported()) return;
  new Notification({ title, body }).show();
}

export async function runBackgroundSync(): Promise<{ total: number; errors: string[] }> {
  if (syncing) return { total: 0, errors: [] };
  syncing = true;
  const settings = getSettings();
  const errors: string[] = [];
  let total = 0;

  try {
    wakeSnoozed();
    const overdue = processOverdueTracking();
    if (settings.notifyTrackingDue) {
      for (const msg of overdue) {
        notify("Takip hatırlatma", `"${msg.subject}" için yanıt süresi doldu`);
      }
    }

    const accounts = listAccounts().filter((a) => accountCanSync(a));
    if (accounts.length === 0) return { total: 0, errors };

    // Bir hesabın hatası diğer hesapların senkronunu durdurmaz.
    const { results, errors: syncErrors } = await syncAllAccounts(accounts, settings);
    errors.push(...syncErrors);
    for (const r of results) {
      const replied = mergeInboxForAccount(r.accountId, r.messages);
      total += r.count;
      if (settings.notifyTrackingDue) {
        for (const msg of replied) notify("Yanıt geldi", `"${msg.subject}" yanıtlandı — takip kapatıldı`);
      }
    }
    if (settings.notifyNewMail && total > 0) {
      notify("E-posta", `${total} mesaj senkronize edildi`);
    }

    BrowserWindow.getAllWindows().forEach((win) => {
      win.webContents.send("mail:synced", { total, errors });
    });
  } finally {
    syncing = false;
  }

  return { total, errors };
}

export function startBackgroundSync() {
  stopBackgroundSync();
  const settings = getSettings();
  if (!settings.backgroundSync || settings.syncIntervalMinutes <= 0) return;

  const ms = settings.syncIntervalMinutes * 60 * 1000;
  syncTimer = setInterval(() => {
    runBackgroundSync().catch(() => {});
  }, ms);
}

export function stopBackgroundSync() {
  if (syncTimer) {
    clearInterval(syncTimer);
    syncTimer = null;
  }
}

export function restartBackgroundSync() {
  stopBackgroundSync();
  startBackgroundSync();
}
