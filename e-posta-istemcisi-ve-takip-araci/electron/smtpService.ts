import nodemailer from "nodemailer";
import fs from "fs";
import type { Account, AttachmentInput } from "./types";
import { appendEthicalFooter, bodyToHtml } from "./mailLogic";
import { accountCanSync, resolveSmtpAuth } from "./imapAuth";

export async function sendViaSmtp(
  account: Account & { password?: string },
  input: {
    to: string;
    subject: string;
    body: string;
    bodyHtml?: string;
    attachments?: AttachmentInput[];
    requestReadReceipt?: boolean;
  }
) {
  if (!accountCanSync(account)) {
    throw new Error("SMTP için kimlik bilgisi gerekli");
  }

  const text = appendEthicalFooter(input.body, Boolean(input.requestReadReceipt));
  const html = input.bodyHtml ?? bodyToHtml(text);
  const transporter = await createTransport(account);

  await transporter.sendMail({
    from: account.displayName ? { name: account.displayName, address: account.email } : account.email,
    to: input.to,
    subject: input.subject,
    text,
    html,
    attachments: (input.attachments ?? []).map((a) => ({
      filename: a.name,
      path: a.path,
    })),
  });
}

async function createTransport(account: Account & { password?: string }) {
  if (!account.smtpServer) throw new Error("SMTP sunucu adresi gerekli");
  const port = account.smtpPort || 587;
  return nodemailer.createTransport({
    host: account.smtpServer,
    port,
    secure: port === 465,
    auth: await resolveSmtpAuth(account),
    connectionTimeout: 20000,
  });
}

/** Bağlantı testi: SMTP sunucusuna bağlanıp kimlik doğrulamasını dener (mesaj göndermez). */
export async function verifySmtp(account: Account & { password?: string }): Promise<{ ok: boolean; message: string }> {
  try {
    const transporter = await createTransport(account);
    await transporter.verify();
    transporter.close();
    return { ok: true, message: "SMTP OK" };
  } catch (e) {
    return { ok: false, message: `SMTP: ${e instanceof Error ? e.message : String(e)}` };
  }
}

export function attachmentSize(paths: AttachmentInput[]): number {
  return paths.reduce((sum, a) => {
    try {
      return sum + fs.statSync(a.path).size;
    } catch {
      return sum;
    }
  }, 0);
}
