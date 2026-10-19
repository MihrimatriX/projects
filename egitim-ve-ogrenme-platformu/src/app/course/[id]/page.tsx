"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { SiteHeader } from "@/components/SiteHeader";
import { Button, LinkButton } from "@/components/Button";
import { QuizPanel } from "@/components/QuizPanel";
import { courseCover } from "@/lib/covers";

type QuizQuestion = { question: string; options: string[] };
type Attempt = { score: number; total: number; createdAt: string };
type Quiz = {
  id: string;
  title: string;
  questions: QuizQuestion[];
  attempts: Attempt[];
  bestPercent: number | null;
};
type Lesson = {
  id: string;
  title: string;
  content: string;
  order: number;
  progress: { completed: boolean }[];
};
type Course = {
  id: string;
  title: string;
  description: string;
  lessons: Lesson[];
  quiz: Quiz | null;
};

type View = "lesson" | "quiz";

export default function CoursePage() {
  const params = useParams<{ id: string }>();
  const [course, setCourse] = useState<Course | null>(null);
  const [activeLesson, setActiveLesson] = useState<Lesson | null>(null);
  const [view, setView] = useState<View>("lesson");
  const [playing, setPlaying] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [progressPct, setProgressPct] = useState(0);

  const load = useCallback(async () => {
    const res = await fetch(`/api/courses/${params.id}`);
    if (!res.ok) {
      setLoadError(res.status === 404 ? "Kurs bulunamadı." : `Kurs yüklenemedi (HTTP ${res.status}).`);
      return;
    }
    setLoadError(null);
    const data = await res.json();
    setCourse(data.course);
    const done = data.course.lessons.filter((l: Lesson) => l.progress[0]?.completed).length;
    const total = data.course.lessons.length;
    setProgressPct(total ? Math.round((done / total) * 100) : 0);
    setActiveLesson((prev: Lesson | null) => {
      if (prev && data.course.lessons.some((l: Lesson) => l.id === prev.id)) {
        return data.course.lessons.find((l: Lesson) => l.id === prev.id) ?? null;
      }
      return data.course.lessons.find((l: Lesson) => !l.progress[0]?.completed) ?? data.course.lessons[0] ?? null;
    });
  }, [params.id]);

  useEffect(() => {
    void load();
  }, [load]);

  async function post(url: string, failMessage: string) {
    try {
      const res = await fetch(url, { method: "POST" });
      setNotice(res.ok ? null : failMessage);
    } catch {
      setNotice("Sunucuya ulaşılamadı. Tekrar dene.");
    }
    await load();
  }

  const completeLesson = (lessonId: string) => post(`/api/lessons/${lessonId}/complete`, "Ders kaydedilemedi.");

  async function resetProgress() {
    if (!window.confirm("Bu kurstaki tüm ders ilerlemesi sıfırlansın mı? Quiz geçmişi korunur.")) return;
    setActiveLesson(null);
    setView("lesson");
    await post(`/api/courses/${params.id}/reset`, "İlerleme sıfırlanamadı.");
  }

  if (!course) {
    return (
      <>
        <SiteHeader current="/ders" />
        <main id="icerik" className="mx-auto w-[min(100%-2rem,var(--container-max))] p-8 text-text-secondary" role={loadError ? "alert" : undefined}>
          {loadError ? (
            <>
              {loadError}{" "}
              <Link href="/katalog" className="font-semibold text-accent hover:underline">
                Kataloğa dön
              </Link>
            </>
          ) : (
            "Yükleniyor…"
          )}
        </main>
      </>
    );
  }

  const allLessonsDone = course.lessons.every((l) => l.progress[0]?.completed);
  const activeCompleted = activeLesson?.progress[0]?.completed ?? false;

  return (
    <>
      <SiteHeader current="/ders" />
      <main id="icerik" className="mx-auto w-[min(100%-2rem,var(--container-max))] px-0 py-7 pb-16 max-[680px]:pt-[18px]">
        <div className="grid grid-cols-[280px_minmax(0,1fr)] items-start gap-6 max-[1060px]:grid-cols-1">
          <aside className="animate-surface-in sticky top-[92px] overflow-hidden rounded-[var(--card-radius)] border border-border bg-bg-card shadow-[var(--shadow-sm)] max-[1060px]:static">
            <div className="border-b border-border p-5">
              <h1 className="font-display text-[22px] leading-[1.18] tracking-tight">{course.title}</h1>
              <p className="mt-1.5 text-[13px] text-text-secondary">
                {course.lessons.length} ders · {course.quiz ? "1 quiz" : "quiz yok"} · demo öğrenci
              </p>
              <div className="mt-3.5" aria-label="Kurs ilerlemesi">
                <div className="flex justify-between gap-3 text-xs font-bold tracking-wide text-text-secondary">
                  <span>İlerleme</span>
                  <span>{progressPct}%</span>
                </div>
                <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-border">
                  <span className="block h-full rounded-full bg-accent transition-all duration-300" style={{ width: `${progressPct}%` }} />
                </div>
              </div>
              {progressPct > 0 && (
                <button
                  type="button"
                  onClick={() => void resetProgress()}
                  className="mt-3 text-xs font-semibold text-text-secondary underline-offset-2 hover:text-accent hover:underline"
                >
                  İlerlemeyi sıfırla
                </button>
              )}
            </div>
            <div className="grid py-2.5 max-[1060px]:grid-cols-2 max-[680px]:grid-cols-1">
              {course.lessons.map((lesson) => {
                const done = lesson.progress[0]?.completed;
                const current = view === "lesson" && activeLesson?.id === lesson.id;
                return (
                  <button
                    key={lesson.id}
                    type="button"
                    aria-current={current ? "step" : undefined}
                    onClick={() => {
                      setActiveLesson(lesson);
                      setView("lesson");
                    }}
                    className={`grid min-h-[58px] w-full cursor-pointer grid-cols-[20px_minmax(0,1fr)] items-center gap-2.5 border-0 border-l-[3px] bg-transparent px-4 py-2.5 text-left ${
                      current ? "border-l-accent bg-bg-muted text-text-primary" : "border-l-transparent text-text-secondary hover:bg-[color-mix(in_oklch,var(--bg-muted),white_46%)]"
                    }`}
                  >
                    {done ? (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4 text-success" aria-hidden="true">
                        <path d="m5 12 4 4L19 6" />
                      </svg>
                    ) : (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden="true">
                        <path d="M8 5v14l11-7-11-7Z" />
                      </svg>
                    )}
                    <span>
                      <span className="block text-sm font-semibold leading-snug">{lesson.title}</span>
                      <span className="mt-0.5 block text-xs text-text-secondary">Ders {lesson.order}</span>
                    </span>
                  </button>
                );
              })}
              {course.quiz && (
                <button
                  type="button"
                  aria-current={view === "quiz" ? "step" : undefined}
                  onClick={() => setView("quiz")}
                  className={`grid min-h-[58px] w-full cursor-pointer grid-cols-[20px_minmax(0,1fr)] items-center gap-2.5 border-0 border-l-[3px] bg-transparent px-4 py-2.5 text-left ${
                    view === "quiz" ? "border-l-accent bg-bg-muted text-text-primary" : "border-l-transparent text-text-secondary"
                  } ${!allLessonsDone ? "opacity-70" : ""}`}
                >
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden="true">
                    {!allLessonsDone ? (
                      <>
                        <rect x="5" y="11" width="14" height="10" rx="2" />
                        <path d="M8 11V8a4 4 0 0 1 8 0v3" />
                      </>
                    ) : (
                      <path d="m5 12 4 4L19 6" />
                    )}
                  </svg>
                  <span>
                    <span className="block text-sm font-semibold leading-snug">{course.quiz.title}</span>
                    <span className="mt-0.5 block text-xs text-text-secondary">{course.quiz.questions.length} soru</span>
                  </span>
                </button>
              )}
            </div>
          </aside>

          <section className="animate-surface-in overflow-hidden rounded-[var(--card-radius)] border border-border bg-bg-card shadow-[var(--shadow-sm)] [animation-delay:70ms]">
            <div className="flex items-center justify-between gap-4 border-b border-border p-[18px_20px] max-[680px]:grid">
              <span className="text-[13px] font-semibold text-text-secondary">
                Katalog / {course.title} / {view === "quiz" ? "Quiz" : activeLesson ? `Ders ${activeLesson.order}` : "—"}
              </span>
              <span
                className={`inline-flex h-7 items-center rounded-full px-2.5 text-xs font-bold ${
                  (view === "quiz" ? allLessonsDone : activeCompleted)
                    ? "bg-[color-mix(in_oklch,var(--success),white_86%)] text-[color-mix(in_oklch,var(--success),black_22%)]"
                    : "bg-[color-mix(in_oklch,var(--warning),white_84%)] text-[color-mix(in_oklch,var(--warning),black_40%)]"
                }`}
              >
                {view === "quiz"
                  ? allLessonsDone
                    ? "Quiz açık"
                    : "Quiz kilitli"
                  : activeCompleted
                    ? "Tamamlandı"
                    : "Devam ediyor"}
              </span>
            </div>

            {view === "lesson" && activeLesson && (
              <>
                <div
                  className="relative grid aspect-video place-items-center overflow-hidden p-7 text-white max-[680px]:min-h-[260px]"
                  aria-label="Video oynatıcı"
                >
                  <img
                    src={courseCover(course.title, "mobil")}
                    alt=""
                    aria-hidden="true"
                    className="absolute inset-0 h-full w-full object-cover"
                  />
                  <div className="absolute inset-0 bg-[radial-gradient(circle_at_72%_26%,color-mix(in_oklch,var(--accent),transparent_68%)_0_110px,transparent_112px),linear-gradient(135deg,rgba(15,23,42,0.72),rgba(15,23,42,0.88))]" />
                  <div className="relative z-10 grid place-items-center gap-3.5 text-center">
                    <button
                      type="button"
                      aria-label={playing ? "Videoyu duraklat" : "Videoyu oynat"}
                      onClick={() => setPlaying((p) => !p)}
                      className="grid h-[68px] w-[68px] place-items-center rounded-full border-0 bg-white/94 text-bg-dark hover:scale-105 focus-visible:outline focus-visible:outline-[3px] focus-visible:outline-offset-4 focus-visible:outline-[color-mix(in_oklch,var(--accent),white_28%)]"
                    >
                      {playing ? (
                        <svg viewBox="0 0 24 24" fill="currentColor" className="h-7 w-7" aria-hidden="true">
                          <path d="M7 5h4v14H7V5Zm6 0h4v14h-4V5Z" />
                        </svg>
                      ) : (
                        <svg viewBox="0 0 24 24" fill="currentColor" className="ml-0.5 h-7 w-7" aria-hidden="true">
                          <path d="M8 5v14l11-7-11-7Z" />
                        </svg>
                      )}
                    </button>
                    <strong className="text-lg tracking-tight">{playing ? "Oynatılıyor" : "Poster hazır"}</strong>
                    <span className="text-[13px] text-white/70">HLS/Mux entegrasyonu Faz 2 için ayrıldı</span>
                  </div>
                  <div className="absolute inset-x-5 bottom-[18px] z-10 grid grid-cols-[auto_1fr_auto] items-center gap-3 font-mono text-xs text-white/75 max-[680px]:static max-[680px]:mt-4 max-[680px]:w-full">
                    <span>{playing ? "09:42" : "06:58"}</span>
                    <div className="h-1.5 overflow-hidden rounded-full bg-white/20">
                      <span className="block h-full rounded-full bg-white transition-all" style={{ width: playing ? "67%" : "48%" }} />
                    </div>
                    <span>14:30</span>
                  </div>
                </div>

                <div className="grid grid-cols-[minmax(0,1fr)_320px] items-start gap-6 p-6 max-[1060px]:grid-cols-1 max-[680px]:p-[18px]">
                  <article>
                    <h2 className="mb-2.5 font-display text-[clamp(1.75rem,4vw,2.5rem)] leading-[1.08] tracking-[-0.02em] text-balance">
                      {activeLesson.title}
                    </h2>
                    <p className="mb-4 max-w-[68ch] whitespace-pre-wrap text-text-secondary">{activeLesson.content}</p>

                    <div className="my-5 grid grid-cols-[24px_minmax(0,1fr)] items-start gap-3 rounded-[var(--card-radius)] border border-border bg-bg-muted p-4">
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="mt-0.5 h-5 w-5 text-accent" aria-hidden="true">
                        <circle cx="12" cy="12" r="10" />
                        <path d="M12 16v-4" />
                        <path d="M12 8h.01" />
                      </svg>
                      <div>
                        <strong className="mb-0.5 block text-sm">Quiz kilidi</strong>
                        <span className="text-sm text-text-secondary">
                          Tüm dersleri tamamlamadan quiz gönderilemez; bu gerçek ürün akışındaki kilit mesajını temsil eder.
                        </span>
                      </div>
                    </div>

                    <div className="mt-5 flex flex-wrap gap-2.5">
                      {!activeCompleted && (
                        <Button type="button" onClick={() => completeLesson(activeLesson.id)}>
                          Dersi tamamla
                        </Button>
                      )}
                      <LinkButton href="/katalog" variant="secondary">
                        Kataloğa dön
                      </LinkButton>
                    </div>
                    {notice && (
                      <p className="mt-3 text-sm font-semibold text-danger" role="alert">
                        {notice}
                      </p>
                    )}
                  </article>

                  <div className="grid gap-4">
                    {course.quiz && (
                      // Onizleme yalnizca ozet gosterir; tek soruyla deneme gondermek puani bozuyordu.
                      <section className="rounded-[var(--card-radius)] border border-border bg-bg-card p-[18px] shadow-[var(--shadow-sm)]">
                        <h2 className="mb-1.5 text-lg leading-tight tracking-tight">{course.quiz.title}</h2>
                        <p className="mb-3 text-sm text-text-secondary">
                          {course.quiz.questions.length} soru ·{" "}
                          {course.quiz.bestPercent === null ? "henüz deneme yok" : `en iyi sonuç %${course.quiz.bestPercent}`}
                        </p>
                        <Button type="button" variant="secondary" onClick={() => setView("quiz")}>
                          {allLessonsDone ? "Quiz'e geç" : "Quiz kilitli — göz at"}
                        </Button>
                      </section>
                    )}
                    <section className="rounded-[var(--card-radius)] border border-border bg-bg-card p-[18px] shadow-[var(--shadow-sm)]">
                      <h2 className="mb-2.5 text-lg leading-tight tracking-tight">Bu derste netleşenler</h2>
                      <ul className="grid list-none gap-2.5 p-0 text-sm text-text-secondary">
                        {[
                          "Local state küçük etkileşimlerde kalır.",
                          "Quiz sonucu sunucuya gittiğinde ilerleme verisiyle eşleşir.",
                          "Faz 2 analitik için drop-off olayları ayrı tutulur.",
                        ].map((note) => (
                          <li key={note} className="grid grid-cols-[18px_minmax(0,1fr)] items-start gap-2">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="mt-0.5 h-4 w-4 text-success" aria-hidden="true">
                              <path d="m5 12 4 4L19 6" />
                            </svg>
                            <span>{note}</span>
                          </li>
                        ))}
                      </ul>
                    </section>
                  </div>
                </div>
              </>
            )}

            {view === "quiz" && course.quiz && (
              <div className="p-6">
                <QuizPanel
                  courseId={course.id}
                  title={course.quiz.title}
                  questions={course.quiz.questions}
                  unlocked={allLessonsDone}
                  onSubmitted={() => void load()}
                />
                {course.quiz.attempts.length > 0 && (
                  <section className="mt-5" aria-label="Quiz geçmişi">
                    <h3 className="mb-2 text-sm font-bold">
                      Son denemeler · en iyi %{course.quiz.bestPercent}
                    </h3>
                    <ul className="grid list-none gap-1.5 p-0 text-sm text-text-secondary">
                      {course.quiz.attempts.map((a, i) => (
                        <li key={i} className="flex justify-between gap-3 rounded-[var(--button-radius)] bg-bg-muted px-3 py-2">
                          <span>{new Date(a.createdAt).toLocaleString("tr-TR")}</span>
                          <strong className="text-text-primary">
                            {a.score}/{a.total}
                          </strong>
                        </li>
                      ))}
                    </ul>
                  </section>
                )}
                <div className="mt-4">
                  <Link href="/katalog" className="text-sm font-semibold text-accent hover:underline">
                    ← Kataloğa dön
                  </Link>
                </div>
              </div>
            )}
          </section>
        </div>
      </main>
    </>
  );
}
