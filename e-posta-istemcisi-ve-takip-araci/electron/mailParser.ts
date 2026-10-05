import { simpleParser } from "mailparser";
import type { MailAttachment, MailMessage } from "./types";

export async function parseMailSource(
  source: Buffer,
  accountId: string,
  uid: number,
  accountEmail: string
): Promise<MailMessage> {
  const parsed = await simpleParser(source);
  const from = parsed.from?.value?.[0]?.address ?? "bilinmiyor";
  const subject = parsed.subject ?? "(konu yok)";
  const date = parsed.date?.toISOString() ?? new Date().toISOString();
  const body = parsed.text?.slice(0, 12000) ?? "";
  const bodyHtml = parsed.html ? String(parsed.html).slice(0, 50000) : undefined;
  const attachments: MailAttachment[] = (parsed.attachments ?? []).map((a) => ({
    name: a.filename ?? "ek",
    size: a.size ?? 0,
  }));

  return {
    id: `imap-${accountId}-${uid}`,
    accountId,
    folder: "inbox",
    from,
    to: accountEmail,
    subject,
    body: body || (bodyHtml ? stripHtml(bodyHtml).slice(0, 12000) : ""),
    bodyHtml,
    read: false,
    starred: false,
    archived: false,
    date,
    remote: true,
    snoozedUntil: null,
    tracking: null,
    attachments: attachments.length ? attachments : undefined,
  };
}

function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim();
}

export function fallbackParse(
  source: Buffer,
  accountId: string,
  uid: number,
  accountEmail: string
): MailMessage {
  const text = source.toString("utf8");
  const plain = text.split("\r\n\r\n").slice(1).join("\r\n\r\n");
  const body = plain.slice(0, 8000) || text.slice(0, 8000);
  const subjectMatch = text.match(/^Subject:\s*(.+)$/im);
  const fromMatch = text.match(/^From:\s*(.+)$/im);
  return {
    id: `imap-${accountId}-${uid}`,
    accountId,
    folder: "inbox",
    from: fromMatch?.[1]?.trim() ?? "bilinmiyor",
    to: accountEmail,
    subject: subjectMatch?.[1]?.trim() ?? "(konu yok)",
    body,
    read: false,
    starred: false,
    archived: false,
    date: new Date().toISOString(),
    remote: true,
    snoozedUntil: null,
    tracking: null,
  };
}
