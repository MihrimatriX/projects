"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Button, LinkButton } from "@/components/Button";
import { CourseCover } from "@/components/CourseCover";
import type { CatalogItem } from "@/lib/catalog";
import { CATEGORIES } from "@/lib/catalog";

type Props = {
  items: CatalogItem[];
  continueCourse?: { title: string; href: string; progress: number; lessonHint: string; coverImage: string };
};

function normalize(value: string) {
  return value.toLocaleLowerCase("tr-TR").trim();
}

function StarIcon() {
  return (
    <svg viewBox="0 0 24 24" aria-hidden="true" className="h-[15px] w-[15px] fill-star stroke-star">
      <path d="m12 2 3 6.4 7 .9-5.1 5 1.3 7L12 18l-6.2 3.3 1.3-7-5.1-5 7-.9L12 2Z" />
    </svg>
  );
}

export function CatalogClient({ items, continueCourse }: Props) {
  const [query, setQuery] = useState("");
  const [level, setLevel] = useState("all");
  const [category, setCategory] = useState("all");

  const visible = useMemo(() => {
    const q = normalize(query);
    return items.filter((item) => {
      const matchesQuery = !q || normalize(`${item.title} ${item.description}`).includes(q);
      const matchesLevel = level === "all" || item.level === level;
      const matchesCategory = category === "all" || item.category.includes(category);
      return matchesQuery && matchesLevel && matchesCategory;
    });
  }, [items, query, level, category]);

  function clearFilters() {
    setQuery("");
    setLevel("all");
    setCategory("all");
  }

  return (
    <>
      {continueCourse && (
        <section className="mb-7 grid grid-cols-[minmax(0,1fr)_minmax(300px,390px)] items-stretch gap-6 max-[1024px]:grid-cols-1">
          <div className="animate-surface-in overflow-hidden rounded-[18px] bg-[radial-gradient(circle_at_86%_20%,color-mix(in_oklch,var(--accent),transparent_68%)_0_110px,transparent_112px),linear-gradient(var(--bg-dark),var(--bg-dark))] p-[clamp(26px,5vw,48px)] text-text-inverse shadow-[var(--shadow-md)]">
            <span className="inline-flex items-center gap-2 font-mono text-xs uppercase tracking-[0.08em] text-[color-mix(in_oklch,var(--text-inverse),transparent_24%)] before:h-2 before:w-2 before:rounded-full before:bg-success before:content-['']">
              Kurs vitrini
            </span>
            <h1 className="mt-6 mb-3.5 max-w-[12ch] font-display text-[clamp(2.375rem,6vw,4rem)] leading-[1.04] tracking-[-0.03em] text-balance">
              Niş kursları hızlı keşfet.
            </h1>
            <p className="max-w-[62ch] text-[17px] text-[color-mix(in_oklch,var(--text-inverse),transparent_16%)]">
              Self-host edilebilir, komisyonsuz eğitim pazarında demo kurslar, kayıt durumu ve öğrenci ilerlemesi aynı katalog akışında görünür.
            </p>
            <div className="mt-7 grid grid-cols-3 gap-2.5 max-[680px]:grid-cols-1">
              {[
                { n: String(items.length), l: "yayında kurs" },
                { n: "1", l: "demo seed" },
                { n: "3", l: "öğrenme yolu" },
              ].map((s) => (
                <div key={s.l} className="rounded-[var(--card-radius)] border border-white/15 bg-white/6 p-3.5">
                  <strong className="block text-[22px] leading-tight tracking-tight">{s.n}</strong>
                  <span className="mt-1 block text-xs text-[color-mix(in_oklch,var(--text-inverse),transparent_28%)]">{s.l}</span>
                </div>
              ))}
            </div>
          </div>

          <aside className="animate-surface-in flex min-h-full flex-col justify-between rounded-[18px] border border-border bg-bg-card p-[22px] shadow-[var(--shadow-sm)]">
            <div>
              <div className="relative mb-4 overflow-hidden rounded-[var(--card-radius)]">
                <CourseCover src={continueCourse.coverImage} alt={continueCourse.title} />
                <span className="absolute inset-0 grid place-items-center">
                  <span className="grid h-12 w-12 place-items-center rounded-full bg-white/92 text-bg-dark shadow-md">
                    <svg viewBox="0 0 24 24" fill="currentColor" className="ml-0.5 h-[22px] w-[22px]">
                      <path d="M8 5v14l11-7-11-7Z" />
                    </svg>
                  </span>
                </span>
              </div>
              <h2 className="text-xl leading-tight tracking-tight">{continueCourse.title}</h2>
              <p className="mt-2 text-sm text-text-secondary">{continueCourse.lessonHint}</p>
              <div className="my-3 h-2 overflow-hidden rounded-full bg-border">
                <span className="block h-full bg-accent" style={{ width: `${continueCourse.progress}%` }} />
              </div>
            </div>
            <LinkButton href={continueCourse.href}>Derse devam et</LinkButton>
          </aside>
        </section>
      )}

      <section aria-label="Kurs filtreleri">
        <div className="animate-surface-in mb-5 grid grid-cols-[minmax(240px,1fr)_auto_auto] items-end gap-3 rounded-[18px] border border-border bg-bg-card p-4 shadow-[var(--shadow-sm)] max-[1024px]:grid-cols-1 [animation-delay:70ms]">
          <label className="grid gap-1.5">
            <span className="text-xs font-bold uppercase tracking-[0.08em] text-text-secondary">Kurs ara</span>
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Flutter, Next.js, tasarım..."
              autoComplete="off"
              className="min-h-11 w-full rounded-[var(--button-radius)] border border-border bg-bg-card px-3 text-text-primary focus:border-accent focus:shadow-[0_0_0_3px_color-mix(in_oklch,var(--accent),transparent_70%)] focus:outline-none"
            />
          </label>
          <label className="grid gap-1.5">
            <span className="text-xs font-bold uppercase tracking-[0.08em] text-text-secondary">Seviye</span>
            <select
              value={level}
              onChange={(e) => setLevel(e.target.value)}
              className="min-h-11 rounded-[var(--button-radius)] border border-border bg-bg-card px-3 focus:border-accent focus:shadow-[0_0_0_3px_color-mix(in_oklch,var(--accent),transparent_70%)] focus:outline-none"
            >
              <option value="all">Tüm seviyeler</option>
              <option value="baslangic">Başlangıç</option>
              <option value="orta">Orta</option>
              <option value="ileri">İleri</option>
            </select>
          </label>
          <Button variant="secondary" onClick={clearFilters} className="self-end">
            Temizle
          </Button>
        </div>

        <div className="animate-surface-in mb-5 flex flex-wrap gap-2 [animation-delay:120ms]" role="group" aria-label="Kategoriler">
          {CATEGORIES.map((cat) => (
            <button
              key={cat.id}
              type="button"
              aria-pressed={category === cat.id}
              onClick={() => setCategory(cat.id)}
              className={`min-h-9 rounded-full border px-3 text-sm font-semibold transition ${
                category === cat.id
                  ? "border-accent bg-[color-mix(in_oklch,var(--accent),white_88%)] text-[color-mix(in_oklch,var(--accent),black_18%)]"
                  : "border-border bg-bg-card text-text-secondary hover:border-accent"
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>
      </section>

      {visible.length === 0 ? (
        <div className="rounded-[18px] border border-dashed border-border bg-bg-card p-10 text-center text-text-secondary" role="status">
          <strong className="mb-1.5 block text-xl tracking-tight text-text-primary">Bu filtrelerle kurs bulunamadı.</strong>
          Aramayı sadeleştir veya tüm kategorilere geri dön.
        </div>
      ) : (
        <div className="grid grid-cols-3 gap-6 max-[1024px]:grid-cols-2 max-[680px]:grid-cols-1">
          {visible.map((item, i) => (
            <article
              key={item.id ?? item.title}
              className="animate-surface-in relative overflow-hidden rounded-[var(--card-radius)] border border-border bg-bg-card shadow-[var(--shadow-sm)] transition hover:-translate-y-0.5 hover:border-[color-mix(in_oklch,var(--accent),var(--border)_68%)] hover:shadow-[var(--shadow-md)]"
              style={{ animationDelay: `${120 + i * 40}ms` }}
            >
              {item.featured && <div className="absolute inset-x-0 top-0 z-10 h-[3px] bg-accent" />}
              <CourseCover
                src={item.coverImage}
                alt={item.title}
                title={item.coverTitle}
                levelLabel={item.levelLabel}
                overlay
              />
              <div className="p-5">
                <div className="flex items-start justify-between gap-3">
                  <h2 className="text-xl leading-tight tracking-tight">{item.title}</h2>
                  <span
                    className={`inline-flex h-[26px] items-center whitespace-nowrap rounded-full px-2 text-xs font-bold ${
                      item.badgeWarning
                        ? "bg-[color-mix(in_oklch,var(--warning),white_84%)] text-[color-mix(in_oklch,var(--warning),black_38%)]"
                        : "bg-[color-mix(in_oklch,var(--success),white_86%)] text-[color-mix(in_oklch,var(--success),black_22%)]"
                    }`}
                  >
                    {item.badge}
                  </span>
                </div>
                <p className="mt-2.5 mb-4 text-sm leading-relaxed text-text-secondary">{item.description}</p>
                <div className="flex items-center justify-between gap-3 text-[13px] text-text-secondary">
                  <span className="inline-flex items-center gap-1.5 font-bold text-text-primary">
                    <StarIcon />
                    {item.rating}
                  </span>
                  <span>{item.meta}</span>
                </div>
                <div className="mt-4 flex items-center justify-between gap-4">
                  <strong className="text-2xl leading-none tracking-tight">{item.price}</strong>
                  {item.action === "continue" && item.href ? (
                    <LinkButton href={item.href}>Devam et</LinkButton>
                  ) : (
                    <Button variant="secondary" disabled>
                      {item.badge === "Yakında" ? "Listeye alındı" : "Planlı"}
                    </Button>
                  )}
                </div>
              </div>
            </article>
          ))}
        </div>
      )}
    </>
  );
}
