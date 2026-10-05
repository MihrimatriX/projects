import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { state } from "./electronMock";

vi.mock("electron", () => import("./electronMock"));

const { listAccounts, listAccountsForUi, saveAccounts, getAccount } = await import("../electron/accounts");
const { loadSecretMap, saveSecretMap } = await import("../electron/secretStore");

const SECRET = "Cok-Gizli-Sifre-42!";
const acc = (id: string) => ({ id, server: "imap.test", email: `${id}@test`, displayName: id });

function allFilesText(dir: string) {
  return fs
    .readdirSync(dir)
    .map((f) => fs.readFileSync(path.join(dir, f)))
    .map((b) => b.toString("utf8") + b.toString("latin1"))
    .join("\n");
}

describe("kimlik bilgisi depolama (safeStorage)", () => {
  beforeEach(() => {
    state.userData = fs.mkdtempSync(path.join(os.tmpdir(), "mail-cred-"));
    state.encryptionAvailable = true;
  });
  afterEach(() => fs.rmSync(state.userData, { recursive: true, force: true }));

  it("şifre diske düz metin (veya düz base64) yazılmaz, geri okunabilir", () => {
    saveAccounts([{ ...acc("a1"), password: SECRET }], "a1");
    const text = allFilesText(state.userData);
    expect(text).not.toContain(SECRET);
    expect(text).not.toContain(Buffer.from(SECRET).toString("base64"));
    expect(JSON.parse(fs.readFileSync(path.join(state.userData, "accounts.json"), "utf8"))[0]).not.toHaveProperty(
      "password"
    );
    expect(getAccount("a1")?.password).toBe(SECRET);
  });

  it("arayüz listesi şifreyi içermez, yalnızca hasPassword bildirir", () => {
    saveAccounts([{ ...acc("a1"), password: SECRET }, acc("a2")]);
    const ui = listAccountsForUi();
    expect(JSON.stringify(ui)).not.toContain(SECRET);
    expect(ui.map((a) => a.hasPassword)).toEqual([true, false]);
  });

  it("boş bırakılan şifre korunur, '' siler, kaldırılan hesabın şifresi silinir", () => {
    saveAccounts([{ ...acc("a1"), password: SECRET }, { ...acc("a2"), password: "ikinci" }]);
    saveAccounts([acc("a1"), { ...acc("a2"), password: "" }]);
    expect(listAccounts().map((a) => a.password)).toEqual([SECRET, ""]);
    saveAccounts([acc("a2")]);
    expect(Object.keys(loadSecretMap(path.join(state.userData, "credentials.json")))).toEqual([]);
  });

  it("güvenli depolama yoksa kaydetmeyi reddeder ve hiçbir şey yazmaz", () => {
    state.encryptionAvailable = false;
    expect(() => saveAccounts([{ ...acc("a1"), password: SECRET }])).toThrow(/Güvenli depolama/);
    expect(fs.existsSync(path.join(state.userData, "accounts.json"))).toBe(false);
    expect(allFilesText(state.userData)).not.toContain(SECRET);
  });

  it("çözülemeyen tek kayıt diğer şifreleri silmez", () => {
    const file = path.join(state.userData, "credentials.json");
    saveSecretMap(file, { a1: SECRET });
    const raw = JSON.parse(fs.readFileSync(file, "utf8"));
    raw.bozuk = Buffer.from("rastgele").toString("base64");
    fs.writeFileSync(file, JSON.stringify(raw));
    expect(loadSecretMap(file)).toEqual({ a1: SECRET });
  });

  it("eski düz metin account.json taşınır ve silinir", () => {
    fs.writeFileSync(
      path.join(state.userData, "account.json"),
      JSON.stringify({ server: "imap.eski", email: "eski@test", displayName: "Eski", password: SECRET })
    );
    expect(listAccounts()[0]).toMatchObject({ id: "acc-default", email: "eski@test", password: SECRET });
    expect(fs.existsSync(path.join(state.userData, "account.json"))).toBe(false);
    expect(allFilesText(state.userData)).not.toContain(SECRET);
  });
});
