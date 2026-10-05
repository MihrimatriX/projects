import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

type Params = { params: Promise<{ id: string }> };

// Kursu bastan almak icin ders ilerlemesini sifirlar; quiz denemeleri gecmis olarak kalir.
export async function POST(_request: Request, { params }: Params) {
  const { id } = await params;
  const course = await prisma.course.findUnique({ where: { id } });
  if (!course) return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });
  await prisma.progress.updateMany({ where: { lesson: { courseId: id } }, data: { completed: false } });
  return NextResponse.json({ ok: true });
}
