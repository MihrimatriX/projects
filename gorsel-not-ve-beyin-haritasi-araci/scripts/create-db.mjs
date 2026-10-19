// Prisma semasiyla bos bir SQLite dosyasi olusturur (prisma/dev.db'ye dokunmaz).
// Kullanim: node scripts/create-db.mjs <hedef.db>  — testler ve publish.ps1 (sablon db) kullanir.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

/** @param {string} file */
export function createDb(file) {
  const target = path.resolve(file);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  for (const f of [target, `${target}-journal`]) fs.rmSync(f, { force: true });

  const cli = path.join(root, "node_modules", "prisma", "build", "index.js");
  const env = { ...process.env, CHECKPOINT_DISABLE: "1", PRISMA_HIDE_UPDATE_MESSAGE: "1" };
  const run = (/** @type {string[]} */ args) =>
    execFileSync(process.execPath, [cli, ...args], { cwd: root, env, stdio: ["ignore", "pipe", "inherit"] });

  const sqlFile = `${target}.sql`;
  fs.writeFileSync(
    sqlFile,
    run(["migrate", "diff", "--from-empty", "--to-schema-datamodel", "prisma/schema.prisma", "--script"]),
  );
  try {
    run(["db", "execute", "--url", `file:${target.replace(/\\/g, "/")}`, "--file", sqlFile]);
  } finally {
    fs.rmSync(sqlFile, { force: true });
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
