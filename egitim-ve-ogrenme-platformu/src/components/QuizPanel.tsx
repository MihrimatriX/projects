"use client";

import { useState } from "react";
import { Button } from "./Button";

type QuizQuestion = { question: string; options: string[] };

type Props = {
  courseId: string;
  title: string;
  questions: QuizQuestion[];
  unlocked: boolean;
  onSubmitted?: (percent: number) => void;
};

export function QuizPanel({ courseId, title, questions, unlocked, onSubmitted }: Props) {
  const [answers, setAnswers] = useState<number[]>(() => new Array(questions.length).fill(-1));
  const [result, setResult] = useState<{ score: number; total: number; percent: number; correct?: boolean[] } | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  // Kilit mesaji prop'tan turetilir: dersler bu panel acikken bitse de guncel kalir.
  const message =
    feedback ?? (unlocked ? "Quiz açıldı. Tüm soruları yanıtlayıp gönder." : "Quiz kilitli. Önce tüm dersleri tamamla.");

  function selectAnswer(qIndex: number, optionIndex: number) {
    setAnswers((prev) => {
      const next = [...prev];
      next[qIndex] = optionIndex;
      return next;
    });
    setResult(null);
    setFeedback(null);
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!unlocked) return;
    if (answers.some((a) => a < 0)) {
      setFeedback("Devam etmek için tüm soruları yanıtla.");
      return;
    }
    setSubmitting(true);
    try {
      const res = await fetch(`/api/courses/${courseId}/quiz/submit`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ answers }),
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok) {
        setResult({ score: data.score, total: data.total, percent: data.percent, correct: data.correct });
        setFeedback(`Sonuç: ${data.score}/${data.total} (%${data.percent})`);
        onSubmitted?.(data.percent);
      } else {
        setFeedback(data.error ?? `Gönderilemedi (HTTP ${res.status}).`);
      }
    } catch {
      setFeedback("Sunucuya ulaşılamadı. Tekrar dene.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <section className="rounded-[var(--card-radius)] border border-border bg-bg-card p-[18px] shadow-[var(--shadow-sm)]" aria-labelledby="quiz-title">
      <h2 id="quiz-title" className="mb-2.5 text-lg leading-tight tracking-tight">
        {title}
      </h2>
      <form onSubmit={handleSubmit}>
        {questions.map((q, qi) => (
          <fieldset key={qi} disabled={!unlocked || submitting} className="mb-4 border-0 p-0">
            <legend className="mb-3 text-[15px] font-semibold leading-snug">
              {qi + 1}. {q.question}
            </legend>
            <div className="grid gap-2.5">
              {q.options.map((opt, oi) => {
                const checked = answers[qi] === oi;
                // Yalnizca yanlis secilen sik kirmizi; once tum secimler (dogrular dahil) kirmiziya boyaniyordu
                const wrong = checked && result?.correct?.[qi] === false;
                return (
                  <label
                    key={oi}
                    className={`grid cursor-pointer grid-cols-[20px_minmax(0,1fr)] items-start gap-2.5 rounded-[var(--card-radius)] border bg-bg-card p-3.5 transition ${
                      wrong
                        ? "border-danger bg-[color-mix(in_oklch,var(--danger),white_90%)] shadow-[inset_0_0_0_1px_var(--danger)]"
                        : checked
                          ? "border-accent bg-[color-mix(in_oklch,var(--accent),white_90%)] shadow-[inset_0_0_0_1px_var(--accent)]"
                          : "border-border hover:border-[color-mix(in_oklch,var(--text-secondary),var(--border)_64%)]"
                    }`}
                  >
                    <input
                      type="radio"
                      name={`q-${qi}`}
                      checked={checked}
                      onChange={() => selectAnswer(qi, oi)}
                      className="mt-0.5 accent-accent"
                    />
                    <span className="text-sm">
                      {opt}
                      {wrong && <strong className="ml-2 text-xs text-danger">Yanlış</strong>}
                    </span>
                  </label>
                );
              })}
            </div>
          </fieldset>
        ))}
        <p
          className={`min-h-8 text-sm font-semibold ${result ? (result.percent >= 66 ? "text-[color-mix(in_oklch,var(--success),black_20%)]" : "text-[color-mix(in_oklch,var(--danger),black_12%)]") : "text-text-secondary"}`}
          role="status"
        >
          {message}
        </p>
        <Button type="submit" disabled={!unlocked || submitting}>
          {submitting ? "Gönderiliyor…" : "Cevabı gönder"}
        </Button>
      </form>
    </section>
  );
}
