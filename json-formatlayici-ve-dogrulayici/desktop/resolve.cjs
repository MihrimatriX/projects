// app://local/<yol> isteklerini Next.js statik export (out/) dosyalarina eslestirir.
const fs = require("node:fs");
const path = require("node:path");

function isFile(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

/** Dosya yolu dondurur; bulunamazsa ya da kok disina cikiyorsa null. */
function resolveStaticFile(root, urlPath) {
  let rel;
  try {
    rel = decodeURIComponent(urlPath.split(/[?#]/)[0]);
  } catch {
    return null;
  }
  const base = path.resolve(root);
  const target = path.resolve(base, "." + path.posix.normalize("/" + rel));
  if (target !== base && !target.startsWith(base + path.sep)) return null;
  for (const candidate of [target, target + ".html", path.join(target, "index.html")]) {
    if (isFile(candidate)) return candidate;
  }
  return null;
}

module.exports = { resolveStaticFile };
