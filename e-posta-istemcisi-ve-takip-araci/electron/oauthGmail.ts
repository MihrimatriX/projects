import http from "http";
import { BrowserWindow } from "electron";
import { URL } from "url";
import crypto from "crypto";
import path from "path";
import { app } from "electron";
import { loadSecretMap, saveSecretMap } from "./secretStore";

const REDIRECT_PORT = 9876;
const REDIRECT_URI = `http://127.0.0.1:${REDIRECT_PORT}/oauth/callback`;
const GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const SCOPES = [
  "https://mail.google.com/",
  "openid",
  "email",
  "profile",
].join(" ");

type OAuthStore = Record<
  string,
  {
    refreshToken?: string;
    accessToken?: string;
    expiresAt?: number;
  }
>;

function oauthPath() {
  return path.join(app.getPath("userData"), "oauth-tokens.json");
}

function loadStore(): OAuthStore {
  const out: OAuthStore = {};
  for (const [id, json] of Object.entries(loadSecretMap(oauthPath()))) {
    try {
      out[id] = JSON.parse(json);
    } catch {
      /* bozuk girdi atlanır */
    }
  }
  return out;
}

function saveStore(store: OAuthStore) {
  const plain: Record<string, string> = {};
  for (const [id, data] of Object.entries(store)) plain[id] = JSON.stringify(data);
  saveSecretMap(oauthPath(), plain);
}

export function hasOAuthToken(accountId: string): boolean {
  return Boolean(loadStore()[accountId]?.refreshToken);
}

export function getRefreshToken(accountId: string): string | undefined {
  return loadStore()[accountId]?.refreshToken;
}

export async function getOAuthAccessToken(
  accountId: string,
  clientId: string
): Promise<string | null> {
  const store = loadStore();
  const entry = store[accountId];
  if (!entry?.refreshToken || !clientId) return null;

  if (entry.accessToken && entry.expiresAt && entry.expiresAt > Date.now() + 60000) {
    return entry.accessToken;
  }

  const body = new URLSearchParams({
    client_id: clientId,
    refresh_token: entry.refreshToken,
    grant_type: "refresh_token",
  });

  const res = await fetch(GOOGLE_TOKEN, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });

  if (!res.ok) return null;
  const data = (await res.json()) as { access_token: string; expires_in: number };
  store[accountId] = {
    ...entry,
    accessToken: data.access_token,
    expiresAt: Date.now() + data.expires_in * 1000,
  };
  saveStore(store);
  return data.access_token;
}

function pkcePair() {
  const verifier = crypto.randomBytes(32).toString("base64url");
  const challenge = crypto.createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge };
}

export async function startGoogleOAuth(
  accountId: string,
  clientId: string,
  emailHint?: string
): Promise<{ email: string }> {
  if (!clientId.trim()) throw new Error("Google OAuth Client ID gerekli");

  const { verifier, challenge } = pkcePair();

  return new Promise((resolve, reject) => {
    let authWindow: BrowserWindow | null = null;
    let settled = false;
    const finish = (err: unknown, value?: { email: string }) => {
      if (settled) return;
      settled = true;
      if (err) reject(err);
      else resolve(value!);
    };

    const server = http.createServer(async (req, res) => {
      try {
        if (!req.url?.startsWith("/oauth/callback")) return;
        const url = new URL(req.url, `http://127.0.0.1:${REDIRECT_PORT}`);
        const code = url.searchParams.get("code");
        const err = url.searchParams.get("error");
        if (err || !code) throw new Error(err ?? "OAuth kodu alınamadı");

        const tokenRes = await fetch(GOOGLE_TOKEN, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body: new URLSearchParams({
            client_id: clientId,
            code,
            grant_type: "authorization_code",
            redirect_uri: REDIRECT_URI,
            code_verifier: verifier,
          }),
        });

        if (!tokenRes.ok) {
          const t = await tokenRes.text();
          throw new Error(`Token hatası: ${t.slice(0, 200)}`);
        }

        const tokens = (await tokenRes.json()) as {
          access_token: string;
          refresh_token?: string;
          expires_in: number;
        };

        if (!tokens.refresh_token) {
          throw new Error("Refresh token alınamadı — Google'da erişimi iptal edip tekrar deneyin");
        }

        const store = loadStore();
        store[accountId] = {
          refreshToken: tokens.refresh_token,
          accessToken: tokens.access_token,
          expiresAt: Date.now() + tokens.expires_in * 1000,
        };
        saveStore(store);

        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
        res.end("<html><body><h2>Bağlantı başarılı</h2><p>Bu pencereyi kapatabilirsiniz.</p></body></html>");
        server.close();
        authWindow?.close();
        finish(null, { email: emailHint ?? "" });
      } catch (e) {
        res.writeHead(400, { "Content-Type": "text/html; charset=utf-8" });
        const msg = (e instanceof Error ? e.message : String(e)).replace(/[<>&"]/g, "");
        res.end(`<pre>${msg}</pre>`);
        server.close();
        authWindow?.close();
        finish(e);
      }
    });

    server.on("error", (e) => {
      authWindow?.close();
      finish(new Error(`OAuth yönlendirme portu ${REDIRECT_PORT} açılamadı: ${e.message}`));
    });
    server.listen(REDIRECT_PORT, "127.0.0.1");

    const params = new URLSearchParams({
      client_id: clientId,
      redirect_uri: REDIRECT_URI,
      response_type: "code",
      scope: SCOPES,
      access_type: "offline",
      prompt: "consent",
      code_challenge: challenge,
      code_challenge_method: "S256",
    });
    if (emailHint) params.set("login_hint", emailHint);

    authWindow = new BrowserWindow({
      width: 520,
      height: 720,
      webPreferences: { nodeIntegration: false, contextIsolation: true },
    });

    authWindow.on("closed", () => {
      authWindow = null;
      server.close();
      finish(new Error("Google oturum penceresi kapatıldı — bağlantı tamamlanmadı"));
    });

    authWindow.loadURL(`${GOOGLE_AUTH}?${params.toString()}`);
  });
}

export function revokeOAuth(accountId: string) {
  const store = loadStore();
  delete store[accountId];
  saveStore(store);
}
