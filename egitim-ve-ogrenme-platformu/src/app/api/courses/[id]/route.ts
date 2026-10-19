import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { parseQuizQuestions, percent } from "@/lib/quiz";

type Params = { params: Promise<{ id: string }> };

export async function GET(_request: Request, { params }: Params) {
  const { id } = await params;
  const course = await prisma.course.findUnique({
    where: { id },
    include: {
      lessons: { orderBy: { order: "asc" }, include: { progress: true } },
      quiz: { include: { attempts: { orderBy: { createdAt: "desc" } } } },
    },
  });
  if (!course) return NextResponse.json({ error: "Bulunamadı" }, { status: 404 });

  // Doğru cevaplar (correctIndex) istemciye gönderilmez; puanlama /quiz/submit içinde sunucuda yapılır.
  const { quiz, ...rest } = course;
  const safeQuiz = quiz
    ? {
        id: quiz.id,
        title: quiz.title,
        questions: parseQuizQuestions(quiz.questions).map((q) => ({
          question: q.question,
          options: q.options,
        })),
        attempts: quiz.attempts.slice(0, 5).map((a) => ({
          score: a.score,
          total: a.total,
          createdAt: a.createdAt,
        })),
        bestPercent: quiz.attempts.length
          ? Math.max(...quiz.attempts.map((a) => percent(a.score, a.total)))
          : null,
      }
    : null;

  return NextResponse.json({ course: { ...rest, quiz: safeQuiz } });
}
