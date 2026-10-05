import type { AppSettings, MailFolderView, MailMessage, SearchFilters } from "./types";
import { DEFAULT_SETTINGS } from "./types";

export function matchesFolder(
  message: MailMessage,
  folder: MailFolderView,
  now: number,
  accountFilter?: string
): boolean {
  if (accountFilter && message.accountId !== accountFilter) return false;
  if (message.folder === "trash") return folder === "trash";
  if (folder === "trash") return false;

  const snoozed = Boolean(
    message.snoozedUntil && new Date(message.snoozedUntil).getTime() > now
  );

  switch (folder) {
    case "inbox":
      return message.folder === "inbox" && !message.archived && !snoozed;
    case "unified":
      return message.folder === "inbox" && !message.archived && !snoozed;
    case "archive":
      return message.archived;
    case "sent":
      return message.folder === "sent";
    case "drafts":
      return message.folder === "drafts";
    case "starred":
      return message.starred;
    case "snoozed":
      return message.folder === "inbox" && !message.archived && snoozed;
    case "tracking":
      return Boolean(message.tracking?.waitingReply);
    default:
      return false;
  }
}

export function filterMessages(
  all: MailMessage[],
  folder: MailFolderView,
  filters: SearchFilters,
  settings: AppSettings = DEFAULT_SETTINGS
): MailMessage[] {
  const now = Date.now();
  const cutoff = now - settings.cacheDays * 86400000;
  let items = all.filter(
    (m) => matchesFolder(m, folder, now, filters.accountId) && !isExpiredCache(m, cutoff)
  );

  const q = filters.query?.trim().toLowerCase();
  if (q) {
    items = items.filter(
      (m) =>
        m.subject.toLowerCase().includes(q) ||
        m.from.toLowerCase().includes(q) ||
        m.to.toLowerCase().includes(q) ||
        m.body.toLowerCase().includes(q)
    );
  }

  if (filters.fromDate) {
    const from = new Date(filters.fromDate).getTime();
    items = items.filter((m) => new Date(m.date).getTime() >= from);
  }
  if (filters.toDate) {
    const to = new Date(filters.toDate).getTime();
    items = items.filter((m) => new Date(m.date).getTime() <= to);
  }

  return items.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
}

/**
 * Önbellek süresi yalnızca sunucudan gelen (yeniden indirilebilir) gelen kutusu kopyalarına uygulanır.
 * Önceden gönderilenler ve yerel mesajlar da her senkronda kalıcı olarak siliniyordu (veri kaybı).
 * Yıldızlı ve takipteki mesajlar da korunur.
 */
export function isExpiredCache(m: MailMessage, cutoff: number): boolean {
  return (
    Boolean(m.remote) &&
    m.folder === "inbox" &&
    !m.starred &&
    !m.tracking?.waitingReply &&
    new Date(m.date).getTime() < cutoff
  );
}

export function pruneOldMessages(all: MailMessage[], cacheDays: number): MailMessage[] {
  const cutoff = Date.now() - cacheDays * 86400000;
  return all.filter((m) => !isExpiredCache(m, cutoff));
}

const FOLDERS = new Set<MailMessage["folder"]>(["inbox", "sent", "drafts", "trash"]);

/** Yedek dosyasındaki mesajları doğrular; eksik/bozuk kayıtlar atlanır (DB NOT NULL hatası yerine). */
export function sanitizeImportedMessages(raw: unknown): MailMessage[] {
  if (!Array.isArray(raw)) return [];
  const out: MailMessage[] = [];
  for (const r of raw as Partial<MailMessage>[]) {
    if (!r || typeof r !== "object" || typeof r.id !== "string" || !r.id) continue;
    if (!FOLDERS.has(r.folder as MailMessage["folder"])) continue;
    const date = new Date(String(r.date ?? ""));
    out.push({
      ...r,
      id: r.id,
      accountId: typeof r.accountId === "string" ? r.accountId : "local",
      folder: r.folder as MailMessage["folder"],
      from: String(r.from ?? ""),
      to: String(r.to ?? ""),
      subject: String(r.subject ?? ""),
      body: String(r.body ?? ""),
      read: Boolean(r.read),
      starred: Boolean(r.starred),
      archived: Boolean(r.archived),
      date: Number.isNaN(date.getTime()) ? new Date().toISOString() : date.toISOString(),
    });
  }
  return out;
}

/** "Re: Ynt: FW: Konu" → "konu" */
export function normalizeSubject(subject: string): string {
  return subject
    .replace(/^\s*((re|fwd?|ynt|ilt|yanıt|ileti)\s*(\[\d+\])?\s*:\s*)+/i, "")
    .trim()
    .toLowerCase();
}

export function extractAddresses(list: string): string[] {
  return (list.match(/[^\s<>,;"]+@[^\s<>,;"]+/g) ?? []).map((a) => a.toLowerCase());
}

/**
 * Yanıt takibi: takipteki gönderilmiş bir mesajın alıcısından aynı konulu (Re: …) yeni bir mesaj
 * geldiyse takip "yanıtlandı" olarak kapatılır. Güncellenmiş mesajları döner.
 */
export function resolveRepliedTracking(all: MailMessage[], incoming: MailMessage[]): MailMessage[] {
  const resolved: MailMessage[] = [];
  for (const m of all) {
    const t = m.tracking;
    if (m.folder !== "sent" || !t?.waitingReply) continue;
    const recipients = extractAddresses(m.to);
    const subject = normalizeSubject(m.subject);
    const started = new Date(t.startedAt).getTime();
    const reply = incoming.find(
      (i) =>
        i.folder === "inbox" &&
        new Date(i.date).getTime() >= started &&
        normalizeSubject(i.subject) === subject &&
        extractAddresses(i.from).some((a) => recipients.includes(a))
    );
    if (reply) {
      resolved.push({ ...m, tracking: { ...t, waitingReply: false, repliedAt: reply.date } });
    }
  }
  return resolved;
}

export function overdueTracking(all: MailMessage[], now = Date.now()): MailMessage[] {
  return all.filter((m) => {
    const t = m.tracking;
    if (!t?.waitingReply || t.notified) return false;
    const due = new Date(t.startedAt).getTime() + t.reminderDays * 86400000;
    return now >= due;
  });
}

export function snoozedDue(all: MailMessage[], now = Date.now()): MailMessage[] {
  return all.filter(
    (m) =>
      m.folder === "inbox" &&
      m.snoozedUntil &&
      new Date(m.snoozedUntil).getTime() <= now
  );
}

export function appendEthicalFooter(body: string, requestReadReceipt: boolean): string {
  if (!requestReadReceipt) return body;
  const note =
    "\n\n—\n[Okundu bildirimi istendi — alıcı onayıyla yerel takip; gizli pixel yok.]";
  return body.includes(note) ? body : body + note;
}

export function bodyToHtml(text: string): string {
  const escaped = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
  return escaped
    .split(/\n{2,}/)
    .map((p) => `<p>${p.replace(/\n/g, "<br>")}</p>`)
    .join("");
}

export function mergeImportedInbox(
  existing: MailMessage[],
  imported: MailMessage[],
  accountId: string
): MailMessage[] {
  const sent = existing.filter((m) => m.folder === "sent");
  const drafts = existing.filter((m) => m.folder === "drafts");
  const trash = existing.filter((m) => m.folder === "trash");
  // Bu hesabın mevcut gelen kutusu (sunucudan gelenler dahil): yerel bayraklar (yıldız, arşiv,
  // erteleme, takip) korunmak üzere aşağıda sunucudan gelen kopyayla birleştirilir.
  const localInbox = existing.filter(
    (m) => m.folder === "inbox" && m.accountId === accountId
  );
  const otherAccounts = existing.filter(
    (m) => m.accountId !== accountId && m.folder !== "inbox"
  );
  const otherInboxes = existing.filter(
    (m) => m.accountId !== accountId && m.folder === "inbox"
  );

  const byId = new Map<string, MailMessage>();
  // Önce yerel kopya, sonra sunucu kopyası: içerik ve okundu bilgisi (\Seen) sunucudan,
  // diğer bayraklar yerelden gelir.
  for (const msg of [...localInbox, ...imported]) {
    const prev = byId.get(msg.id);
    if (prev) {
      byId.set(msg.id, {
        ...msg,
        read: msg.read,
        starred: prev.starred,
        archived: prev.archived,
        snoozedUntil: prev.snoozedUntil,
        tracking: prev.tracking,
      });
    } else {
      byId.set(msg.id, msg);
    }
  }

  return [...byId.values(), ...otherInboxes, ...otherAccounts, ...sent, ...drafts, ...trash];
}
