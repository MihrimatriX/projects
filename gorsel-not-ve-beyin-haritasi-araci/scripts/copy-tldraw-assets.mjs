// tldraw ikon/yazi tipi/ceviri dosyalarini public/tldraw-assets altina kopyalar:
// varsayilan CDN (cdn.tldraw.com) yerine yerelden yuklenir, uygulama cevrimdisi da tam calisir.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const src = path.join(root, "node_modules", "@tldraw", "assets");
const dest = path.join(root, "public", "tldraw-assets");

for (const dir of ["fonts", "icons", "translations", "embed-icons"]) {
  fs.cpSync(path.join(src, dir), path.join(dest, dir), { recursive: true });
}
