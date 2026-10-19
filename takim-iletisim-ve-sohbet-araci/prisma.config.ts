import { defineConfig, env } from "prisma/config";

// Prisma 7 .env dosyasini kendisi okumaz; var olan ortam degiskenleri ezilmez
try {
  process.loadEnvFile();
} catch {
  // .env yok (Docker / masaustu paketi): degiskenler ortamdan gelir
}

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { seed: "tsx prisma/seed.ts" },
  datasource: { url: env("DATABASE_URL") },
});
