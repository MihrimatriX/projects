import { PrismaLibSql } from "@prisma/adapter-libsql";
import { PrismaClient } from "@prisma/client";

// Prisma 7 .env'i kendisi okumaz. server.ts ve seed bu modulu Next'ten once yukler;
// loadEnvFile ortamda zaten tanimli degiskenleri ezmez (masaustu kabugu / Docker ortamdan verir).
try {
  process.loadEnvFile();
} catch {
  // .env yok
}

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient | undefined };

function createPrismaClient() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL tanımlı değil");
  // libsql N-API modülüdür: aynı ikili hem Node'da hem Electron'un node'unda çalışır
  return new PrismaClient({
    adapter: new PrismaLibSql({ url }),
    log: process.env.NODE_ENV === "development" ? ["error", "warn"] : ["error"],
  });
}

export const prisma = globalForPrisma.prisma ?? createPrismaClient();

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
