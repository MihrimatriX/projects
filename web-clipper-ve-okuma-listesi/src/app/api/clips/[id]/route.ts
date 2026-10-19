import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { clipDetailInclude, serializeClip } from "@/lib/clips";
import { scheduleParse } from "@/lib/readability";
import { isNotFound, jsonError, readJson } from "@/lib/api";

type Params = { params: Promise<{ id: string }> };

export async function GET(_request: Request, { params }: Params) {
  const { id } = await params;
  const clip = await prisma.clip.findUnique({ where: { id }, include: clipDetailInclude });
  if (!clip) return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });
  return NextResponse.json({ clip: serializeClip(clip, true) });
}

export async function PATCH(request: Request, { params }: Params) {
  const { id } = await params;
  const body = await readJson(request);
  if (!body) return jsonError("Geçersiz istek gövdesi", 400);
  const data: Record<string, unknown> = {};

  if (body.isRead !== undefined) data.isRead = Boolean(body.isRead);
  if (body.isStarred !== undefined) data.isStarred = Boolean(body.isStarred);
  if (body.title !== undefined) {
    const title = String(body.title).trim();
    if (!title) return jsonError("Başlık boş olamaz", 400);
    data.title = title.slice(0, 500);
  }

  try {
    const clip = await prisma.clip.update({ where: { id }, data, include: clipDetailInclude });
    return NextResponse.json({ clip: serializeClip(clip) });
  } catch (err) {
    if (isNotFound(err)) return jsonError("Bulunamadı", 404);
    throw err;
  }
}

export async function DELETE(_request: Request, { params }: Params) {
  const { id } = await params;
  try {
    await prisma.clip.delete({ where: { id } });
  } catch (err) {
    if (isNotFound(err)) return jsonError("Bulunamadı", 404);
    throw err;
  }
  return NextResponse.json({ ok: true });
}

export async function POST(request: Request, { params }: Params) {
  const { id } = await params;
  const body = await request.json().catch(() => ({}));
  if (body.action !== "reparse") {
    return NextResponse.json({ error: "Geçersiz işlem" }, { status: 400 });
  }

  const clip = await prisma.clip.findUnique({ where: { id } });
  if (!clip) return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });

  await prisma.clip.update({
    where: { id },
    data: { parseStatus: "pending", content: null },
  });
  scheduleParse(id, clip.url);

  return NextResponse.json({ ok: true });
}
