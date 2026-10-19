import fs from "fs";
import os from "os";
import path from "path";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { state } from "./electronMock";
import { startFakeSmtp, type FakeSmtp } from "./fakeSmtp";

vi.mock("electron", () => import("./electronMock"));

const { sendViaSmtp, verifySmtp } = await import("../electron/smtpService");

let smtp: FakeSmtp;
const account = (pass: string) => ({
  id: "a1",
  server: "127.0.0.1",
  email: "ben@test.local",
  displayName: "Ben",
  smtpServer: "127.0.0.1",
  smtpPort: 0,
  password: pass,
});

beforeAll(async () => {
  state.userData = fs.mkdtempSync(path.join(os.tmpdir(), "mail-smtp-"));
  smtp = await startFakeSmtp("ben@test.local", "dogru-sifre");
});
afterAll(async () => {
  await smtp.close();
  fs.rmSync(state.userData, { recursive: true, force: true });
});

describe("SMTP (yerel sahte sunucu)", () => {
  it("mesajı kimlik doğrulayarak gönderir; konu, alıcı, ek ve okundu notu iletilir", async () => {
    const attach = path.join(state.userData, "not.txt");
    fs.writeFileSync(attach, "ek icerigi");
    await sendViaSmtp(
      { ...account("dogru-sifre"), smtpPort: smtp.port },
      {
        to: "alici@test.local",
        subject: "Deneme konusu",
        body: "Merhaba dunya",
        attachments: [{ name: "not.txt", path: attach }],
        requestReadReceipt: true,
      }
    );
    expect(smtp.mails).toHaveLength(1);
    const raw = smtp.mails[0];
    expect(raw).toContain("Subject: Deneme konusu");
    expect(raw).toContain("To: alici@test.local");
    expect(raw).toContain("Merhaba dunya");
    expect(raw).toContain('filename=not.txt');
    expect(raw).toContain("Okundu bildirimi");
  });

  it("bağlantı testi doğru şifrede OK, yanlış şifrede hata döner (mesaj göndermeden)", async () => {
    const before = smtp.mails.length;
    expect(await verifySmtp({ ...account("dogru-sifre"), smtpPort: smtp.port })).toMatchObject({ ok: true });
    const bad = await verifySmtp({ ...account("yanlis"), smtpPort: smtp.port });
    expect(bad.ok).toBe(false);
    expect(bad.message).toMatch(/^SMTP:/);
    expect(smtp.mails.length).toBe(before);
  });

  it("yanlış şifreyle gönderim hata fırlatır", async () => {
    await expect(
      sendViaSmtp({ ...account("yanlis"), smtpPort: smtp.port }, { to: "x@test.local", subject: "s", body: "b" })
    ).rejects.toThrow();
  });
});
