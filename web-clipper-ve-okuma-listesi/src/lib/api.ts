import { NextResponse } from "next/server";
import { Prisma } from "@prisma/client";

/** İstek gövdesini JSON nesnesi olarak okur; bozuk/boş gövdede null (500 yerine 400 dönmek için). */
export async function readJson(request: Request): Promise<Record<string, unknown> | null> {
  const body: unknown = await request.json().catch(() => null);
  return body && typeof body === "object" && !Array.isArray(body) ? (body as Record<string, unknown>) : null;
}

export function jsonError(error: string, status: number) {
  return NextResponse.json({ error }, { status });
}

/** Silinmiş / hiç olmayan kayıt üzerinde update/delete (Prisma P2025) → 404. */
export function isNotFound(err: unknown): boolean {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2025";
}

export function errorMessage(err: unknown, fallback: string): string {
  return err instanceof Error && err.message ? err.message : fallback;
}
