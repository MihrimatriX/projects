// Prisma semasiyla bos bir SQLite dosyasi olusturur (prisma/dev.db'ye dokunmaz).
// Kullanim: node scripts/create-db.mjs <hedef.db>  — testler ve publish.ps1 (sablon db) kullanir.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/** @param {string} file */
export function createDb(file) {
  const target = path.resolve(file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  for (const f of [target, `${target}-journal`]) fs.rmSync(f, { force: true });

  // Semadan SQL uret (Prisma CLI), sonra Node'un yerlesik SQLite'i ile uygula
  const sql = execFileSync(
    process.execPath,
    [
      path.join(root, "node_modules", "prisma", "build", "index.js"),
      "migrate", "diff", "--from-empty", "--to-schema-datamodel", "prisma/schema.prisma", "--script",
    ],
    {
      cwd: root,
      env: { ...process.env, CHECKPOINT_DISABLE: "1", PRISMA_HIDE_UPDATE_MESSAGE: "1" },
      stdio: ["ignore", "pipe", "inherit"],
      encoding: "utf8",
    },
  );
  const db = new DatabaseSync(target);
  try {
    db.exec(sql);
  } finally {
    db.close();
  }
  return target;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (!process.argv[2]) {
    console.error("Kullanim: node scripts/create-db.mjs <hedef.db>");
    process.exit(1);
  }
  console.log(createDb(process.argv[2]));
}
