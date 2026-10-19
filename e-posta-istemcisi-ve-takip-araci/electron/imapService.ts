import { ImapFlow } from "imapflow";
import type { Account, AppSettings, MailMessage } from "./types";
import { accountCanSync, parseImapUid, resolveImapAuth } from "./imapAuth";
import { fallbackParse, parseMailSource } from "./mailParser";

async function createClient(account: Account & { password?: string }) {
  const auth = await resolveImapAuth(account);
  const client = new ImapFlow({
    host: account.server,
    port: account.imapPort || 993,
    secure: (account.imapPort || 993) === 993,
    auth,
    logger: false,
  });
  await client.connect();
  return client;
}

export async function testConnection(
  account: Account & { password?: string }
): Promise<{ ok: boolean; message: string }> {
  if (!accountCanSync(account)) {
    return { ok: false, message: "Sunucu, e-posta ve kimlik bilgisi gerekli" };
  }
  try {
    const client = await createClient(account);
    const status = await client.status("INBOX", { messages: true });
    await client.logout();
    return { ok: true, message: `Bağlantı OK — ${(status && status.messages) || 0} mesaj` };
  } catch (e) {
    return { ok: false, message: e instanceof Error ? e.message : String(e) };
  }
}

export async function markSeenOnServer(
  account: Account & { password?: string },
  messageId: string
): Promise<boolean> {
  const uid = parseImapUid(messageId, account.id);
  if (!uid || !accountCanSync(account)) return false;

  try {
    const client = await createClient(account);
    const lock = await client.getMailboxLock("INBOX");
    try {
      await client.messageFlagsAdd({ uid }, ["\\Seen"], { uid: true });
    } finally {
      lock.release();
    }
    await client.logout();
    return true;
  } catch {
    return false;
  }
}

export async function syncImapInbox(
  account: Account & { password?: string },
  settings: AppSettings
): Promise<MailMessage[]> {
  if (!accountCanSync(account)) {
    throw new Error(`${account.email || "Hesap"}: kimlik bilgisi eksik`);
  }

  const client = await createClient(account);
  const lock = await client.getMailboxLock("INBOX");
  const imported: MailMessage[] = [];
  const cutoff = Date.now() - settings.cacheDays * 86400000;

  try {
    const status = await client.status("INBOX", { messages: true });
    const total = (status && status.messages) || 0;
    const fetchCount = Math.min(total, 150);
    const start = Math.max(1, total - fetchCount + 1);
    const range = `${start}:${total}`;

    // Son 150 mesaj sıra numarasıyla (seq) çekilir; kimlik için UID kullanılır (imap-<hesap>-<uid>).
    // Boş kutuda "1:1" aralığı sunucu hatası verir, bu yüzden fetch atlanır.
    if (total > 0) for await (const msg of client.fetch(range, {
      envelope: true,
      source: true,
      uid: true,
      flags: true,
    })) {
      const msgDate = msg.envelope?.date ? new Date(msg.envelope.date).getTime() : Date.now();
      if (msgDate < cutoff) continue;

      let parsed: MailMessage;
      if (msg.source) {
        try {
          parsed = await parseMailSource(msg.source, account.id, msg.uid, account.email);
        } catch {
          parsed = fallbackParse(msg.source, account.id, msg.uid, account.email);
        }
      } else {
        parsed = fallbackParse(Buffer.from(""), account.id, msg.uid, account.email);
      }
      parsed.read = msg.flags?.has("\\Seen") ?? false;
      imported.unshift(parsed);
    }
  } finally {
    lock.release();
    // Hata olsa da bağlantıyı kapat; aksi halde her başarısız senkronda bir IMAP oturumu açık kalıyordu.
    await client.logout().catch(() => {});
  }

  return imported;
}

export async function syncAllAccounts(
  accounts: (Account & { password?: string })[],
  settings: AppSettings
): Promise<{
  results: { accountId: string; count: number; messages: MailMessage[] }[];
  errors: string[];
}> {
  const results: { accountId: string; count: number; messages: MailMessage[] }[] = [];
  const errors: string[] = [];
  for (const account of accounts) {
    if (!accountCanSync(account)) continue;
    try {
      const messages = await syncImapInbox(account, settings);
      results.push({ accountId: account.id, count: messages.length, messages });
    } catch (e) {
      // Önceden ilk hatalı hesap tüm senkronu iptal ediyordu; diğer hesaplar yine senkronlanır.
      errors.push(`${account.email}: ${e instanceof Error ? e.message : String(e)}`);
    }
  }
  return { results, errors };
}

export async function fetchNewSinceIdle(
  account: Account & { password?: string },
  settings: AppSettings
): Promise<MailMessage[]> {
  return syncImapInbox(account, settings);
}
