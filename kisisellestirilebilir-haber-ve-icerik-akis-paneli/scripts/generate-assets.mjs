// assets/icon.svg'den PNG/ICO ikonlarini uretir (Playwright Chromium ile; ek arac gerekmez).
// Cikti (gitignore'da): assets/icon.png, assets/app.ico, public/favicon.png, public/apple-touch-icon.png
// Kullanim: node scripts/generate-assets.mjs   (once: npx playwright install chromium)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "@playwright/test";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const svg = fs.readFileSync(path.join(root, "assets", "icon.svg"));
const src = `data:image/svg+xml;base64,${svg.toString("base64")}`;

const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  /** @param {number} size */
  const render = async (size) => {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(
      `<style>html,body{margin:0;background:transparent}</style><img src="${src}" width="${size}" height="${size}">`,
    );
    return page.screenshot({ omitBackground: true });
  };

  const png256 = await render(256);
  fs.writeFileSync(path.join(root, "assets", "icon.png"), png256);
  fs.writeFileSync(path.join(root, "public", "favicon.png"), await render(32));
  fs.writeFileSync(path.join(root, "public", "apple-touch-icon.png"), await render(180));

  // ICO: tek 256x256 PNG girdisi (Windows Vista+ PNG sikistirmali ikonlari destekler)
  const header = Buffer.alloc(22);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // tip: ikon
  header.writeUInt16LE(1, 4); // girdi sayisi
  header.writeUInt8(0, 6); // genislik 256
  header.writeUInt8(0, 7); // yukseklik 256
  header.writeUInt16LE(1, 10); // renk duzlemi
  header.writeUInt16LE(32, 12); // bit/piksel
  header.writeUInt32LE(png256.length, 14);
  header.writeUInt32LE(22, 18); // veri ofseti
  fs.writeFileSync(path.join(root, "assets", "app.ico"), Buffer.concat([header, png256]));
  console.log("Ikonlar uretildi: assets/icon.png, assets/app.ico, public/favicon.png, public/apple-touch-icon.png");
} finally {
  await browser.close();
}
