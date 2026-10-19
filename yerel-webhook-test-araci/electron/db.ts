import Database from "better-sqlite3";
import { app } from "electron";
import path from "path";
import type { AppSettings, MockRule, WebhookEndpoint, WebhookRequest } from "../src/types";
import { generateId, generateSlug, maskBody, maskHeaders, truncateBody } from "./server-utils";

let db: Database.Database | null = null;

const DEFAULT_SETTINGS: AppSettings = {
  defaultPort: 8787,
  maxRequests: 1000,
  maxBodyBytes: 512_000,
  maskSecrets: true,
  autoStart: true,
};

function dbPath() {
  return path.join(app.getPath("userData"), "hookyerel.db");
}

function initSchema(database: Database.Database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS endpoints (
      id TEXT PRIMARY KEY,
      slug TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS requests (
      id TEXT PRIMARY KEY,
      endpoint_id TEXT NOT NULL,
      method TEXT NOT NULL,
      url TEXT NOT NULL,
      headers_json TEXT NOT NULL,
      body_masked TEXT NOT NULL,
      body_raw TEXT NOT NULL,
      headers_raw_json TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE CASCADE
    );
    CREATE INDEX IF NOT EXISTS idx_requests_endpoint ON requests(endpoint_id);
    CREATE INDEX IF NOT EXISTS idx_requests_ts ON requests(timestamp);
    CREATE TABLE IF NOT EXISTS mock_rules (
      id TEXT PRIMARY KEY,
      endpoint_id TEXT NOT NULL,
      method TEXT,
      path_pattern TEXT,
      status_code INTEGER NOT NULL DEFAULT 200,
      body TEXT NOT NULL DEFAULT '{"ok":true}',
      content_type TEXT NOT NULL DEFAULT 'application/json',
      priority INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE CASCADE
    );
    CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
  `);
}

export function getDb(): Database.Database {
  if (!db) {
    db = new Database(dbPath());
    db.pragma("journal_mode = WAL");
    // SQLite'ta FK (ON DELETE CASCADE) varsayılan kapalıdır; açılmazsa silinen endpoint'in istekleri/kuralları kalır
    db.pragma("foreign_keys = ON");
    initSchema(db);
    ensureDefaultEndpoint(db);
  }
  return db;
}

function ensureDefaultEndpoint(database: Database.Database) {
  const row = database.prepare("SELECT COUNT(*) as c FROM endpoints").get() as { c: number };
  if (row.c === 0) {
    insertEndpoint(database, generateId(), generateSlug());
  }
}

function insertEndpoint(database: Database.Database, id: string, slug: string) {
  database
    .prepare("INSERT INTO endpoints (id, slug, created_at) VALUES (?, ?, ?)")
    .run(id, slug, new Date().toISOString());
}

function rowToRequest(row: Record<string, unknown>): WebhookRequest {
  return {
    id: String(row.id),
    endpointId: String(row.endpoint_id),
    method: String(row.method),
    url: String(row.url),
    headers: JSON.parse(String(row.headers_json)) as Record<string, string>,
    body: String(row.body_masked),
    timestamp: String(row.timestamp),
  };
}

export function getSettings(): AppSettings {
  const database = getDb();
  const rows = database.prepare("SELECT key, value FROM settings").all() as { key: string; value: string }[];
  const map = Object.fromEntries(rows.map((r) => [r.key, r.value]));
  return {
    defaultPort: Number(map.defaultPort) || DEFAULT_SETTINGS.defaultPort,
    maxRequests: Number(map.maxRequests) || DEFAULT_SETTINGS.maxRequests,
    maxBodyBytes: Number(map.maxBodyBytes) || DEFAULT_SETTINGS.maxBodyBytes,
    maskSecrets: map.maskSecrets !== "false",
    autoStart: map.autoStart !== "false",
  };
}

export function saveSettings(settings: Partial<AppSettings>): AppSettings {
  const database = getDb();
  const current = getSettings();
  const next = { ...current, ...settings };
  const stmt = database.prepare(
    "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value"
  );
  for (const [key, value] of Object.entries(next)) {
    stmt.run(key, String(value));
  }
  return next;
}

export function listEndpoints(): WebhookEndpoint[] {
  const database = getDb();
  const rows = database.prepare("SELECT * FROM endpoints ORDER BY created_at ASC").all();
  return rows.map((row) => ({
    id: String((row as Record<string, unknown>).id),
    slug: String((row as Record<string, unknown>).slug),
    createdAt: String((row as Record<string, unknown>).created_at),
  }));
}

export function createEndpoint(): WebhookEndpoint {
  const database = getDb();
  const id = generateId();
  const slug = generateSlug();
  insertEndpoint(database, id, slug);
  return { id, slug, createdAt: new Date().toISOString() };
}

export function deleteEndpoint(id: string): boolean {
  const database = getDb();
  const count = database.prepare("SELECT COUNT(*) as c FROM endpoints").get() as { c: number };
  if (count.c <= 1) return false;
  database.prepare("DELETE FROM endpoints WHERE id = ?").run(id);
  return true;
}

export function getEndpointBySlug(slug: string): WebhookEndpoint | undefined {
  return listEndpoints().find((e) => e.slug === slug);
}

export function insertRequest(
  endpointId: string,
  method: string,
  url: string,
  rawHeaders: Record<string, string>,
  rawBody: string
): WebhookRequest {
  const database = getDb();
  const settings = getSettings();
  // Arayüze maskelenmiş kopya gider; replay ve imza doğrulama için ham gövde/başlıklar ayrı sütunda tutulur
  const truncated = truncateBody(rawBody, settings.maxBodyBytes);
  const headers = settings.maskSecrets ? maskHeaders(rawHeaders) : rawHeaders;
  const body = settings.maskSecrets ? maskBody(truncated) : truncated;
  const id = generateId();
  const timestamp = new Date().toISOString();

  database
    .prepare(
      `INSERT INTO requests (id, endpoint_id, method, url, headers_json, body_masked, body_raw, headers_raw_json, timestamp)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .run(
      id,
      endpointId,
      method,
      url,
      JSON.stringify(headers),
      body,
      truncated,
      JSON.stringify(rawHeaders),
      timestamp
    );

  trimRequests(database, settings.maxRequests);

  return { id, endpointId, method, url, headers, body, timestamp };
}

function trimRequests(database: Database.Database, max: number) {
  const count = database.prepare("SELECT COUNT(*) as c FROM requests").get() as { c: number };
  if (count.c <= max) return;
  database
    .prepare(
      `DELETE FROM requests WHERE id IN (
        SELECT id FROM requests ORDER BY timestamp ASC LIMIT ?
      )`
    )
    .run(count.c - max);
}

export function listRequests(): WebhookRequest[] {
  const database = getDb();
  const rows = database
    .prepare("SELECT * FROM requests ORDER BY timestamp DESC")
    .all() as Record<string, unknown>[];
  return rows.map(rowToRequest);
}

export function clearRequests(endpointId?: string) {
  const database = getDb();
  if (endpointId) {
    database.prepare("DELETE FROM requests WHERE endpoint_id = ?").run(endpointId);
  } else {
    database.prepare("DELETE FROM requests").run();
  }
}

export function deleteRequest(id: string): boolean {
  const database = getDb();
  const r = database.prepare("DELETE FROM requests WHERE id = ?").run(id);
  return r.changes > 0;
}

export function getRawRequest(id: string): { headers: Record<string, string>; body: string } | null {
  const database = getDb();
  const row = database.prepare("SELECT headers_raw_json, body_raw FROM requests WHERE id = ?").get(id) as
    | Record<string, unknown>
    | undefined;
  if (!row) return null;
  return {
    headers: JSON.parse(String(row.headers_raw_json)) as Record<string, string>,
    body: String(row.body_raw),
  };
}

export function listMockRules(endpointId?: string): MockRule[] {
  const database = getDb();
  const rows = endpointId
    ? database
        .prepare("SELECT * FROM mock_rules WHERE endpoint_id = ? ORDER BY priority DESC")
        .all(endpointId)
    : database.prepare("SELECT * FROM mock_rules ORDER BY priority DESC").all();
  return rows.map((row) => {
    const r = row as Record<string, unknown>;
    return {
      id: String(r.id),
      endpointId: String(r.endpoint_id),
      method: r.method ? String(r.method) : null,
      pathPattern: r.path_pattern ? String(r.path_pattern) : null,
      statusCode: Number(r.status_code),
      body: String(r.body),
      contentType: String(r.content_type),
      priority: Number(r.priority),
    };
  });
}

export function upsertMockRule(rule: Omit<MockRule, "id"> & { id?: string }): MockRule {
  const database = getDb();
  const id = rule.id ?? generateId();
  database
    .prepare(
      `INSERT INTO mock_rules (id, endpoint_id, method, path_pattern, status_code, body, content_type, priority)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(id) DO UPDATE SET
         method = excluded.method,
         path_pattern = excluded.path_pattern,
         status_code = excluded.status_code,
         body = excluded.body,
         content_type = excluded.content_type,
         priority = excluded.priority`
    )
    .run(
      id,
      rule.endpointId,
      rule.method,
      rule.pathPattern,
      rule.statusCode,
      rule.body,
      rule.contentType,
      rule.priority
    );
  return { ...rule, id } as MockRule;
}

export function deleteMockRule(id: string): boolean {
  const database = getDb();
  return database.prepare("DELETE FROM mock_rules WHERE id = ?").run(id).changes > 0;
}
