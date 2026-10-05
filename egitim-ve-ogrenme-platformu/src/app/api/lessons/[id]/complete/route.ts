import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

type Params = { params: Promise<{ id: string }> };

export async function POST(_request: Request, { params }: Params) {
  const { id } = await params;
  const lesson = await prisma.lesson.findUnique({ where: { id } });
  if (!lesson) return NextResponse.json({ error: "Ders bulunamadı" }, { status: 404 });
  await prisma.progress.upsert({
    where: { lessonId: id },
    create: { lessonId: id, completed: true },
    update: { completed: true },
  });
  return NextResponse.json({ ok: true });
}
