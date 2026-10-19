import { app } from "electron";
import fs from "fs";
import path from "path";
import { getAccount, listAccounts } from "./accounts";
import {
  deleteMessageById,
  deleteMessagesByFolder,
  getMessageById,
  loadAllMessages,
  messageCount,
  saveAllMessages,
  upsertMany,
  upsertMessage,
} from "./db";
import {
  filterMessages,
  mergeImportedInbox,
  overdueTracking,
  pruneOldMessages,
  resolveRepliedTracking,
  sanitizeImportedMessages,
  snoozedDue,
} from "./mailLogic";
import type {
  AppSettings,
  MailFolderView,
  MailMessage,
  MailTemplate,
  MailTracking,
  SearchFilters,
} from "./types";
import { DEFAULT_SETTINGS } from "./types";

function dataPath(name: string) {
  return path.join(app.getPath("userData"), name);
}

function loadJson<T>(file: string, fallback: T): T {
  try {
    return JSON.parse(fs.readFileSync(dataPath(file), "utf8")) as T;
  } catch {
    return fallback;
  }
}

function saveJson(file: string, data: unknown) {
  fs.mkdirSync(path.dirname(dataPath(file)), { recursive: true });
  fs.writeFileSync(dataPath(file), JSON.stringify(data, null, 2), "utf8");
}

export function getSettings(): AppSettings {
  return { ...DEFAULT_SETTINGS, ...loadJson<Partial<AppSettings>>("settings.json", {}) };
}

export function saveSettings(patch: Partial<AppSettings>): AppSettings {
  const next = { ...getSettings(), ...patch };
  saveJson("settings.json", next);
  return next;
}

export { getAccount, listAccounts };

export function listMessages(folder: MailFolderView, filters: SearchFilters = {}): MailMessage[] {
  ensureSeedMail();
  return filterMessages(loadAllMessages(), folder, filters, getSettings());
}

export function getMessage(id: string): MailMessage | null {
  return getMessageById(id);
}

export function updateMessage(id: string, patch: Partial<MailMessage>): MailMessage | null {
  const current = getMessageById(id);
  if (!current) return null;
  const updated = { ...current, ...patch, id: current.id };
  upsertMessage(updated);
  return updated;
}

export function deleteMessage(id: string): boolean {
  const target = getMessageById(id);
  if (!target) return false;

  if (target.folder === "trash") {
    deleteMessageById(id);
    return true;
  }

  upsertMessage({ ...target, folder: "trash", archived: false });
  return true;
}

export function mergeInboxForAccount(accountId: string, imported: MailMessage[]) {
  const merged = mergeImportedInbox(loadAllMessages(), imported, accountId);
  saveAllMessages(pruneOldMessages(merged, getSettings().cacheDays));
  // Yanıtı gelen takipler kapatılır; bildirim için döndürülür.
  return closeRepliedTracking(imported);
}

export function appendMessage(message: MailMessage) {
  upsertMessage(message);
}

export function bulkUpdate(ids: string[], patch: Partial<MailMessage>) {
  const set = new Set(ids);
  for (const m of loadAllMessages()) {
    if (set.has(m.id)) upsertMessage({ ...m, ...patch, id: m.id });
  }
}

export function markAllRead(folder: MailFolderView) {
  const items = listMessages(folder).filter((m) => !m.read);
  for (const m of items) {
    upsertMessage({ ...m, read: true });
  }
  return items.length;
}

export function emptyTrash(): number {
  const trash = listMessages("trash");
  deleteMessagesByFolder("trash");
  return trash.length;
}

export function listTemplates(): MailTemplate[] {
  return loadJson<MailTemplate[]>("templates.json", [
    {
      id: "thanks",
      name: "Teşekkür",
      subject: "Re: {konu}",
      body: "Merhaba {ad},\n\nMesajınız için teşekkür ederim.\n\nSaygılarımla,",
    },
    {
      id: "followup",
      name: "Takip",
      subject: "Re: {konu}",
      body: "Merhaba {ad},\n\nÖnceki mesajıma yanıt alamadım; müsait olduğunuzda dönüş yapabilir misiniz?\n\nTeşekkürler,",
    },
  ]);
}

export function saveTemplate(template: MailTemplate) {
  const all = listTemplates();
  const idx = all.findIndex((t) => t.id === template.id);
  if (idx >= 0) all[idx] = template;
  else all.push(template);
  saveJson("templates.json", all);
  return template;
}

export function deleteTemplate(id: string) {
  saveJson(
    "templates.json",
    listTemplates().filter((t) => t.id !== id)
  );
}

export function folderCounts(): Record<MailFolderView, number> {
  const views: MailFolderView[] = [
    "inbox",
    "unified",
    "sent",
    "drafts",
    "archive",
    "trash",
    "starred",
    "tracking",
    "snoozed",
  ];
  return Object.fromEntries(views.map((v) => [v, listMessages(v).length])) as Record<
    MailFolderView,
    number
  >;
}

export function trackingItems(): MailMessage[] {
  return listMessages("tracking");
}

export function wakeSnoozed(): MailMessage[] {
  const due = snoozedDue(loadAllMessages());
  for (const msg of due) {
    updateMessage(msg.id, { snoozedUntil: null });
  }
  return due;
}

export function processOverdueTracking(): MailMessage[] {
  const due = overdueTracking(loadAllMessages());
  for (const msg of due) {
    updateMessage(msg.id, {
      tracking: { ...msg.tracking!, notified: true },
    });
  }
  return due;
}

export function exportMailbox(): string {
  return JSON.stringify(
    {
      exportedAt: new Date().toISOString(),
      messages: loadAllMessages(),
      templates: listTemplates(),
    },
    null,
    2
  );
}

/**
 * Yedeği mevcut verilerle birleştirir (aynı id'li kayıtlar güncellenir).
 * Önceden içe aktarma tüm posta kutusunu ve şablonları siliyordu.
 */
export function importMailbox(json: string): number {
  let data: { messages?: unknown; templates?: unknown };
  try {
    data = JSON.parse(json);
  } catch {
    throw new Error("Yedek dosyası okunamadı: geçerli bir JSON değil");
  }
  const messages = sanitizeImportedMessages(data?.messages);
  if (!messages.length && !Array.isArray(data?.templates)) {
    throw new Error("Yedek dosyasında içe aktarılacak mesaj veya şablon bulunamadı");
  }
  upsertMany(messages);
  if (Array.isArray(data.templates)) {
    const byId = new Map(listTemplates().map((t) => [t.id, t]));
    for (const t of data.templates as MailTemplate[]) {
      if (t && typeof t.id === "string" && typeof t.name === "string") {
        byId.set(t.id, { id: t.id, name: t.name, subject: String(t.subject ?? ""), body: String(t.body ?? "") });
      }
    }
    saveJson("templates.json", [...byId.values()]);
  }
  return messages.length;
}

/** Gönderilen taslağı kalıcı kaldırır (yalnızca taslak klasöründeyse). */
export function discardDraft(id: string) {
  if (getMessageById(id)?.folder === "drafts") deleteMessageById(id);
}

/** Yeni gelen mesajlar takipteki gönderilmiş mesajları yanıtlıyorsa takibi kapatır. */
export function closeRepliedTracking(incoming: MailMessage[]): MailMessage[] {
  const resolved = resolveRepliedTracking(loadAllMessages(), incoming);
  for (const m of resolved) upsertMessage(m);
  return resolved;
}

function ensureSeedMail() {
  if (messageCount() > 0) return;
  const welcome: MailMessage = {
    id: "welcome",
    accountId: "local",
    folder: "inbox",
    from: "destek@ornek.com",
    to: "siz@ornek.com",
    subject: "E-posta istemcisine hoş geldiniz",
    body:
      "Yerel mod aktif.\n\nHesap ayarlarından Gmail/Outlook profili veya Google OAuth ile bağlanın.\n\nKlavye kısayolları için F1 tuşuna basın.",
    read: false,
    starred: false,
    archived: false,
    date: new Date().toISOString(),
  };
  upsertMessage(welcome);
}

export type { MailTracking };
