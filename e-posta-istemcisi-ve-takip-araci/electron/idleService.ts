import { BrowserWindow } from "electron";
import { ImapFlow } from "imapflow";
import { listAccounts } from "./accounts";
import { accountCanSync, resolveImapAuth } from "./imapAuth";
import { fetchNewSinceIdle } from "./imapService";
import { getSettings, mergeInboxForAccount } from "./store";

let stopRequested = false;
// Her start yeni bir nesil açar; eski döngü kendi neslinin geçersiz olduğunu görünce durur.
// (Önceden restart, eski döngüyü durdurmadan ikinci bir döngü başlatıyordu.)
let generation = 0;

export function startIdleListeners() {
  stopIdleListeners();
  const settings = getSettings();
  if (!settings.useIdle) return;

  stopRequested = false;
  void idleLoop(generation);
}

export function stopIdleListeners() {
  stopRequested = true;
  generation++;
}

export function restartIdleListeners() {
  stopIdleListeners();
  startIdleListeners();
}

async function idleLoop(gen: number) {
  while (gen === generation && !stopRequested) {
    const visible = BrowserWindow.getAllWindows().some((w) => w.isVisible() && !w.isMinimized());
    if (!visible) {
      await sleep(5000);
      continue;
    }

    const accounts = listAccounts().filter((a) => accountCanSync(a));
    for (const account of accounts) {
      if (stopRequested) break;
      try {
        await idleOnce(account);
      } catch {
        /* sonraki hesap */
      }
    }
    await sleep(3000);
  }
}

async function idleOnce(account: Awaited<ReturnType<typeof listAccounts>>[number]) {
  
  const auth = await resolveImapAuth(account);
  const client = new ImapFlow({
    host: account.server,
    port: account.imapPort || 993,
    secure: (account.imapPort || 993) === 993,
    auth,
    logger: false,
  });

  let changed = false;
  client.on("exists", () => {
    changed = true;
  });

  await client.connect();
  const lock = await client.getMailboxLock("INBOX");
  try {
    const idleEnd = Date.now() + 4 * 60 * 1000;
    while (!stopRequested && Date.now() < idleEnd) {
      const remaining = idleEnd - Date.now();
      if (remaining <= 0) break;
      await Promise.race([
        client.idle(),
        sleep(Math.min(remaining, 60000)),
      ]);
      if (changed) break;
    }
  } finally {
    lock.release();
  }
  await client.logout();

  if (changed && !stopRequested) {
    const messages = await fetchNewSinceIdle(account, getSettings());
    mergeInboxForAccount(account.id, messages);
    BrowserWindow.getAllWindows().forEach((win) => {
      win.webContents.send("mail:synced", { total: messages.length, errors: [] });
    });
  }
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}
