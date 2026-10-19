import { app } from "electron";
import fs from "fs";
import path from "path";
import { decryptSecret, loadSecretMap, saveSecretMap } from "./secretStore";
import { PROVIDER_PRESETS, type Account, type ProviderPreset } from "./types";

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

function credPath() {
  return dataPath("credentials.json");
}

function loadCredentialMap(): Record<string, string> {
  if (!fs.existsSync(credPath())) return migrateLegacyCredential();
  return loadSecretMap(credPath());
}

function migrateLegacyCredential(): Record<string, string> {
  try {
    const encoded = fs.readFileSync(dataPath("credentials.bin"));
    const password = decryptSecret(encoded.toString("base64"));
    if (!password) return {};
    const accounts = listAccountsRaw();
    const id = accounts[0]?.id ?? "default";
    saveCredentialMap({ [id]: password });
    try {
      fs.unlinkSync(dataPath("credentials.bin"));
    } catch {
      /* ignore */
    }
    return { [id]: password };
  } catch {
    return {};
  }
}

function saveCredentialMap(map: Record<string, string>) {
  saveSecretMap(credPath(), map);
}

function listAccountsRaw(): Account[] {
  migrateLegacyAccount();
  return loadJson<Account[]>("accounts.json", []);
}

function migrateLegacyAccount() {
  if (fs.existsSync(dataPath("accounts.json"))) return;
  try {
    const legacy = loadJson<Account & { password?: string }>("account.json", {
      server: "",
      email: "",
      displayName: "",
    } as Account & { password?: string });
    if (!legacy.email && !legacy.server) {
      saveJson("accounts.json", []);
      return;
    }
    const id = "acc-default";
    const account: Account = {
      id,
      server: legacy.server,
      email: legacy.email,
      displayName: legacy.displayName,
      imapPort: legacy.imapPort,
      smtpServer: legacy.smtpServer,
      smtpPort: legacy.smtpPort,
      provider: "custom",
    };
    saveJson("accounts.json", [account]);
    if (legacy.password) {
      const creds = loadCredentialMap();
      creds[id] = legacy.password;
      saveCredentialMap(creds);
    }
    // Eski sürümün düz metin şifre içeren dosyası taşındıktan sonra silinir.
    fs.rmSync(dataPath("account.json"), { force: true });
  } catch {
    saveJson("accounts.json", []);
  }
}

export function listAccounts(): (Account & { password?: string })[] {
  const accounts = listAccountsRaw(); // önce: eski account.json taşınırken şifre de taşınır
  const creds = loadCredentialMap();
  return accounts.map((a) => ({
    ...a,
    password: creds[a.id] ?? "",
  }));
}

/** Arayüze giden liste: şifre renderer'a hiç gönderilmez, yalnızca kayıtlı olup olmadığı bildirilir. */
export function listAccountsForUi(): (Account & { hasPassword: boolean })[] {
  return listAccounts().map(({ password, ...rest }) => ({ ...rest, hasPassword: Boolean(password) }));
}

export function getActiveAccountId(): string | undefined {
  return loadJson<{ activeId?: string }>("active-account.json", {}).activeId;
}

export function getAccount(id?: string): (Account & { password?: string }) | null {
  const accounts = listAccounts();
  if (accounts.length === 0) return null;
  if (id) return accounts.find((a) => a.id === id) ?? null;
  const activeId = getActiveAccountId();
  return accounts.find((a) => a.id === activeId) ?? accounts[0];
}

/**
 * password: undefined → kayıtlı şifre korunur, "" → silinir, dolu → değiştirilir.
 * Listeden kaldırılan hesapların şifreleri de silinir.
 */
export function saveAccounts(
  accounts: (Account & { password?: string; hasPassword?: boolean })[],
  activeId?: string
) {
  const old = loadCredentialMap();
  const creds: Record<string, string> = {};
  const stored: Account[] = accounts.map(({ password, hasPassword: _h, ...rest }) => {
    if (password) creds[rest.id] = password;
    else if (password === undefined && old[rest.id]) creds[rest.id] = old[rest.id];
    return rest;
  });
  // Önce şifreler: güvenli depolama yoksa hata fırlatır ve hesap listesi de değişmez.
  saveCredentialMap(creds);
  saveJson("accounts.json", stored);
  if (activeId) saveJson("active-account.json", { activeId });
  return listAccountsForUi();
}

export function applyProviderPreset(provider: ProviderPreset): Partial<Account> {
  if (provider === "custom") return { provider };
  return { ...PROVIDER_PRESETS[provider], provider };
}

export function createAccountId() {
  return `acc-${Date.now()}`;
}
