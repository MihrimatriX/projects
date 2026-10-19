import Database from "better-sqlite3";
import { app } from "electron";
import fs from "fs";
import path from "path";
import type { MailAttachment, MailMessage, MailTracking } from "./types";

let db: Database.Database | null = null;

function dbPath() {
  return path.join(app.getPath("userData"), "mailbox.db");
}

function rowToMessage(row: Record<string, unknown>): MailMessage {
  return {
    id: String(row.id),
    accountId: String(row.account_id),
    folder: row.folder as MailMessage["folder"],
    from: String(row.from_addr),
    to: String(row.to_addr),
    subject: String(row.subject),
    body: String(row.body),
    bodyHtml: row.body_html ? String(row.body_html) : undefined,
    read: Boolean(row.read_flag),
    starred: Boolean(row.starred),
    archived: Boolean(row.archived),
    date: String(row.date),
    remote: Boolean(row.remote_flag),
    snoozedUntil: row.snoozed_until ? String(row.snoozed_until) : null,
    tracking: row.tracking_json ? (JSON.parse(String(row.tracking_json)) as MailTracking) : null,
    inReplyTo: row.in_reply_to ? String(row.in_reply_to) : undefined,
    attachments: row.attachments_json
      ? (JSON.parse(String(row.attachments_json)) as MailAttachment[])
      : undefined,
    readReceiptRequested: Boolean(row.read_receipt_requested),
  };
}

function messageToRow(m: MailMessage) {
  return {
    id: m.id,
    account_id: m.accountId ?? "acc-default",
    folder: m.folder,
    from_addr: m.from,
    to_addr: m.to,
    subject: m.subject,
    body: m.body,
    body_html: m.bodyHtml ?? null,
    read_flag: m.read ? 1 : 0,
    starred: m.starred ? 1 : 0,
    archived: m.archived ? 1 : 0,
    date: m.date,
    remote_flag: m.remote ? 1 : 0,
    snoozed_until: m.snoozedUntil ?? null,
    tracking_json: m.tracking ? JSON.stringify(m.tracking) : null,
    in_reply_to: m.inReplyTo ?? null,
    attachments_json: m.attachments?.length ? JSON.stringify(m.attachments) : null,
    read_receipt_requested: m.readReceiptRequested ? 1 : 0,
  };
}

function initSchema(database: Database.Database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      folder TEXT NOT NULL,
      from_addr TEXT NOT NULL,
      to_addr TEXT NOT NULL,
      subject TEXT NOT NULL,
      body TEXT NOT NULL,
      body_html TEXT,
      read_flag INTEGER NOT NULL DEFAULT 0,
      starred INTEGER NOT NULL DEFAULT 0,
      archived INTEGER NOT NULL DEFAULT 0,
      date TEXT NOT NULL,
      remote_flag INTEGER NOT NULL DEFAULT 0,
      snoozed_until TEXT,
      tracking_json TEXT,
      in_reply_to TEXT,
      attachments_json TEXT,
      read_receipt_requested INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS idx_messages_folder ON messages(folder);
    CREATE INDEX IF NOT EXISTS idx_messages_account ON messages(account_id);
    CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date);
    CREATE INDEX IF NOT EXISTS idx_messages_subject ON messages(subject);
  `);
}

function migrateFromJson(database: Database.Database) {
  const jsonPath = path.join(app.getPath("userData"), "mailbox.json");
  if (!fs.existsSync(jsonPath)) return;
  const count = database.prepare("SELECT COUNT(*) as c FROM messages").get() as { c: number };
  if (count.c > 0) return;

  try {
    const raw = JSON.parse(fs.readFileSync(jsonPath, "utf8")) as MailMessage[];
    if (!Array.isArray(raw) || raw.length === 0) return;
    upsertMessages(database, raw);
    fs.renameSync(jsonPath, `${jsonPath}.bak`);
  } catch {
    /* ignore corrupt json */
  }
}

const UPSERT_SQL = `
  INSERT INTO messages (
    id, account_id, folder, from_addr, to_addr, subject, body, body_html,
    read_flag, starred, archived, date, remote_flag, snoozed_until,
    tracking_json, in_reply_to, attachments_json, read_receipt_requested
  ) VALUES (
    @id, @account_id, @folder, @from_addr, @to_addr, @subject, @body, @body_html,
    @read_flag, @starred, @archived, @date, @remote_flag, @snoozed_until,
    @tracking_json, @in_reply_to, @attachments_json, @read_receipt_requested
  )
  ON CONFLICT(id) DO UPDATE SET
    account_id=excluded.account_id,
    folder=excluded.folder,
    from_addr=excluded.from_addr,
    to_addr=excluded.to_addr,
    subject=excluded.subject,
    body=excluded.body,
    body_html=excluded.body_html,
    read_flag=excluded.read_flag,
    starred=excluded.starred,
    archived=excluded.archived,
    date=excluded.date,
    remote_flag=excluded.remote_flag,
    snoozed_until=excluded.snoozed_until,
    tracking_json=excluded.tracking_json,
    in_reply_to=excluded.in_reply_to,
    attachments_json=excluded.attachments_json,
    read_receipt_requested=excluded.read_receipt_requested
`;

function upsertMessages(database: Database.Database, messages: MailMessage[]) {
  const stmt = database.prepare(UPSERT_SQL);
  const tx = database.transaction((items: MailMessage[]) => {
    for (const m of items) stmt.run(messageToRow(m));
  });
  tx(messages);
}

export function getDb(): Database.Database {
  if (!db) {
    db = new Database(dbPath());
    db.pragma("journal_mode = WAL");
    initSchema(db);
    migrateFromJson(db);
  }
  return db;
}

export function loadAllMessages(): MailMessage[] {
  const rows = getDb().prepare("SELECT * FROM messages ORDER BY date DESC").all();
  return rows.map((r) => rowToMessage(r as Record<string, unknown>));
}

export function getMessageById(id: string): MailMessage | null {
  const row = getDb().prepare("SELECT * FROM messages WHERE id = ?").get(id);
  return row ? rowToMessage(row as Record<string, unknown>) : null;
}

export function saveAllMessages(messages: MailMessage[]) {
  const database = getDb();
  database.transaction(() => {
    database.prepare("DELETE FROM messages").run();
    if (messages.length) upsertMessages(database, messages);
  })();
}

export function upsertMessage(message: MailMessage) {
  getDb().prepare(UPSERT_SQL).run(messageToRow(message));
}

export function upsertMany(messages: MailMessage[]) {
  if (!messages.length) return;
  upsertMessages(getDb(), messages);
}

export function deleteMessageById(id: string) {
  getDb().prepare("DELETE FROM messages WHERE id = ?").run(id);
}

export function deleteMessagesByFolder(folder: MailMessage["folder"]) {
  getDb().prepare("DELETE FROM messages WHERE folder = ?").run(folder);
}

export function messageCount(): number {
  const row = getDb().prepare("SELECT COUNT(*) as c FROM messages").get() as { c: number };
  return row.c;
}

export function searchMessagesSql(query: string, limit = 500): MailMessage[] {
  const q = `%${query.trim().toLowerCase()}%`;
  const rows = getDb()
    .prepare(
      `SELECT * FROM messages WHERE
        lower(subject) LIKE ? OR lower(from_addr) LIKE ? OR lower(body) LIKE ?
       ORDER BY date DESC LIMIT ?`
    )
    .all(q, q, q, limit);
  return rows.map((r) => rowToMessage(r as Record<string, unknown>));
}
