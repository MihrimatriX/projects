import fs from "fs";
import os from "os";
import path from "path";
import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";
import { state } from "./electronMock";

vi.mock("electron", () => import("./electronMock"));

// Sahte IMAP sunucusu: imapflow'un kullanılan API'si bellekte taklit edilir.
type FakeMsg = { uid: number; seen: boolean; source: string };
const server = vi.hoisted(() => ({
  boxes: {} as Record<string, FakeMsg[]>,
  fail: new Set<string>(),
  log: [] as string[],
}));

vi.mock("imapflow", () => ({
  ImapFlow: class {
    user: string;
    constructor(opts: { auth: { user: string; pass?: string } }) {
      this.user = opts.auth.user;
    }
    async connect() {
      if (server.fail.has(this.user)) throw new Error("Kimlik doğrulama başarısız");
      server.log.push(`connect ${this.user}`);
    }
    async status() {
      return { messages: (server.boxes[this.user] ?? []).length };
    }
    async getMailboxLock() {
      return { release: () => server.log.push(`release ${this.user}`) };
    }
    async *fetch(range: string) {
      server.log.push(`fetch ${range}`);
      const [start, end] = range.split(":").map(Number);
      const box = server.boxes[this.user] ?? [];
      for (let seq = start; seq <= end; seq++) {
        const m = box[seq - 1];
        yield {
          uid: m.uid,
          source: Buffer.from(m.source),
          flags: new Set(m.seen ? ["\\Seen"] : []),
          envelope: { date: new Date() },
        };
      }
    }
    async messageFlagsAdd(range: { uid: number }, flags: string[]) {
      server.log.push(`flag ${range.uid} ${flags.join(",")}`);
      const m = (server.boxes[this.user] ?? []).find((x) => x.uid === range.uid);
      if (m) m.seen = true;
    }
    async logout() {
      server.log.push(`logout ${this.user}`);
    }
  },
}));

const { syncImapInbox, syncAllAccounts, markSeenOnServer, testConnection } = await import("../electron/imapService");
const { DEFAULT_SETTINGS } = await import("../electron/types");

const rfc = (from: string, subject: string, body: string) =>
  `From: ${from}\r\nTo: ben@test.local\r\nSubject: ${subject}\r\nDate: ${new Date().toUTCString()}\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n${body}\r\n`;

const account = (email: string) => ({
  id: `acc-${email}`,
  server: "127.0.0.1",
  imapPort: 1143,
  email,
  displayName: email,
  password: "sifre",
});

beforeEach(() => {
  state.userData = fs.mkdtempSync(path.join(os.tmpdir(), "mail-imap-"));
  server.boxes = {};
  server.fail.clear();
  server.log = [];
});
afterAll(() => fs.rmSync(state.userData, { recursive: true, force: true }));

describe("IMAP senkronu (sahte imapflow)", () => {
  it("mesajları ayrıştırır, UID tabanlı kimlik ve \Seen bayrağını kullanır, en yeni önce", async () => {
    server.boxes["ben@test.local"] = [
      { uid: 41, seen: true, source: rfc("Ayse <ayse@test.local>", "Toplantı", "Yarın 10:00") },
      { uid: 42, seen: false, source: rfc("ali@test.local", "Rapor", "Ekte rapor") },
    ];
    const msgs = await syncImapInbox(account("ben@test.local"), DEFAULT_SETTINGS);
    expect(msgs.map((m) => m.id)).toEqual(["imap-acc-ben@test.local-42", "imap-acc-ben@test.local-41"]);
    expect(msgs[0]).toMatchObject({ from: "ali@test.local", subject: "Rapor", read: false, remote: true });
    expect(msgs[1]).toMatchObject({ from: "ayse@test.local", subject: "Toplantı", read: true });
    expect(msgs[1].body).toContain("Yarın 10:00");
    expect(server.log).toContain("logout ben@test.local");
  });

  it("boş gelen kutusunda fetch çağrılmaz", async () => {
    expect(await syncImapInbox(account("bos@test.local"), DEFAULT_SETTINGS)).toEqual([]);
    expect(server.log.some((l) => l.startsWith("fetch"))).toBe(false);
  });

  it("bir hesabın hatası diğer hesapların senkronunu durdurmaz", async () => {
    server.boxes["iyi@test.local"] = [{ uid: 1, seen: false, source: rfc("x@test.local", "Merhaba", "b") }];
    server.fail.add("kotu@test.local");
    const { results, errors } = await syncAllAccounts(
      [account("kotu@test.local"), account("iyi@test.local")],
      DEFAULT_SETTINGS
    );
    expect(results.map((r) => r.count)).toEqual([1]);
    expect(errors).toHaveLength(1);
    expect(errors[0]).toMatch(/^kotu@test.local: Kimlik/);
  });

  it("okundu bilgisi sunucuya UID ile yazılır; yerel mesajlar sunucuya gitmez", async () => {
    server.boxes["ben@test.local"] = [{ uid: 7, seen: false, source: rfc("a@test.local", "s", "b") }];
    const acc = account("ben@test.local");
    expect(await markSeenOnServer(acc, `imap-${acc.id}-7`)).toBe(true);
    expect(server.boxes["ben@test.local"][0].seen).toBe(true);
    expect(await markSeenOnServer(acc, "123-sent")).toBe(false);
  });

  it("bağlantı testi mesaj sayısını veya hatayı döner", async () => {
    server.boxes["ben@test.local"] = [{ uid: 1, seen: false, source: rfc("a@test.local", "s", "b") }];
    expect((await testConnection(account("ben@test.local"))).message).toMatch(/1 mesaj/);
    server.fail.add("ben@test.local");
    expect(await testConnection(account("ben@test.local"))).toMatchObject({ ok: false });
    expect((await testConnection({ ...account("ben@test.local"), password: "" })).ok).toBe(false);
  });
});
