import { safeStorage } from "electron";
import fs from "fs";
import path from "path";

// Şifre ve token'lar yalnızca OS güvenli depolamasıyla (Windows: DPAPI) şifrelenip yazılır.
// Şifreleme kullanılamıyorsa düz metne düşmek yerine kaydetme reddedilir.
export function encryptSecret(plain: string): string {
  if (!safeStorage.isEncryptionAvailable()) {
    throw new Error("Güvenli depolama (OS şifreleme) kullanılamıyor — şifre kaydedilmedi");
  }
  return safeStorage.encryptString(plain).toString("base64");
}

export function decryptSecret(b64: string): string | null {
  if (!safeStorage.isEncryptionAvailable()) return null;
  try {
    return safeStorage.decryptString(Buffer.from(b64, "base64"));
  } catch {
    return null; // bozuk / başka kullanıcıya ait kayıt: yalnızca bu girdi atlanır
  }
}

/** { id: base64(şifreli) } biçimindeki dosyayı çözer; çözülemeyen girdiler atlanır. */
export function loadSecretMap(file: string): Record<string, string> {
  let encoded: Record<string, string>;
  try {
    encoded = JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, string>;
  } catch {
    return {};
  }
  const out: Record<string, string> = {};
  for (const [id, b64] of Object.entries(encoded ?? {})) {
    if (typeof b64 !== "string") continue;
    const plain = decryptSecret(b64);
    if (plain !== null) out[id] = plain;
  }
  return out;
}

export function saveSecretMap(file: string, map: Record<string, string>) {
  const encoded: Record<string, string> = {};
  for (const [id, plain] of Object.entries(map)) {
    if (plain) encoded[id] = encryptSecret(plain);
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(encoded, null, 2), "utf8");
}
