import { NextResponse } from "next/server";
import { Prisma } from "@prisma/client";
import { cleanName, isSnapshotJson } from "@/lib/board-utils";
import { prisma } from "@/lib/prisma";

type Params = { params: Promise<{ id: string }> };

const notFound = () => NextResponse.json({ error: "Bulunamadı" }, { status: 404 });
const badRequest = (error: string) => NextResponse.json({ error }, { status: 400 });

function isMissing(err: unknown) {
  return err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2025";
}

export async function GET(_request: Request, { params }: Params) {
  const { id } = await params;
  const board = await prisma.board.findUnique({ where: { id } });
  if (!board) return notFound();
  return NextResponse.json({ board });
}

export async function PATCH(request: Request, { params }: Params) {
  const { id } = await params;
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object") return badRequest("Geçersiz istek gövdesi");
  const data: { name?: string; data?: string } = {};
  if (body.name !== undefined) {
    const name = cleanName(body.name);
    if (!name) return badRequest("Pano adı boş olamaz");
    data.name = name;
  }
  if (body.data !== undefined) {
    if (!isSnapshotJson(body.data)) return badRequest("Tuval verisi geçerli bir JSON nesnesi değil");
    data.data = body.data;
  }
  try {
    const board = await prisma.board.update({ where: { id }, data, select: { id: true, name: true, updatedAt: true } });
    return NextResponse.json({ board });
  } catch (err) {
    if (isMissing(err)) return notFound();
    throw err;
  }
}

export async function DELETE(_request: Request, { params }: Params) {
  const { id } = await params;
  try {
    await prisma.board.delete({ where: { id } });
  } catch (err) {
    if (isMissing(err)) return notFound();
    throw err;
  }
  return NextResponse.json({ ok: true });
}
