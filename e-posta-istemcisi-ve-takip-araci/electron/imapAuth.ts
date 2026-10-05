import type { Account } from "./types";
import { getOAuthAccessToken, getRefreshToken, hasOAuthToken } from "./oauthGmail";

export type ImapAuth =
  | { user: string; pass: string }
  | { user: string; accessToken: string };

export async function resolveImapAuth(
  account: Account & { password?: string }
): Promise<ImapAuth> {
  if (account.authMode === "oauth" || hasOAuthToken(account.id)) {
    const token = await getOAuthAccessToken(account.id, account.googleClientId ?? "");
    if (!token) throw new Error("OAuth oturumu süresi doldu — yeniden bağlanın");
    return { user: account.email, accessToken: token };
  }
  if (!account.password) throw new Error("Şifre veya OAuth gerekli");
  return { user: account.email, pass: account.password };
}

export function accountCanSync(account: Account & { password?: string }): boolean {
  if (!account.server || !account.email) return false;
  return Boolean(account.password) || account.authMode === "oauth" || hasOAuthToken(account.id);
}

export function parseImapUid(messageId: string, accountId: string): number | null {
  const prefix = `imap-${accountId}-`;
  if (!messageId.startsWith(prefix)) return null;
  const uid = parseInt(messageId.slice(prefix.length), 10);
  return Number.isFinite(uid) ? uid : null;
}

export async function resolveSmtpAuth(account: Account & { password?: string }) {
  if (account.authMode === "oauth" || hasOAuthToken(account.id)) {
    const accessToken = await getOAuthAccessToken(account.id, account.googleClientId ?? "");
    return {
      type: "OAuth2" as const,
      user: account.email,
      accessToken: accessToken ?? undefined,
      refreshToken: getRefreshToken(account.id),
      clientId: account.googleClientId,
    };
  }
  return { user: account.email, pass: account.password };
}
