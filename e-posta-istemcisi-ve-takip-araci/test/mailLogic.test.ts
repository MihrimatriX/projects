import { describe, expect, it } from "vitest";
import {
  appendEthicalFooter,
  filterMessages,
  matchesFolder,
  mergeImportedInbox,
  normalizeSubject,
  overdueTracking,
  pruneOldMessages,
  resolveRepliedTracking,
  sanitizeImportedMessages,
} from "../electron/mailLogic";
import type { MailMessage } from "../electron/types";

const base = (patch: Partial<MailMessage>): MailMessage => ({
  id: "1",
  accountId: "a1",
  folder: "inbox",
  from: "a@test.com",
  to: "b@test.com",
  subject: "Test",
  body: "hello",
  read: false,
  starred: false,
  archived: false,
  date: new Date().toISOString(),
  ...patch,
});

describe("mailLogic", () => {
  it("matches inbox excluding archived and snoozed", () => {
    const now = Date.now();
    expect(matchesFolder(base({ archived: true }), "inbox", now)).toBe(false);
    expect(
      matchesFolder(base({ snoozedUntil: new Date(now + 3600000).toISOString() }), "inbox", now)
    ).toBe(false);
    expect(matchesFolder(base({}), "inbox", now)).toBe(true);
  });

  it("lists snoozed inbox mail only in the snoozed view until it wakes", () => {
    const now = Date.now();
    const later = base({ snoozedUntil: new Date(now + 3600000).toISOString() });
    expect(matchesFolder(later, "snoozed", now)).toBe(true);
    expect(matchesFolder(later, "snoozed", now + 7200000)).toBe(false);
    expect(matchesFolder(base({}), "snoozed", now)).toBe(false);
    expect(matchesFolder({ ...later, folder: "trash" }, "snoozed", now)).toBe(false);
  });

  it("matches unified across accounts", () => {
    const now = Date.now();
    expect(matchesFolder(base({ accountId: "x" }), "unified", now)).toBe(true);
  });

  it("filters by search query", () => {
    const all = [base({ subject: "Alpha" }), base({ id: "2", subject: "Beta" })];
    expect(filterMessages(all, "inbox", { query: "alpha" }).length).toBe(1);
  });

  it("prunes only old server-cached inbox copies; local, sent, starred and tracked mail is kept", () => {
    const oldDate = new Date(Date.now() - 40 * 86400000).toISOString();
    const all = [
      base({ id: "old", remote: true, date: oldDate }),
      base({ id: "welcome" }),
      base({ id: "sent-old", folder: "sent", date: oldDate }),
      base({ id: "star-old", remote: true, starred: true, date: oldDate }),
      base({ id: "track-old", remote: true, date: oldDate, tracking: { waitingReply: true, startedAt: oldDate, reminderDays: 3 } }),
    ];
    const kept = pruneOldMessages(all, 30).map((m) => m.id);
    expect(kept).toEqual(["welcome", "sent-old", "star-old", "track-old"]);
    expect(filterMessages(all, "sent", {}).map((m) => m.id)).toEqual(["sent-old"]);
  });

  it("normalizes reply/forward subject prefixes", () => {
    expect(normalizeSubject("Re: Ynt: FW: Teklif")).toBe("teklif");
    expect(normalizeSubject("RE[2]: teklif ")).toBe("teklif");
  });

  it("closes tracking when the recipient replies with the same subject", () => {
    const started = new Date(Date.now() - 2 * 86400000).toISOString();
    const sent = base({
      id: "s1",
      folder: "sent",
      to: "Ayşe <ayse@test.com>",
      subject: "Teklif",
      tracking: { waitingReply: true, startedAt: started, reminderDays: 3 },
    });
    const otherSender = base({ id: "i0", from: "baska@test.com", subject: "Re: Teklif" });
    const otherSubject = base({ id: "i1", from: "ayse@test.com", subject: "Başka konu" });
    expect(resolveRepliedTracking([sent], [otherSender, otherSubject])).toEqual([]);
    const reply = base({ id: "i2", from: "ayse@test.com", subject: "Ynt: Teklif" });
    const [closed] = resolveRepliedTracking([sent], [reply]);
    expect(closed.tracking).toMatchObject({ waitingReply: false, repliedAt: reply.date });
    const oldReply = base({ id: "i3", from: "ayse@test.com", subject: "Re: Teklif", date: new Date(Date.now() - 5 * 86400000).toISOString() });
    expect(resolveRepliedTracking([sent], [oldReply])).toEqual([]);
  });

  it("sanitizes imported backup messages", () => {
    const out = sanitizeImportedMessages([
      { id: "ok", folder: "sent", subject: "S", date: "2025-01-01T00:00:00Z" },
      { id: "", folder: "inbox" },
      { id: "x", folder: "spam" },
      null,
      "metin",
    ]);
    expect(out).toHaveLength(1);
    expect(out[0]).toMatchObject({ id: "ok", from: "", to: "", body: "", read: false, accountId: "local" });
    expect(sanitizeImportedMessages({ not: "array" })).toEqual([]);
  });

  it("detects overdue tracking", () => {
    const msg = base({
      tracking: {
        waitingReply: true,
        startedAt: new Date(Date.now() - 5 * 86400000).toISOString(),
        reminderDays: 3,
      },
    });
    expect(overdueTracking([msg]).length).toBe(1);
  });

  it("keeps local flags of synced inbox messages", () => {
    const local = base({ id: "imap-a1-5", remote: true, archived: true, starred: true });
    const fromServer = base({ id: "imap-a1-5", remote: true, read: true, subject: "Yeni" });
    const [merged] = mergeImportedInbox([local], [fromServer], "a1");
    expect(merged.archived).toBe(true);
    expect(merged.starred).toBe(true);
    expect(merged.read).toBe(true);
    expect(merged.subject).toBe("Yeni");
  });

  it("appends ethical read receipt footer once", () => {
    const once = appendEthicalFooter("Merhaba", true);
    expect(once).toContain("Okundu bildirimi");
    expect(appendEthicalFooter(once, true)).toBe(once);
  });
});
