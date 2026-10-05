"use client";

import { FormEvent, useState } from "react";
import { SiteHeader } from "@/components/SiteHeader";
import { Button, LinkButton } from "@/components/Button";

const CHART_DATA = {
  seed: [100, 84, 69, 62, 38],
  week: [100, 81, 72, 58, 44],
  month: [100, 88, 75, 64, 41],
} as const;

const LABELS = ["Ders 1", "Ders 2", "Ders 3", "Ders 4", "Quiz"];

type Module = { title: string; type: string };

export default function EgitmenPage() {
  const [range, setRange] = useState<keyof typeof CHART_DATA>("seed");
  const [modules, setModules] = useState<Module[]>([
    { title: "State yönetimine giriş", type: "Ders · 14:30" },
    { title: "Quiz: State seçimi", type: "Quiz · 3 soru" },
  ]);
  const [moduleTitle, setModuleTitle] = useState("");
  const [moduleType, setModuleType] = useState("Ders");
  const [checks, setChecks] = useState([true, true, false, false]);

  const readiness = Math.round((checks.filter(Boolean).length / checks.length) * 100);
  const values = CHART_DATA[range];

  function addModule(e: FormEvent) {
    e.preventDefault();
    const title = moduleTitle.trim();
    if (!title) return;
    setModules((prev) => [{ title, type: `${moduleType} · yeni taslak` }, ...prev]);
    setModuleTitle("");
  }

  return (
    <>
      <SiteHeader current="/egitmen" />
      <main id="icerik" className="mx-auto w-[min(100%-2rem,var(--container-max))] px-0 py-[30px] pb-16">
        <section className="animate-surface-in mb-6 grid grid-cols-[minmax(0,1fr)_auto] items-end gap-6 max-[720px]:grid-cols-1">
          <div>
            <span className="inline-flex items-center gap-2 font-mono text-xs uppercase tracking-[0.08em] text-text-secondary before:h-2 before:w-2 before:rounded-full before:bg-warning before:content-['']">
              Faz 2 eğitmen yüzeyi
            </span>
            <h1 className="mt-3.5 mb-2 max-w-[13ch] font-display text-[clamp(2.25rem,5vw,3.5rem)] leading-[1.04] tracking-[-0.03em] text-balance">
              Kursu yayına hazırlayan panel.
            </h1>
            <p className="max-w-[68ch] text-text-secondary">
              Kurs taslağı, yayın kontrol listesi ve drop-off görünürlüğü aynı panelde; ödeme, video ve sertifika işleri aşamalı eklenebilir.
            </p>
          </div>
          <LinkButton href="/katalog" variant="secondary">
            Öğrenci görünümüne dön
          </LinkButton>
        </section>

        <section className="mb-6 grid grid-cols-4 gap-3.5 max-[1050px]:grid-cols-2 max-[720px]:grid-cols-1" aria-label="Kurs ölçümleri">
          {[
            { label: "Aktif taslak", value: "1", note: "Flutter Temelleri kursu yayına hazırlanıyor." },
            { label: "Gelir", value: "Beklemede", note: "Stripe Checkout Faz 2 kapsamına alındı." },
            { label: "Video durumu", value: "Planlı", note: "Mux/HLS oynatıcı entegrasyonu bekliyor." },
            { label: "Sertifika", value: "Beklemede", note: "PDF üretimi tamamlama sonrası açılacak." },
          ].map((m, i) => (
            <article
              key={m.label}
              className="animate-surface-in rounded-[var(--card-radius)] border border-border bg-bg-card p-[18px] shadow-[var(--shadow-sm)]"
              style={{ animationDelay: `${70 + i * 40}ms` }}
            >
              <span className="block text-xs font-bold uppercase tracking-[0.07em] text-text-secondary">{m.label}</span>
              <strong className="mt-2 block text-[28px] leading-none tracking-tight">{m.value}</strong>
              <small className="mt-2 block text-[13px] leading-snug text-text-secondary">{m.note}</small>
            </article>
          ))}
        </section>

        <div className="grid grid-cols-[minmax(0,1.15fr)_minmax(340px,0.85fr)] items-start gap-6 max-[1050px]:grid-cols-2 max-[720px]:grid-cols-1">
          <section className="animate-surface-in overflow-hidden rounded-[var(--card-radius)] border border-border bg-bg-card shadow-[var(--shadow-sm)] max-[1050px]:col-span-full [animation-delay:160ms]">
            <div className="flex items-start justify-between gap-[18px] border-b border-border p-5 max-[720px]:grid">
              <div>
                <h2 className="text-xl leading-tight tracking-tight">Ders bazlı drop-off</h2>
                <p className="mt-1.5 text-sm text-text-secondary">Örnek kohort görünümü; Faz 2 analitik olayları bağlandığında gerçek veriyle beslenecek.</p>
              </div>
              <div className="inline-flex gap-1 rounded-full border border-border bg-bg-muted p-1" role="group" aria-label="Zaman aralığı">
                {(["seed", "week", "month"] as const).map((key) => (
                  <button
                    key={key}
                    type="button"
                    aria-pressed={range === key}
                    onClick={() => setRange(key)}
                    className={`min-h-[30px] rounded-full px-2.5 text-xs font-bold ${
                      range === key ? "bg-bg-card text-text-primary shadow-[var(--shadow-sm)]" : "text-text-secondary"
                    }`}
                  >
                    {key === "seed" ? "Seed" : key === "week" ? "7 gün" : "30 gün"}
                  </button>
                ))}
              </div>
            </div>
            <div className="grid gap-3.5 p-5" aria-label="Drop-off bar chart">
              {LABELS.map((label, i) => {
                const value = values[i];
                return (
                  <div key={label} className="grid grid-cols-[110px_minmax(0,1fr)_44px] items-center gap-3 text-[13px] text-text-secondary max-[720px]:grid-cols-[84px_minmax(0,1fr)_42px]">
                    <span className="font-semibold text-text-primary">{label}</span>
                    <span className="h-3 overflow-hidden rounded-full bg-bg-muted">
                      <span
                        className={`block h-full rounded-full transition-all duration-300 ${value < 45 ? "bg-danger" : value < 75 ? "bg-warning" : "bg-accent"}`}
                        style={{ width: `${value}%` }}
                      />
                    </span>
                    <span>{value}%</span>
                  </div>
                );
              })}
            </div>
          </section>

          <section className="animate-surface-in overflow-hidden rounded-[var(--card-radius)] border border-border bg-bg-card shadow-[var(--shadow-sm)] [animation-delay:220ms]">
            <div className="border-b border-border p-5">
              <h2 className="text-xl leading-tight tracking-tight">Kurs taslağı</h2>
              <p className="mt-1.5 text-sm text-text-secondary">Yeni modül ekle, yayınlanmadan önce akışı kontrol et.</p>
            </div>
            <div className="p-5">
              <form className="grid gap-3.5" onSubmit={addModule}>
                <label className="grid gap-1.5">
                  <span className="text-xs font-bold uppercase tracking-[0.08em] text-text-secondary">Kurs başlığı</span>
                  <input defaultValue="Flutter Temelleri" className="min-h-11 rounded-[var(--button-radius)] border border-border px-3 focus:border-accent focus:shadow-[0_0_0_3px_color-mix(in_oklch,var(--accent),transparent_70%)] focus:outline-none" />
                </label>
                <label className="grid gap-1.5">
                  <span className="text-xs font-bold uppercase tracking-[0.08em] text-text-secondary">Yeni modül</span>
                  <input
                    value={moduleTitle}
                    onChange={(e) => setModuleTitle(e.target.value)}
                    placeholder="Örn. State yönetimi pratiği"
                    className="min-h-11 rounded-[var(--button-radius)] border border-border px-3 focus:border-accent focus:shadow-[0_0_0_3px_color-mix(in_oklch,var(--accent),transparent_70%)] focus:outline-none"
                  />
                </label>
                <label className="grid gap-1.5">
                  <span className="text-xs font-bold uppercase tracking-[0.08em] text-text-secondary">Modül tipi</span>
                  <select
                    value={moduleType}
                    onChange={(e) => setModuleType(e.target.value)}
                    className="min-h-11 rounded-[var(--button-radius)] border border-border px-3 focus:border-accent focus:outline-none"
                  >
                    <option>Ders</option>
                    <option>Quiz</option>
                    <option>Ödev</option>
                  </select>
                </label>
                <Button type="submit">Modül ekle</Button>
              </form>
              <div className="mt-4 grid gap-2.5" aria-live="polite">
                {modules.map((mod, index) => (
                  <div key={index} className="grid min-h-[54px] grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded-[var(--card-radius)] border border-border bg-bg-muted p-3">
                    <div>
                      <strong className="block text-sm">{mod.title}</strong>
                      <span className="mt-0.5 block text-xs text-text-secondary">{mod.type}</span>
                    </div>
                    <button
                      type="button"
                      aria-label={`${mod.title} modülünü kaldır`}
                      onClick={() => setModules((prev) => prev.filter((_, j) => j !== index))}
                      className="min-h-[34px] rounded-[var(--button-radius)] border border-border bg-bg-card px-2.5 text-xs font-bold text-text-secondary">
                      Kaldır
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </section>

          <section className="animate-surface-in overflow-hidden rounded-[var(--card-radius)] border border-border bg-bg-card shadow-[var(--shadow-sm)] max-[1050px]:col-span-full">
            <div className="border-b border-border p-5">
              <h2 className="text-xl leading-tight tracking-tight">Yayın kontrol listesi</h2>
              <p className="mt-1.5 text-sm text-text-secondary">Eksik parçaları işaretle; hazır olma yüzdesi canlı güncellenir.</p>
            </div>
            <div className="p-5">
              <div className="grid gap-2.5">
                {[
                  ["Kurs açıklaması", "Türkçe özet ve hedef öğrenci net."],
                  ["Quiz soruları", "3 çoktan seçmeli soru hazır."],
                  ["Video altyazısı", "Mux/HLS entegrasyonu sonrası eklenecek."],
                  ["Ödeme ayarı", "Stripe Checkout ve webhook Faz 2 işi."],
                ].map(([title, desc], i) => (
                  <label key={title} className="grid grid-cols-[22px_minmax(0,1fr)] items-start gap-2.5 rounded-[var(--card-radius)] border border-border bg-bg-card p-3">
                    <input
                      type="checkbox"
                      checked={checks[i]}
                      onChange={(e) => setChecks((prev) => prev.map((c, j) => (j === i ? e.target.checked : c)))}
                      className="mt-0.5 accent-success"
                    />
                    <span>
                      <strong className="block text-sm">{title}</strong>
                      <span className="mt-0.5 block text-xs text-text-secondary">{desc}</span>
                    </span>
                  </label>
                ))}
              </div>
              <div className="mt-4 rounded-[var(--card-radius)] bg-bg-muted p-3.5" aria-label="Yayına hazır olma">
                <div className="flex justify-between gap-3 text-xs font-bold uppercase tracking-[0.07em] text-text-secondary">
                  <span>Hazırlık</span>
                  <span>{readiness}%</span>
                </div>
                <div className="mt-2 h-2 overflow-hidden rounded-full bg-border">
                  <span className="block h-full rounded-full bg-success transition-all duration-300" style={{ width: `${readiness}%` }} />
                </div>
                <p className="mt-3 min-h-8 text-sm font-semibold text-text-secondary">
                  {readiness === 100
                    ? "Yayın öncesi son incelemeye hazır."
                    : `${checks.filter((c) => !c).length} kontrol maddesi bekliyor.`}
                </p>
              </div>
            </div>
          </section>
        </div>
      </main>
    </>
  );
}
