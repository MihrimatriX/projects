import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { jsonError, readJson } from "@/lib/api";

type Params = { params: Promise<{ id: string }> };

export async function GET(_request: Request, { params }: Params) {
  const { id } = await params;
  const highlights = await prisma.highlight.findMany({
    where: { clipId: id },
    orderBy: { createdAt: "asc" },
  });
  return NextResponse.json({
    highlights: highlights.map((h) => ({
      id: h.id,
      text: h.text,
      note: h.note,
      color: h.color,
      createdAt: h.createdAt.toISOString(),
    })),
  });
}

export async function POST(request: Request, { params }: Params) {
  const { id } = await params;
  const body = await readJson(request);
  if (!body) return jsonError("Geçersiz istek gövdesi", 400);
  const text = String(body.text ?? "").trim();
  if (!text) return NextResponse.json({ error: "Metin gerekli" }, { status: 400 });

  const clip = await prisma.clip.findUnique({ where: { id } });
  if (!clip) return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });

  const highlight = await prisma.highlight.create({
    data: {
      clipId: id,
      text: text.slice(0, 5000),
      note: body.note ? String(body.note).slice(0, 2000) : null,
      color: String(body.color ?? "yellow").slice(0, 20),
    },
  });

  return NextResponse.json(
    {
      highlight: {
        id: highlight.id,
        text: highlight.text,
        note: highlight.note,
        color: highlight.color,
        createdAt: highlight.createdAt.toISOString(),
      },
    },
    { status: 201 }
  );
}
