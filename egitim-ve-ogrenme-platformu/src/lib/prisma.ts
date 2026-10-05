import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient | undefined };

// DATABASE_URL verilirse (testler, masaustu surumu) o dosya kullanilir; yoksa semadaki prisma/dev.db.
const url = process.env.DATABASE_URL;

export const prisma =
  globalForPrisma.prisma ?? new PrismaClient(url ? { datasources: { db: { url } } } : undefined);

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = prisma;
