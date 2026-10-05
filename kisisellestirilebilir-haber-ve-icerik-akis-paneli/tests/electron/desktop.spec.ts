import { _electron as electron, expect, test } from "@playwright/test";
import fs from "node:fs";
import type { AddressInfo } from "node:net";
import os from "node:os";
import path from "node:path";
import http from "node:http";

test("masaustu surumu acilir, varsayilan feed'i yerel fiksturden yukler, veriyi ayri klasorde tutar", async () => {
  // DESKTOP_EXE verilirse paketlenmis exe (dist\...) test edilir, yoksa desktop\ kabugu + stage\.
  const exe = process.env.DESKTOP_EXE;
  const desktop = path.join(__dirname, "..", "..", "desktop");
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "haber-e2e-"));
  // Playwright test yukleyicisi .mjs ESM fikstur sunucusunu yukleyemedigi icin burada kucuk bir sunucu acilir
  const xml = fs.readFileSync(path.join(__dirname, "..", "fixtures", "teknoloji.xml"));
  const fixtures = http.createServer((_, res) => res.writeHead(200, { "Content-Type": "application/xml" }).end(xml));
  await new Promise<void>((r) => fixtures.listen(0, "127.0.0.1", r));
  const feedUrl = `http://127.0.0.1:${(fixtures.address() as AddressInfo).port}/teknoloji.xml`;

  const app = await electron.launch({
    ...(exe
      ? { executablePath: exe }
      : { executablePath: path.join(desktop, "node_modules", "electron", "dist", "electron.exe"), args: [desktop] }),
    env: {
      ...process.env,
      APP_DATA_DIR: dataDir,
      RSS_ALLOW_PRIVATE_HOSTS: "1",
      DEFAULT_FEEDS: JSON.stringify([{ url: feedUrl, folder: "Teknoloji", title: "Yerel Teknoloji" }]),
    },
  });
  try {
    const page = await app.firstWindow();
    await expect(page.getByRole("complementary", { name: "Feed listesi" }).getByText("Yerel Teknoloji")).toBeVisible({
      timeout: 60_000,
    });
    await page.getByRole("option", { name: /Yapay zeka çipleri/ }).click();
    await expect(page.getByRole("heading", { name: "Yapay zeka çipleri yerelleşiyor" })).toBeVisible();
    expect(fs.existsSync(path.join(dataDir, "haber.db"))).toBe(true);
  } finally {
    await app.close();
    await new Promise((r) => fixtures.close(r));
    fs.rmSync(dataDir, { recursive: true, force: true, maxRetries: 10, retryDelay: 300 });
  }
});
