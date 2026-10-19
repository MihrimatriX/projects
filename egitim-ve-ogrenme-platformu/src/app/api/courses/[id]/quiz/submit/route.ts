import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { parseQuizQuestions, percent, scoreQuiz, validateAnswers } from "@/lib/quiz";

type Params = { params: Promise<{ id: string }> };

export async function POST(request: Request, { params }: Params) {
  const { id: courseId } = await params;
  const body = await request.json().catch(() => null);

  const quiz = await prisma.quiz.findUnique({ where: { courseId } });
  if (!quiz) {
    return NextResponse.json({ error: "Quiz bulunamadı" }, { status: 404 });
  }

  // Quiz kilidi sunucuda da uygulanir: tamamlanmamis ders varsa deneme kaydedilmez.
  const lessons = await prisma.lesson.findMany({ where: { courseId }, include: { progress: true } });
  if (lessons.some((l) => !l.progress[0]?.completed)) {
    return NextResponse.json({ error: "Quiz için önce tüm dersleri tamamla." }, { status: 403 });
  }

  const questions = parseQuizQuestions(quiz.questions);
  const answers = body?.answers;
  const invalid = validateAnswers(questions, answers);
  if (invalid) return NextResponse.json({ error: invalid }, { status: 400 });

  const { score, total } = scoreQuiz(questions, answers);
  const attempt = await prisma.quizAttempt.create({
    data: { quizId: quiz.id, score, total, answers: JSON.stringify(answers) },
  });

  // Soru bazli dogru/yanlis: arayuz yalnizca yanlis secimi isaretler (dogru sik yine gonderilmez).
  const correct = questions.map((q, i) => answers[i] === q.correctIndex);
  return NextResponse.json({ score, total, percent: percent(score, total), correct, attemptId: attempt.id });
}
