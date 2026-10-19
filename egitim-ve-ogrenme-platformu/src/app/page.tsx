import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { ensureSeed } from "@/lib/seed";
import { prisma } from "@/lib/prisma";

// Veritabanından okunur; build sırasında statik HTML'e dondurulmasın.
export const dynamic = "force-dynamic";

export default async function HomePage() {
  await ensureSeed();
  const course = await prisma.course.findFirst({
    include: {
      lessons: { include: { progress: true } },
      quiz: { include: { attempts: { orderBy: { createdAt: "desc" }, take: 1 } } },
    },
  });

  const lessonProgress = course
    ? Math.round(
        (course.lessons.filter((l) => l.progress[0]?.completed).length / Math.max(course.lessons.length, 1)) * 100
      )
    : 0;
  const lastAttempt = course?.quiz?.attempts[0];
  const quizLabel = lastAttempt ? `${lastAttempt.score}/${lastAttempt.total}` : "—";
  const quizPct = lastAttempt && lastAttempt.total ? Math.round((lastAttempt.score / lastAttempt.total) * 100) : 0;
  const courseHref = course ? `/course/${course.id}` : "/katalog";

  return (
    <>
      <SiteHeader current="/" cta={{ href: "/katalog", label: "Kursları aç" }} />
      <main id="icerik" className="mx-auto w-[min(100%-2rem,var(--container-max))] px-0 py-10 pb-16 max-[720px]:pt-5">
        <section className="grid min-h-[420px] grid-cols-[minmax(0,1.1fr)_minmax(320px,0.9fr)] items-stretch gap-7 max-[980px]:grid-cols-1">
          <div className="animate-surface-in flex flex-col justify-between overflow-hidden rounded-[18px] bg-[radial-gradient(circle_at_78%_18%,color-mix(in_oklch,var(--accent),transparent_66%)_0_120px,transparent_122px),linear-gradient(135deg,var(--bg-dark),oklch(28%_0.06_265))] p-[clamp(28px,5vw,56px)] text-text-inverse shadow-[var(--shadow-md)] max-[720px]:min-h-[460px]">
            <div>
              <span className="inline-flex items-center gap-2 font-mono text-xs uppercase tracking-[0.08em] text-[color-mix(in_oklch,var(--text-inverse),transparent_22%)] before:h-2 before:w-2 before:rounded-full before:bg-success before:shadow-[0_0_0_5px_color-mix(in_oklch,var(--success),transparent_82%)] before:content-['']">
                MVP v1.0 hazır
              </span>
              <h1 className="mt-7 mb-5 max-w-[11ch] font-display text-[clamp(2.5rem,7vw,4.5rem)] leading-[1.02] font-normal tracking-[-0.03em] text-balance">
                Türkçe-first eğitim marketplace.
              </h1>
              <p className="max-w-[62ch] text-[clamp(1rem,1.8vw,1.125rem)] leading-[1.62] text-[color-mix(in_oklch,var(--text-inverse),transparent_16%)]">
                Katalog, ders ilerlemesi, sunucu puanlamalı quiz ve Faz 2 eğitmen analitiği aynı açık tema sistemiyle çalışır.
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Link href="/katalog" className="inline-flex min-h-11 items-center rounded-[var(--button-radius)] bg-white px-4 text-sm font-semibold text-bg-dark hover:-translate-y-px">
                  Kurs vitrini
                </Link>
                <Link href={courseHref} className="inline-flex min-h-11 items-center rounded-[var(--button-radius)] border border-white/25 px-4 text-sm font-semibold text-text-inverse hover:-translate-y-px">
                  Derse devam et
                </Link>
              </div>
            </div>
          </div>

          <aside className="animate-surface-in flex flex-col overflow-hidden rounded-[18px] border border-border bg-bg-card shadow-[var(--shadow-sm)] [animation-delay:70ms]">
            <div className="flex justify-between gap-4 border-b border-border p-[22px_22px_16px] max-[720px]:grid">
              <div>
                <h2 className="text-lg leading-tight tracking-tight">Bugünkü öğrenme durumu</h2>
                <p className="mt-1.5 text-sm text-text-secondary">Demo öğrenci hesabı: {course?.title ?? "—"}</p>
              </div>
              <span className="inline-flex h-7 items-center whitespace-nowrap rounded-full bg-[color-mix(in_oklch,var(--success),white_86%)] px-2.5 text-xs font-bold text-[color-mix(in_oklch,var(--success),black_22%)]">
                Demo mod
              </span>
            </div>
            <div className="grid gap-[18px] p-[18px_22px_22px]">
              {[
                { label: "Ders ilerlemesi", value: `${lessonProgress}%`, width: lessonProgress },
                { label: "Quiz doğruluğu", value: quizLabel, width: quizPct },
                { label: "Eğitmen drop-off görünürlüğü", value: "Faz 2", width: 38 },
              ].map((item) => (
                <div key={item.label} className="grid gap-2">
                  <div className="flex justify-between gap-4 text-sm font-semibold">
                    <span>{item.label}</span>
                    <span className="font-mono text-xs tracking-wide text-text-secondary">{item.value}</span>
                  </div>
                  <div className="h-2 overflow-hidden rounded-full bg-border">
                    <div className="h-full rounded-full bg-accent" style={{ width: `${item.width}%` }} />
                  </div>
                </div>
              ))}
            </div>
          </aside>
        </section>

        <section aria-labelledby="screens-title" className="mt-12">
          <div className="mb-5 flex items-end justify-between gap-6 max-[980px]:grid">
            <h2 id="screens-title" className="max-w-[14ch] text-[clamp(1.75rem,4vw,2.5rem)] leading-[1.08] tracking-[-0.02em] text-balance">
              Üç ana ürün yüzeyi.
            </h2>
            <p className="max-w-[54ch] text-text-secondary">
              Her ekran kendi rotasında; filtreleme, quiz, ilerleme ve analitik gerçek kontrollerle çalışır.
            </p>
          </div>

          <div className="grid grid-cols-3 gap-6 max-[980px]:grid-cols-1">
            {[
              {
                href: "/katalog",
                title: "Kurs vitrini",
                text: "Teachable/Udemy hissinde katalog, arama, kategori filtresi ve boş sonuç durumu.",
                pills: ["Responsive grid", "Arama", "Kayıtlı durum"],
                icon: (
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" className="h-[22px] w-[22px] stroke-[1.7]">
                    <path d="M4 5h16" /><path d="M4 12h16" /><path d="M4 19h16" /><path d="M8 5v14" />
                  </svg>
                ),
              },
              {
                href: courseHref,
                title: "Ders ve quiz",
                text: "Curriculum sidebar, video oynatıcı durumu, dersi tamamlama ve quiz paneli.",
                pills: ["Lesson nav", "Quiz state", "İlerleme"],
                icon: (
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" className="h-[22px] w-[22px] stroke-[1.7]">
                    <path d="M5 4h14a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1Z" /><path d="m10 8 5 3-5 3V8Z" /><path d="M8 20h8" /><path d="M12 16v4" />
                  </svg>
                ),
              },
              {
                href: "/egitmen",
                title: "Eğitmen paneli",
                text: "Faz 2 için kurs oluşturma, yayın kontrol listesi ve drop-off bar chart modülü.",
                pills: ["Analitik", "Kurs taslağı", "Yayın hazırlığı"],
                icon: (
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeLinecap="round" strokeLinejoin="round" className="h-[22px] w-[22px] stroke-[1.7]">
                    <path d="M4 19V5" /><path d="M4 19h16" /><path d="M8 16v-5" /><path d="M12 16V8" /><path d="M16 16v-7" />
                  </svg>
                ),
              },
            ].map((card, i) => (
              <article
                key={card.href}
                className="animate-surface-in flex min-h-[330px] flex-col rounded-[var(--card-radius)] border border-border bg-bg-card p-6 shadow-[var(--shadow-sm)] transition hover:-translate-y-0.5 hover:border-[color-mix(in_oklch,var(--accent),var(--border)_68%)] hover:shadow-[var(--shadow-md)] focus-within:-translate-y-0.5"
                style={{ animationDelay: `${110 + i * 50}ms` }}
              >
                <div className="mb-5 grid h-11 w-11 place-items-center rounded-xl bg-bg-muted">{card.icon}</div>
                <h3 className="text-xl leading-tight tracking-tight">{card.title}</h3>
                <p className="mt-2.5 mb-5 text-[15px] leading-relaxed text-text-secondary">{card.text}</p>
                <div className="mt-auto flex flex-wrap gap-2 pt-3.5">
                  {card.pills.map((pill) => (
                    <span key={pill} className="inline-flex h-7 items-center rounded-full bg-bg-muted px-2.5 text-xs font-semibold text-text-secondary">
                      {pill}
                    </span>
                  ))}
                </div>
                <Link href={card.href} className="mt-4 inline-flex min-h-10 items-center justify-between gap-3 rounded-[var(--button-radius)] border border-border px-3 text-sm font-semibold hover:border-accent hover:shadow-[0_0_0_3px_color-mix(in_oklch,var(--accent),transparent_76%)]">
                  {card.title} aç
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden="true">
                    <path d="M5 12h14" /><path d="m13 6 6 6-6 6" />
                  </svg>
                </Link>
              </article>
            ))}
          </div>
        </section>
      </main>
    </>
  );
}
