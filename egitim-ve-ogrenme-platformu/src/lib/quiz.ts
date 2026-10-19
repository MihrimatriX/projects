export type QuizQuestion = {
  question: string;
  options: string[];
  correctIndex: number;
};

export function parseQuizQuestions(json: string): QuizQuestion[] {
  try {
    const data = JSON.parse(json) as QuizQuestion[];
    if (!Array.isArray(data)) return [];
    return data.filter(
      (q) =>
        typeof q.question === "string" &&
        Array.isArray(q.options) &&
        typeof q.correctIndex === "number"
    );
  } catch {
    return [];
  }
}

/** Gonderilen cevaplar her soru icin gecerli bir secenek mi? Hata mesaji ya da null doner. */
export function validateAnswers(questions: QuizQuestion[], answers: unknown): string | null {
  if (!Array.isArray(answers) || answers.length !== questions.length) {
    return "Tüm soruları yanıtla.";
  }
  const ok = answers.every(
    (a, i) => Number.isInteger(a) && a >= 0 && a < questions[i].options.length
  );
  return ok ? null : "Geçersiz cevap seçimi.";
}

export function scoreQuiz(
  questions: QuizQuestion[],
  answers: number[]
): { score: number; total: number } {
  const total = questions.length;
  let score = 0;
  questions.forEach((q, i) => {
    if (answers[i] === q.correctIndex) score++;
  });
  return { score, total };
}

export function percent(score: number, total: number): number {
  return total ? Math.round((score / total) * 100) : 0;
}
