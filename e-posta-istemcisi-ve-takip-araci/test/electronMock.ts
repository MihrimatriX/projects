// vitest için "electron" modülünün yerine geçen sahte: userData geçici klasör, safeStorage geri çevrilebilir sahte şifreleme.
export const state = { userData: "", encryptionAvailable: true };

const MAGIC = "FAKEDPAPI:";
const xor = (buf: Buffer) => Buffer.from(buf.map((b) => b ^ 0x5a));

export const safeStorage = {
  isEncryptionAvailable: () => state.encryptionAvailable,
  encryptString: (plain: string) => Buffer.concat([Buffer.from(MAGIC), xor(Buffer.from(plain, "utf8"))]),
  decryptString: (buf: Buffer) => {
    if (!buf.subarray(0, MAGIC.length).equals(Buffer.from(MAGIC))) throw new Error("decrypt failed");
    return xor(buf.subarray(MAGIC.length)).toString("utf8");
  },
};

export const app = { getPath: () => state.userData };
export class BrowserWindow {
  static getAllWindows() {
    return [];
  }
}
export class Notification {
  static isSupported() {
    return false;
  }
}
