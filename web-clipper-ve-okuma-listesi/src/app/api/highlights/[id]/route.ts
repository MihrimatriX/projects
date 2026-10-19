import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { isNotFound, jsonError, readJson } from "@/lib/api";

type Params = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, { params }: Params) {
  const { id } = await params;
  const body = await readJson(request);
  if (!body) return jsonError("Geçersiz istek gövdesi", 400);
  const data: Record<string, unknown> = {};
  if (body.note !== undefined) data.note = body.note ? String(body.note).slice(0, 2000) : null;
  if (body.color !== undefined) data.color = String(body.color).slice(0, 20);

  try {
    const highlight = await prisma.highlight.update({ where: { id }, data });
    return NextResponse.json({ highlight });
  } catch (err) {
    if (isNotFound(err)) return jsonError("Bulunamadı", 404);
    throw err;
  }
}

export async function DELETE(_request: Request, { params }: Params) {
  const { id } = await params;
  try {
    await prisma.highlight.delete({ where: { id } });
  } catch (err) {
    if (isNotFound(err)) return jsonError("Bulunamadı", 404);
    throw err;
  }
  return NextResponse.json({ ok: true });
}
