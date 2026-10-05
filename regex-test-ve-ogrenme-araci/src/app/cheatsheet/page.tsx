"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CHEATSHEET_CATEGORIES } from "@/lib/cheatsheet-data";

const CAT_ICONS: Record<string, string> = {
  basics: "Aa",
  anchors: "^$",
  quantifiers: "n+",
  groups: "()",
  flags: "gim",
  replace: "$1",
};

// "Laboratuvarda dene" icin cogu karti eslestiren ornek metin (onceden tek satirlik "Örnek metin buraya" idi).
const SAMPLE_TEXT = `Merhaba dünya! Kedi (cat) ve catalog.
abc a9c 123 4567 aaa
kullanici@ornek.com https://ornek.com/yol
<b>kalın</b> <i>eğik</i> foo foobar ABC Abc #A1F 2026-10-05`;

const norm = (s: string) => s.toLocaleLowerCase("tr");

export default function CheatsheetPage() {
  const router = useRouter();
  const [loadingCode, setLoadingCode] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  useEffect(() => {
    document.documentElement.dataset.ready = "1"; // istemci hazir (UI testleri bekler)
  }, []);

  const tryInLab = (code: string) => {
    setLoadingCode(code);
    router.push(`/lab?p=${encodeURIComponent(code)}&f=g&t=${encodeURIComponent(SAMPLE_TEXT)}`);
  };

  const q = norm(query.trim());
  const categories = CHEATSHEET_CATEGORIES.map((c) => ({
    ...c,
    items: q ? c.items.filter((i) => norm(`${i.code} ${i.title} ${i.desc} ${i.example ?? ""}`).includes(q)) : c.items,
  })).filter((c) => c.items.length > 0);

  return (
    <main className="min-h-screen bg-[var(--bg-app)] text-[var(--text-primary)]">
      <div className="mx-auto max-w-[960px] px-4 py-10 sm:px-6 md:py-16">
        <Link
          href="/lab"
          className="mb-5 inline-flex items-center gap-1.5 text-[13px] font-medium tracking-wide text-[var(--accent-hover)] hover:underline"
        >
          ← Laboratuvara dön
        </Link>
        <header className="mb-10">
          <h1 className="mb-2.5 text-[clamp(28px,4vw,36px)] font-semibold leading-tight tracking-tight">
            Regex Cheatsheet
          </h1>
          <p className="max-w-[52ch] text-[15px] leading-relaxed text-[var(--text-secondary)]">
            Türkçe açıklamalı düzenli ifade referansı — meta karakterler, gruplar, bayraklar ve replace
            ipuçları.
          </p>
          <span className="mt-4 inline-block rounded-full border border-[var(--border)] px-2.5 py-1 text-[11px] font-semibold uppercase tracking-widest text-[var(--text-muted)]">
            v1.2
          </span>
        </header>

        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Cheatsheet'te ara… (ör. grup, \d, lookahead)"
          aria-label="Cheatsheet'te ara"
          className="mb-6 w-full rounded-[var(--radius-btn)] border border-[var(--border)] bg-[var(--bg-editor)] px-3 py-2 text-[13px] focus:outline-none focus:ring-2 focus:ring-[var(--accent)]"
        />
        <div className="flex flex-col gap-8">
          {categories.length === 0 && (
            <p className="text-[13px] text-[var(--text-muted)]">&quot;{query}&quot; için sonuç yok.</p>
          )}
          {categories.map((category) => (
            <section
              key={category.id}
              className="overflow-hidden rounded-[var(--radius-panel)] border border-[var(--border)] bg-[var(--bg-editor)]"
            >
              <h2 className="flex items-center gap-2.5 border-b border-[var(--border)] px-[18px] py-3.5 text-sm font-semibold tracking-tight">
                <span className="grid h-7 w-7 place-items-center rounded-md border border-[var(--border)] font-mono text-[11px] font-semibold text-[var(--text-secondary)]">
                  {CAT_ICONS[category.id] ?? category.icon.slice(0, 2)}
                </span>
                {category.title}
              </h2>
              <div className="grid gap-px bg-[var(--border)] sm:grid-cols-2">
                {category.items.map((item) => (
                  <article key={`${category.id}-${item.code}`} className="flex flex-col gap-2 bg-[var(--bg-editor)] p-[18px]">
                    <div className="flex items-start gap-3">
                      <code className="shrink-0 rounded border border-[color-mix(in_srgb,var(--code-accent)_20%,var(--border))] bg-[color-mix(in_srgb,var(--code-accent)_8%,transparent)] px-2 py-1 font-mono text-xs font-semibold text-[var(--code-accent)]">
                        {item.code}
                      </code>
                      <h3 className="text-sm font-semibold leading-snug tracking-tight">{item.title}</h3>
                    </div>
                    <p className="text-[13px] leading-relaxed text-[var(--text-secondary)]">{item.desc}</p>
                    {item.example && (
                      <p className="rounded border border-[var(--border)] bg-[var(--bg-app)] px-2.5 py-2 font-mono text-xs text-[var(--accent-hover)]">
                        {item.example}
                      </p>
                    )}
                    {category.id !== "flags" && (
                      <button
                        type="button"
                        disabled={loadingCode === item.code}
                        onClick={() => tryInLab(item.code.split(" ")[0] ?? item.code)}
                        className="mt-1 w-fit rounded-md border border-[var(--border)] px-2.5 py-1.5 text-xs font-medium tracking-wide text-[var(--text-secondary)] transition hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)] active:scale-[0.98] disabled:opacity-60"
                      >
                        {loadingCode === item.code ? "Yükleniyor…" : "Laboratuvarda dene"}
                      </button>
                    )}
                  </article>
                ))}
              </div>
            </section>
          ))}
        </div>

        <footer className="mt-12 text-center text-[13px] text-[var(--text-muted)]">
          <Link href="/lab" className="text-[var(--accent-hover)] hover:underline">
            Canlı laboratuvarda dene →
          </Link>
        </footer>
      </div>
    </main>
  );
}
