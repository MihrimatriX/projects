import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { ensureSeed } from "@/lib/seed";

export async function GET() {
  await ensureSeed();

  const courses = await prisma.course.findMany({
    include: { lessons: { orderBy: { order: "asc" }, include: { progress: true } }, quiz: true },
    orderBy: { createdAt: "asc" },
  });

  const mapped = courses.map((c) => {
    const total = c.lessons.length;
    const done = c.lessons.filter((l) => l.progress[0]?.completed).length;
    return {
      id: c.id,
      title: c.title,
      description: c.description,
      lessons: total,
      progress: total ? Math.round((done / total) * 100) : 0,
      hasQuiz: Boolean(c.quiz),
    };
  });

  return NextResponse.json({ courses: mapped });
}

export async function POST() {
  await ensureSeed();
  return NextResponse.json({ ok: true });
}
