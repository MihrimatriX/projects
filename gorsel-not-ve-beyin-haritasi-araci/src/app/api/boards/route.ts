import { NextResponse } from "next/server";
import { cleanName, isBoardEmpty, isSnapshotJson } from "@/lib/board-utils";
import { prisma } from "@/lib/prisma";

export async function GET() {
  // Sınır yok: eskiden ilk 50 pano dışındakiler listede hiç görünmüyordu.
  const rows = await prisma.board.findMany({ orderBy: { updatedAt: "desc" } });
  const boards = rows.map(({ id, name, updatedAt, data }) => ({
    id,
    name,
    updatedAt,
    isEmpty: isBoardEmpty(data),
  }));
  return NextResponse.json({ boards });
}

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return NextResponse.json({ error: "Geçersiz istek gövdesi" }, { status: 400 });
  }
  const name = cleanName(body.name) ?? "Yeni pano";
  // İçe aktarma: dosyadan gelen tuval verisi (yoksa boş pano)
  if (body.data !== undefined && !isSnapshotJson(body.data)) {
    return NextResponse.json({ error: "Tuval verisi geçerli bir JSON nesnesi değil" }, { status: 400 });
  }
  const board = await prisma.board.create({ data: { name, data: body.data ?? "{}" } });
  return NextResponse.json({ board }, { status: 201 });
}
