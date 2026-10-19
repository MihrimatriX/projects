import { _electron as electron, type ElectronApplication, type Page } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";
import { fileURLToPath } from "url";

export const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));

export type Ctx = {
  app: ElectronApplication;
  page: Page;
  dir: string;
  settings: () => Record<string, unknown>;
  close: () => Promise<void>;
};

/**
 * Derlenmiş uygulamayı geçici veri klasörüyle (EPOSTA_DATA_DIR) açar; gerçek posta kutusuna dokunmaz.
 * `settings` null ise settings.json yazılmaz (ilk açılış / karşılama ekranı).
 */
export async function launch(
  settings: Record<string, unknown> | null = { onboardingDone: true }
): Promise<Ctx> {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mail-ui-"));
  if (settings) {
    fs.writeFileSync(
      path.join(dir, "settings.json"),
      JSON.stringify({
        useIdle: false,
        backgroundSync: false,
        minimizeToTray: false,
        notifyNewMail: false,
        notifyTrackingDue: false,
        ...settings,
      })
    );
  }
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) if (v !== undefined) env[k] = v;
  delete env.VITE_DEV_SERVER_URL;
  env.EPOSTA_DATA_DIR = dir;

  const app = await electron.launch({ args: [root], env, colorScheme: null }); // temayı uygulama belirlesin
  const page = await app.firstWindow();
  await page.waitForSelector(".window");
  return {
    app,
    page,
    dir,
    settings: () => JSON.parse(fs.readFileSync(path.join(dir, "settings.json"), "utf8")),
    close: async () => {
      await app.close();
      fs.rmSync(dir, { recursive: true, force: true });
    },
  };
}

/** Yerel aç/kaydet diyaloglarını ana süreçte sahte yanıtlarla değiştirir (gerçek pencere açılmaz). */
export async function mockDialogs(app: ElectronApplication, open: string[][], save: string[]) {
  await app.evaluate(
    ({ dialog }, { open, save }) => {
      dialog.showOpenDialog = (async () => {
        const p = open.shift();
        return p ? { canceled: false, filePaths: p } : { canceled: true, filePaths: [] };
      }) as typeof dialog.showOpenDialog;
      dialog.showSaveDialog = (async () => {
        const p = save.shift();
        return p ? { canceled: false, filePath: p } : { canceled: true, filePath: "" };
      }) as typeof dialog.showSaveDialog;
    },
    { open, save }
  );
}

const day = 86400000;
const ago = (ms: number) => new Date(Date.now() - ms).toISOString();

/** Örnek posta kutusu (kurgusal kişiler, @ornek.com adresleri). */
export function demoBackup() {
  const base = { accountId: "local", read: true, starred: false, archived: false };
  const messages = [
    {
      ...base, id: "d1", folder: "inbox", read: false, date: ago(20 * 60000),
      from: "Elif Kaya <elif.kaya@ornek.com>", to: "ben@ornek.com",
      subject: "Sprint 14 planlama toplantısı",
      body: "Merhaba,\n\nYarın 10:00'daki planlama toplantısı için gündem ekte. Tahminleri cuma gününe kadar tamamlayabilir miyiz?\n\nElif",
      attachments: [{ name: "gundem.pdf", size: 48213 }],
    },
    {
      ...base, id: "d2", folder: "inbox", read: false, starred: true, date: ago(2 * 3600000),
      from: "Mert Demir <mert.demir@ornek.com>", to: "ben@ornek.com",
      subject: "Fatura #2026-118 onayı",
      body: "Ekteki faturayı onaylarsanız ödeme talimatını bugün veriyorum.",
      bodyHtml: "<h3 style='margin:0 0 8px'>Fatura #2026-118</h3><p>Ekteki faturayı onaylarsanız ödeme talimatını <b>bugün</b> veriyorum.</p><table border='1' cellpadding='6' style='border-collapse:collapse'><tr><td>Danışmanlık (Eylül)</td><td>12.500 TL</td></tr><tr><td>KDV</td><td>2.500 TL</td></tr></table><img src='https://izleme.ornek.com/pixel.gif' alt=''>",
    },
    {
      ...base, id: "d3", folder: "inbox", date: ago(5 * 3600000),
      from: "Zeynep Arslan <zeynep@ornek.com>", to: "ben@ornek.com",
      subject: "Tasarım geri bildirimi",
      body: "Yeni ana sayfa taslağına baktım; renk paleti çok iyi ama mobil menü biraz kalabalık.",
    },
    {
      ...base, id: "d4", folder: "inbox", date: ago(day + 3600000),
      from: "Can Yıldız <can@ornek.com>", to: "ben@ornek.com",
      subject: "Kod incelemesi: ödeme modülü",
      body: "PR #482'ye yorumlarımı bıraktım, iki küçük düzeltme dışında onaylıyorum.",
    },
    {
      ...base, id: "d5", folder: "inbox", read: false, date: ago(2 * day),
      from: "Bülten <bulten@ornek.com>", to: "ben@ornek.com",
      subject: "Haftalık teknoloji bülteni",
      body: "Bu hafta: yerel-öncelikli uygulamalar, SQLite ipuçları ve Electron güvenlik kontrol listesi.",
    },
    {
      ...base, id: "d6", folder: "inbox", date: ago(3 * day),
      from: "Ayşe Çelik <ayse@ornek.com>", to: "ben@ornek.com",
      subject: "Kahve molası?",
      body: "Perşembe öğleden sonra müsait misin?",
    },
    {
      ...base, id: "s1", folder: "sent", date: ago(4 * day),
      from: "ben@ornek.com", to: "deniz@ornek.com",
      subject: "Teklif dosyası",
      body: "Merhaba Deniz, teklif dosyasını ekte bulabilirsin. Dönüşünü bekliyorum.",
      tracking: { waitingReply: true, startedAt: ago(4 * day), reminderDays: 3 },
    },
    {
      ...base, id: "s2", folder: "sent", date: ago(day),
      from: "ben@ornek.com", to: "elif.kaya@ornek.com",
      subject: "Re: Sprint 13 retrospektif",
      body: "Notlar için teşekkürler!",
    },
    {
      ...base, id: "dr1", folder: "drafts", date: ago(6 * 3600000),
      from: "ben@ornek.com", to: "can@ornek.com",
      subject: "Yıllık izin planı",
      body: "Merhaba Can,\n\nAralık ayının son haftası için",
    },
    {
      ...base, id: "a1", folder: "inbox", archived: true, date: ago(10 * day),
      from: "İK <ik@ornek.com>", to: "ben@ornek.com",
      subject: "Bordro bilgilendirmesi",
      body: "Eylül bordroları sisteme yüklendi.",
    },
    {
      ...base, id: "t1", folder: "trash", date: ago(12 * day), remote: true,
      from: "Kampanya <kampanya@ornek.com>", to: "ben@ornek.com",
      subject: "Son gün indirimi",
      body: "Kaçırmayın!",
    },
  ];
  const templates = [
    { id: "thanks", name: "Teşekkür", subject: "Re: {konu}", body: "Merhaba {ad},\n\nTeşekkürler, aldım.\n" },
  ];
  return { exportedAt: new Date().toISOString(), messages, templates };
}

/** Örnek yedeği uygulamaya "İçe aktar" düğmesiyle (sahte aç diyaloğu) yükler. */
export async function importDemo(ctx: Ctx) {
  const file = path.join(ctx.dir, "demo-yedek.json");
  fs.writeFileSync(file, JSON.stringify(demoBackup()));
  await mockDialogs(ctx.app, [[file]], []);
  const { page } = ctx;
  await page.getByRole("button", { name: "Ayarlar", exact: true }).click();
  const dlg = page.getByRole("dialog", { name: "Ayarlar" });
  await dlg.getByRole("button", { name: "İçe aktar" }).click();
  await dlg.getByText("11 mesaj içe aktarıldı").waitFor();
  await dlg.getByRole("button", { name: "Kapat" }).click();
}
