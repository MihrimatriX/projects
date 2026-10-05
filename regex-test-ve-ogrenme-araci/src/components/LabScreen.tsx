"use client";

import Link from "next/link";
import FlavorWarnings from "@/components/FlavorWarnings";
import { Suspense, useCallback, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import RegexEditorLazy from "@/components/RegexEditorLazy";
import TestTextEditorLazy from "@/components/TestTextEditorLazy";
import RegexDebugger from "@/components/RegexDebugger";
import AstTreeView from "@/components/AstTreeView";
import AstExplanation from "@/components/AstExplanation";
import HistoryBootstrap from "@/components/HistoryBootstrap";
import { REGEX_PRESETS, startSessionAutosave, useRegexStore } from "@/lib/store";
import { LARGE_TEXT_THRESHOLD } from "@/lib/regex/position";
import { getRedosScore } from "@/lib/redos";
import { detectPii, formatPiiWarning } from "@/lib/pii";

type MobileTab = "pattern" | "test" | "result";
type DebugTab = "steps" | "tree" | "explain";

const FLAG_KEYS = ["g", "i", "m", "s", "u", "y"] as const;

const PRESET_CHIPS: { id: string; label: string }[] = [
  { id: "email", label: "E-posta" },
  { id: "url", label: "URL" },
  { id: "date_tr", label: "Tarih TR" },
  { id: "phone_tr", label: "Telefon" },
  { id: "ipv4", label: "IPv4" },
];

const SHARE_URL_WARN_LENGTH = 2048;

const SHORTCUTS: [string, string][] = [
  ["Ctrl+Enter", "Yeniden çalıştır"],
  ["Ctrl+Shift+C", "Pattern'i /.../bayrak olarak kopyala"],
  ["Ctrl+Shift+M", "Eşleşmeleri JSON olarak kopyala"],
  ["F10 / Shift+F10", "Debugger: ileri / geri"],
  ["Ctrl+Z / Ctrl+Y", "Editörde geri al / yinele"],
  ["Esc", "Uyarıyı / pencereyi kapat"],
  ["F1", "Bu yardım"],
];

// Son oturum yalnizca ilk acilista (URL'de kalip yoksa) geri yuklenir.
let sessionChecked = false;

function Icon({ children }: { children: React.ReactNode }) {
  return (
    <svg className="h-4 w-4 shrink-0 stroke-current fill-none" viewBox="0 0 24 24" strokeWidth={1.6} aria-hidden>
      {children}
    </svg>
  );
}

function LabContent() {
  const searchParams = useSearchParams();
  const {
    pattern,
    setPattern,
    flags,
    toggleFlag,
    testText,
    setTestText,
    replaceText,
    setReplaceText,
    replacedText,
    matches,
    isValid,
    error,
    isEvaluating,
    matchTimedOut,
    redosRisk,
    redosReasons,
    selectedMatchIndex,
    loadPreset,
    loadPattern,
    loadFromShareLink,
    getShareLink,
    getPatternLiteral,
    getMatchesJson,
    setSelectedMatchIndex,
    loadFromHistory,
    history,
    clearHistoryEntries,
    clearAll,
    rerun,
    restoreSession,
  } = useRegexStore();

  const [mobileTab, setMobileTab] = useState<MobileTab>("pattern");
  const [debugTab, setDebugTab] = useState<DebugTab>("steps");
  const [redosDismissed, setRedosDismissed] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const [shareBusy, setShareBusy] = useState(false);
  const [piiWarning, setPiiWarning] = useState<string | null>(null);
  const [helpOpen, setHelpOpen] = useState(false);
  const [canShare, setCanShare] = useState(false);

  const matchedChars = matches.reduce((sum, m) => sum + m.length, 0);
  const coverage = testText.length > 0 ? Math.round((matchedChars / testText.length) * 100) : null;
  const redosScore = getRedosScore(pattern);
  const showRedos = !redosDismissed && pattern.trim() && redosScore >= 55;
  const showWorker = isEvaluating && testText.length > LARGE_TEXT_THRESHOLD;

  const showToast = useCallback((msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2200);
  }, []);

  useEffect(() => {
    const preset = searchParams.get("preset");
    if (preset) loadPreset(preset);

    const p = searchParams.get("p");
    if (p) loadPattern(p, searchParams.get("f") || "g", searchParams.get("t") || "Örnek metin buraya");

    const s = searchParams.get("s");
    if (s) loadFromShareLink(s);

    if (!sessionChecked) {
      sessionChecked = true;
      if (!preset && !p && !s && !window.location.hash.startsWith("#d=")) restoreSession();
    }
  }, [searchParams, loadPreset, loadPattern, loadFromShareLink, restoreSession]);

  useEffect(() => {
    document.documentElement.dataset.ready = "1"; // istemci hazir (UI testleri bekler)
    return startSessionAutosave();
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const hash = window.location.hash;
    if (!hash.startsWith("#d=")) return;
    try {
      const raw = decodeURIComponent(escape(atob(hash.slice(3))));
      const data = JSON.parse(raw);
      if (data.p) loadPattern(data.p, data.f || "g", data.t || "");
    } catch {
      showToast("Geçersiz paylaşım linki");
    }
  }, [loadPattern, showToast]);

  // Paylasim baglantisi yalnizca web'de anlamli (Electron'da adres app://).
  useEffect(() => setCanShare(window.location.protocol.startsWith("http")), []);

  const copyText = useCallback(
    (text: string, ok: string) =>
      navigator.clipboard.writeText(text).then(
        () => showToast(ok),
        () => showToast("Panoya kopyalanamadı")
      ),
    [showToast]
  );

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const key = e.key.toLowerCase();
      if (e.key === "F1") {
        e.preventDefault();
        setHelpOpen(true);
      } else if (e.key === "Escape") {
        if (helpOpen) setHelpOpen(false);
        else if (showRedos) setRedosDismissed(true);
      } else if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        rerun();
      } else if ((e.ctrlKey || e.metaKey) && e.shiftKey && key === "c") {
        e.preventDefault();
        void copyText(getPatternLiteral(), "Pattern panoya kopyalandı");
      } else if ((e.ctrlKey || e.metaKey) && e.shiftKey && key === "m") {
        e.preventDefault();
        void copyText(getMatchesJson(), "Eşleşmeler (JSON) panoya kopyalandı");
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [showRedos, helpOpen, rerun, copyText, getPatternLiteral, getMatchesJson]);

  const statusClass = !pattern.trim()
    ? "hidden"
    : !isValid
      ? "bg-[var(--error-bg)] text-[var(--error)]"
      : redosRisk !== "low"
        ? "bg-[var(--warning-bg)] text-[var(--warning)]"
        : "bg-[color-mix(in_srgb,var(--success)_8%,var(--bg-app))] text-[var(--success)]";

  const statusText = !pattern.trim()
    ? "Pattern girin"
    : !isValid
      ? "Syntax hatası · pattern düzeltin"
      : !testText.trim()
        ? "Test metni girin"
        : `${redosRisk === "low" ? "ReDoS riski düşük" : redosRisk === "high" ? "ReDoS riski yüksek" : "ReDoS riski orta"} · ${matches.length} eşleşme`;

  const copyPattern = () => {
    void copyText(getPatternLiteral(), "Pattern panoya kopyalandı").then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  };

  const shareLink = () => {
    const link = getShareLink();
    if (link.length > SHARE_URL_WARN_LENGTH) {
      showToast("Paylaşım linki çok uzun — metni kısaltın");
      return;
    }
    const findings = detectPii(testText);
    if (findings.length > 0) {
      setPiiWarning(formatPiiWarning(findings));
      return;
    }
    doShare(link);
  };

  const doShare = (link: string) => {
    setShareBusy(true);
    setTimeout(() => {
      navigator.clipboard.writeText(link).then(
        () => showToast("Paylaşım linki kopyalandı"),
        () => showToast(link)
      );
      setShareBusy(false);
      setPiiWarning(null);
    }, 300);
  };

  // Genis ekran: sol sutunda pattern (ust) + test metni (alt), sagda sonuc paneli iki satiri kaplar.
  const panelClass = (tab: MobileTab) =>
    `flex min-h-0 flex-col border-[var(--border)] bg-[var(--bg-editor)] lg:flex lg:col-start-1 lg:border-r ${
      mobileTab !== tab ? "max-lg:hidden" : "max-lg:flex"
    } ${tab === "pattern" ? "lg:row-start-1 lg:border-b" : "lg:row-start-2"}`;

  return (
    <div className="flex h-dvh flex-col overflow-hidden bg-[var(--bg-app)] text-[13px] leading-snug">
      <HistoryBootstrap />

      <header className="flex h-[var(--header-height)] shrink-0 items-center gap-3 border-b border-[var(--border)] bg-[var(--bg-toolbar)] px-4">
        <span className="whitespace-nowrap text-[15px] font-semibold tracking-tight">Regex Laboratuvarı</span>
        <Link
          href="/cheatsheet"
          className="ml-1 inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-btn)] border border-[var(--border)] px-3 text-[13px] font-medium transition hover:bg-[var(--bg-hover)]"
        >
          <Icon>
            <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
            <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
          </Icon>
          Cheatsheet
        </Link>
        <div className="flex-1" />
        <div className="flex gap-1" role="group" aria-label="Regex bayrakları">
          {FLAG_KEYS.map((key) => {
            const on = flags.includes(key);
            return (
              <button
                key={key}
                type="button"
                aria-pressed={on}
                aria-label={`${key} bayrağı`}
                onClick={() => toggleFlag(key)}
                className={`grid h-7 min-w-7 place-items-center rounded-[var(--radius-chip)] border font-mono text-[11px] font-medium transition ${
                  on
                    ? "border-[color-mix(in_srgb,var(--accent)_40%,var(--border))] bg-[color-mix(in_srgb,var(--accent)_20%,transparent)] text-[var(--text-primary)]"
                    : "border-[var(--border)] text-[var(--text-secondary)] hover:bg-[var(--bg-hover)]"
                }`}
              >
                {key}
              </button>
            );
          })}
        </div>
        <span className="hidden items-center gap-1.5 rounded-[var(--radius-chip)] border border-[var(--border)] bg-[var(--bg-editor)] px-2.5 py-1 text-xs text-[var(--text-secondary)] sm:inline-flex">
          <Icon>
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <path d="M8 12h8M12 8v8" />
          </Icon>
          JS flavor
        </span>
        <button
          type="button"
          onClick={copyPattern}
          className="inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-btn)] border border-[var(--border)] px-3 text-[13px] font-medium transition hover:bg-[var(--bg-hover)] active:scale-[0.98]"
        >
          <Icon>
            <rect x="9" y="9" width="13" height="13" rx="2" />
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
          </Icon>
          {copied ? "Kopyalandı" : "Kopyala"}
        </button>
        {canShare && (
          <button
            type="button"
            disabled={shareBusy || !pattern.trim()}
            onClick={shareLink}
            className="inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-btn)] border border-[var(--border)] px-3 text-[13px] font-medium transition hover:bg-[var(--bg-hover)] active:scale-[0.98] disabled:opacity-50"
          >
            <Icon>
              <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8" />
              <polyline points="16 6 12 2 8 6" />
              <line x1="12" y1="2" x2="12" y2="15" />
            </Icon>
            Paylaş
          </button>
        )}
        <button
          type="button"
          onClick={clearAll}
          title="Pattern ve metni temizle"
          className="inline-flex h-8 items-center gap-1.5 rounded-[var(--radius-btn)] border border-[var(--border)] px-3 text-[13px] font-medium transition hover:bg-[var(--bg-hover)] active:scale-[0.98]"
        >
          Temizle
        </button>
        <button
          type="button"
          onClick={() => setHelpOpen(true)}
          aria-label="Yardım ve kısayollar (F1)"
          title="Yardım (F1)"
          className="inline-flex h-8 w-8 items-center justify-center rounded-[var(--radius-btn)] border border-[var(--border)] text-[13px] font-medium transition hover:bg-[var(--bg-hover)]"
        >
          ?
        </button>
      </header>

      {showRedos && (
        <div
          role="alert"
          className="flex shrink-0 items-center justify-between gap-3 border-b border-[color-mix(in_srgb,var(--warning)_25%,var(--border))] bg-[var(--warning-bg)] px-4 py-2.5 text-[var(--warning)]"
        >
          <p className="flex-1 leading-snug">
            <strong className="tabular-nums">Skor {redosScore}</strong> —{" "}
            {redosReasons[0] ?? "İç içe quantifier tespit edildi; büyük girdilerde eşleştirme yavaşlayabilir."}
          </p>
          <button
            type="button"
            aria-label="Uyarıyı kapat"
            onClick={() => setRedosDismissed(true)}
            className="grid h-7 w-7 shrink-0 place-items-center rounded-[var(--radius-chip)] hover:bg-[color-mix(in_srgb,var(--warning)_15%,transparent)]"
          >
            ×
          </button>
        </div>
      )}

      {showWorker && (
        <div role="status" className="flex shrink-0 items-center gap-2.5 border-b border-[var(--border)] bg-[var(--bg-toolbar)] px-4 py-2 font-medium text-[var(--text-secondary)]">
          <span className="h-3.5 w-3.5 motion-safe:animate-spin rounded-full border-2 border-[var(--border)] border-t-[var(--accent)]" />
          Büyük metin eşleştiriliyor…
        </div>
      )}

      <div role="status" className={`flex shrink-0 items-center gap-3 border-b border-[var(--border)] px-4 py-2 ${statusClass}`}>
        {isValid && pattern && (
          <Icon>
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
            <polyline points="22 4 12 14.01 9 11.01" />
          </Icon>
        )}
        <span>{statusText}</span>
        {matchTimedOut && <span className="text-xs opacity-80">(2 sn zaman aşımı)</span>}
      </div>

      {pattern && <div className="shrink-0 px-4 pb-2"><FlavorWarnings /></div>}

      {piiWarning && (
        <div className="shrink-0 border-b border-[var(--error)]/30 bg-[var(--error-bg)] px-4 py-2 text-xs text-[var(--error)]">
          <p>{piiWarning}</p>
          <div className="mt-2 flex gap-2">
            <button type="button" onClick={() => setPiiWarning(null)} className="rounded border border-[var(--border)] px-2 py-1">
              İptal
            </button>
            <button type="button" onClick={() => doShare(getShareLink())} className="rounded border border-[var(--error)]/50 px-2 py-1">
              Yine de paylaş
            </button>
          </div>
        </div>
      )}

      <div className="hidden shrink-0 flex-wrap gap-2 border-b border-[var(--border)] px-4 py-2 max-lg:hidden lg:flex">
        {PRESET_CHIPS.map((chip) => (
          <button
            key={chip.id}
            type="button"
            onClick={() => loadPreset(chip.id)}
            className="rounded-full border border-[var(--border)] bg-[var(--bg-editor)] px-2.5 py-1 text-[11px] font-medium tracking-wide text-[var(--text-secondary)] transition hover:bg-[var(--bg-hover)] hover:text-[var(--text-primary)]"
          >
            {chip.label}
          </button>
        ))}
        <select
          aria-label="Tüm şablonlar"
          value=""
          onChange={(e) => e.target.value && loadPreset(e.target.value)}
          className="rounded-full border border-[var(--border)] bg-[var(--bg-editor)] px-2.5 py-1 text-[11px] text-[var(--text-secondary)]"
        >
          <option value="">Tüm şablonlar ({REGEX_PRESETS.length})…</option>
          {REGEX_PRESETS.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        {history.length > 0 && (
          <select
            aria-label="Geçmiş kalıplar"
            value=""
            onChange={(e) => {
              if (e.target.value === "__clear") clearHistoryEntries();
              else if (e.target.value) loadFromHistory(e.target.value);
            }}
            className="ml-auto rounded-full border border-[var(--border)] bg-[var(--bg-editor)] px-2.5 py-1 text-[11px] text-[var(--text-secondary)]"
          >
            <option value="">Geçmiş…</option>
            {history.map((h) => (
              <option key={h.id} value={h.id}>
                /{h.pattern.slice(0, 24)}
                {h.pattern.length > 24 ? "…" : ""}/{h.flags}
              </option>
            ))}
            <option value="__clear">Geçmişi temizle</option>
          </select>
        )}
      </div>

      <nav className="flex shrink-0 border-b border-[var(--border)] bg-[var(--bg-toolbar)] lg:hidden" role="tablist" aria-label="Panel sekmeleri">
        {(["pattern", "test", "result"] as const).map((tab) => (
          <button
            key={tab}
            type="button"
            role="tab"
            aria-selected={mobileTab === tab}
            onClick={() => setMobileTab(tab)}
            className={`h-10 flex-1 border-b-2 text-[13px] font-medium tracking-wide ${
              mobileTab === tab
                ? "border-[var(--accent)] text-[var(--text-primary)]"
                : "border-transparent text-[var(--text-secondary)]"
            }`}
          >
            {tab === "pattern" ? "Pattern" : tab === "test" ? "Test" : "Sonuç"}
          </button>
        ))}
      </nav>

      <main className="grid min-h-0 flex-1 max-lg:overflow-auto lg:grid-cols-[1fr_var(--sidebar-width)] lg:grid-rows-[minmax(140px,30%)_1fr] lg:overflow-hidden">
        <section className={panelClass("pattern")}>
          <div className="flex shrink-0 items-center justify-between border-b border-[var(--border)] bg-[var(--bg-toolbar)] px-3 py-2 text-xs font-semibold uppercase tracking-widest text-[var(--text-secondary)]">
            <span>Regular expression</span>
            <span
              className={`h-1.5 w-1.5 rounded-full ${isValid ? "bg-[var(--success)]" : "bg-[var(--error)]"}`}
              role="status"
              aria-label={isValid ? "Geçerli pattern" : "Syntax hatası"}
            />
          </div>
          <div className={`relative min-h-[120px] flex-1 ${!isValid && pattern ? "ring-inset ring-[var(--error)]" : ""}`}>
            <RegexEditorLazy value={pattern} onChange={setPattern} placeholderText="Pattern girin — örn. [\\w.-]+@[\\w.-]+\\.\\w{2,}" />
            {!isValid && error && (
              <p className="absolute bottom-0 left-0 right-0 bg-[var(--error-bg)] px-3 py-1.5 text-xs text-[var(--error)]">{error}</p>
            )}
          </div>
        </section>

        <section className={panelClass("test")}>
          <div className="shrink-0 border-b border-[var(--border)] bg-[var(--bg-toolbar)] px-3 py-2 text-xs font-semibold uppercase tracking-widest text-[var(--text-secondary)]">
            Test metni
          </div>
          <div className="relative min-h-[240px] flex-1">
            <TestTextEditorLazy
              value={testText}
              onChange={setTestText}
              matches={matches}
              isValid={isValid}
              selectedMatchIndex={selectedMatchIndex}
            />
          </div>
        </section>

        <aside
          className={`flex min-h-0 flex-col bg-[var(--bg-sidebar)] lg:col-start-2 lg:row-start-1 lg:row-span-2 lg:flex ${
            mobileTab !== "result" ? "max-lg:hidden" : "max-lg:flex"
          }`}
        >
          <div className="flex min-h-0 flex-1 flex-col">
            <div className="shrink-0 border-b border-[var(--border)] bg-[var(--bg-toolbar)] px-3 py-2 text-xs font-semibold uppercase tracking-widest text-[var(--text-secondary)]">
              Yakalama grupları
            </div>
            <div className="min-h-0 flex-1 overflow-auto p-3">
              <div className="mb-3 flex items-center gap-4 text-xs text-[var(--text-secondary)]">
                <span>
                  Eşleşme: <strong className="tabular-nums text-[var(--text-primary)]">{matches.length}</strong>
                </span>
                <span>
                  Kapsama:{" "}
                  <strong className="tabular-nums text-[var(--text-primary)]">
                    {coverage !== null ? `${coverage}%` : "—"}
                  </strong>
                </span>
                <button
                  type="button"
                  disabled={matches.length === 0}
                  onClick={() => void copyText(getMatchesJson(), "Eşleşmeler (JSON) panoya kopyalandı")}
                  title="Eşleşmeleri ve grupları JSON olarak kopyala (Ctrl+Shift+M)"
                  className="ml-auto rounded border border-[var(--border)] px-2 py-0.5 text-[11px] hover:bg-[var(--bg-hover)] disabled:opacity-40"
                >
                  JSON kopyala
                </button>
              </div>
              <table className="w-full border-collapse text-xs" aria-label="Yakalama grupları">
                <thead>
                  <tr className="border-b border-[var(--border)] text-[var(--text-secondary)]">
                    <th className="py-1.5 text-left font-medium">#</th>
                    <th className="py-1.5 text-left font-medium">Eşleşme</th>
                    <th className="py-1.5 text-left font-medium">Uzunluk</th>
                  </tr>
                </thead>
                <tbody>
                  {matches.length === 0 ? (
                    <tr>
                      <td colSpan={3} className="py-3 italic text-[var(--text-muted)]">
                        {!pattern.trim()
                          ? "Pattern girin — üstteki şablonlardan birini deneyin"
                          : !isValid
                            ? `Syntax hatası: ${error}`
                            : "Eşleşme yok"}
                      </td>
                    </tr>
                  ) : (
                    matches.map((m, i) => (
                      // Satira tiklamak (ya da Enter) eslesmeyi test metninde secer ve gorunur yapar.
                      <tr
                        key={i}
                        tabIndex={0}
                        aria-selected={selectedMatchIndex === i}
                        onClick={() => setSelectedMatchIndex(i)}
                        onKeyDown={(e) => {
                          if (e.key === "Enter" || e.key === " ") {
                            e.preventDefault();
                            setSelectedMatchIndex(i);
                          }
                        }}
                        className={`cursor-pointer border-b border-[var(--border)] align-top hover:bg-[var(--bg-hover)] focus:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-[var(--accent)] ${
                          selectedMatchIndex === i ? "bg-[var(--bg-selected)]" : ""
                        }`}
                      >
                        <td className="py-1.5 font-mono">{i}</td>
                        <td className="max-w-[180px] py-1.5 font-mono">
                          <div className="truncate" title={m.value}>{m.value}</div>
                          {m.groups.map((g) => (
                            <div key={`${g.name ?? g.index}`} className="truncate text-[11px] text-[var(--text-secondary)]" title={g.value}>
                              <span className="text-[var(--syntax-group)]">
                                {[g.index > 0 ? `$${g.index}` : "", g.name ? `<${g.name}>` : ""].filter(Boolean).join(" ")}
                              </span>{" "}
                              {g.value}
                            </div>
                          ))}
                        </td>
                        <td className="py-1.5 font-mono tabular-nums">{m.length}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
              <div className="mt-3 border-t border-[var(--border)] pt-3">
                <label htmlFor="replace-input" className="mb-1.5 block text-[11px] font-semibold uppercase tracking-widest text-[var(--text-secondary)]">
                  Replace önizleme
                </label>
                <input
                  id="replace-input"
                  type="text"
                  value={replaceText}
                  onChange={(e) => setReplaceText(e.target.value)}
                  placeholder="$1@domain"
                  spellCheck={false}
                  className="w-full rounded-[var(--radius-chip)] border border-[var(--border)] bg-[var(--bg-editor)] px-2.5 py-2 font-mono text-xs focus:outline-none focus:ring-2 focus:ring-[var(--accent)]"
                />
                <div
                  data-testid="replace-result"
                  className="mt-2 max-h-20 overflow-auto whitespace-pre-wrap break-words rounded-[var(--radius-chip)] border border-[var(--border)] bg-[var(--bg-editor)] p-2.5 font-mono text-xs text-[var(--text-secondary)]"
                >
                  {replacedText || "—"}
                </div>
                <button
                  type="button"
                  disabled={!replaceText || !replacedText}
                  onClick={() => void copyText(replacedText, "Replace sonucu panoya kopyalandı")}
                  className="mt-2 rounded border border-[var(--border)] px-2 py-0.5 text-[11px] text-[var(--text-secondary)] hover:bg-[var(--bg-hover)] disabled:opacity-40"
                >
                  Sonucu kopyala
                </button>
              </div>
            </div>
          </div>

          <div className="flex max-h-[220px] shrink-0 flex-col border-t border-[var(--border)]">
            <div className="flex shrink-0 items-center justify-between border-b border-[var(--border)] bg-[var(--bg-toolbar)] px-3 py-2">
              <span className="text-xs font-semibold uppercase tracking-widest text-[var(--text-secondary)]">Debugger</span>
              <div className="flex gap-1 text-[10px]">
                {(["steps", "tree", "explain"] as const).map((t) => (
                  <button
                    key={t}
                    type="button"
                    aria-pressed={debugTab === t}
                    onClick={() => setDebugTab(t)}
                    className={`rounded px-1.5 py-0.5 ${debugTab === t ? "bg-[var(--bg-selected)] text-[var(--accent)]" : "text-[var(--text-muted)]"}`}
                  >
                    {t === "steps" ? "Adım" : t === "tree" ? "AST" : "Açıklama"}
                  </button>
                ))}
              </div>
            </div>
            <div className="min-h-0 flex-1 overflow-auto p-2">
              {debugTab === "steps" && <RegexDebugger />}
              {debugTab === "tree" && <AstTreeView />}
              {debugTab === "explain" && <AstExplanation />}
            </div>
          </div>
        </aside>
      </main>

      <footer className="flex shrink-0 items-center justify-between border-t border-[var(--border)] px-4 py-2 text-xs text-[var(--text-muted)]">
        <span className="tabular-nums" aria-live="polite">
          {matchedChars} / {testText.length} karakter işlendi
        </span>
        <span className="hidden sm:inline">
          <kbd className="rounded border border-[var(--border)] bg-[var(--bg-toolbar)] px-1 font-mono text-[11px]">Ctrl</kbd>
          +
          <kbd className="rounded border border-[var(--border)] bg-[var(--bg-toolbar)] px-1 font-mono text-[11px]">Enter</kbd>
          {" "}yeniden çalıştır ·{" "}
          <Link href="/" className="text-[var(--accent-hover)] hover:underline">
            Ana sayfa
          </Link>
        </span>
      </footer>

      {helpOpen && (
        <div className="fixed inset-0 z-40 grid place-items-center bg-black/50 p-4" role="presentation" onClick={() => setHelpOpen(false)}>
          <div
            role="dialog"
            aria-modal="true"
            aria-labelledby="help-title"
            onClick={(e) => e.stopPropagation()}
            className="w-full max-w-md rounded-[var(--radius-panel)] border border-[var(--border)] bg-[var(--bg-toolbar)] p-5 shadow-xl"
          >
            <div className="mb-3 flex items-center justify-between">
              <h2 id="help-title" className="text-sm font-semibold">Klavye kısayolları</h2>
              <button type="button" aria-label="Kapat" onClick={() => setHelpOpen(false)} className="rounded px-2 py-0.5 text-xs hover:bg-[var(--bg-hover)]">
                Esc
              </button>
            </div>
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-[13px]">
              {SHORTCUTS.map(([k, v]) => (
                <div key={k} className="contents">
                  <dt>
                    <kbd className="rounded border border-[var(--border)] bg-[var(--bg-editor)] px-1.5 font-mono text-[11px]">{k}</kbd>
                  </dt>
                  <dd className="text-[var(--text-secondary)]">{v}</dd>
                </div>
              ))}
            </dl>
            <p className="mt-4 text-xs leading-relaxed text-[var(--text-muted)]">
              Eşleşme tablosunda bir satıra tıklamak eşleşmeyi test metninde seçer. Oturum otomatik saklanır;
              son 8 kalıp &quot;Geçmiş&quot; listesindedir.
            </p>
          </div>
        </div>
      )}

      {toast && (
        <div
          role="status"
          className="pointer-events-none fixed bottom-14 left-1/2 z-50 -translate-x-1/2 rounded-[var(--radius-btn)] border border-[var(--border)] bg-[var(--bg-toolbar)] px-4 py-2.5 text-[13px] font-medium shadow-lg"
        >
          {toast}
        </div>
      )}
    </div>
  );
}

export default function LabScreen() {
  return (
    <Suspense
      fallback={
        <div className="flex h-dvh items-center justify-center bg-[var(--bg-app)] text-[var(--accent)]">Yükleniyor…</div>
      }
    >
      <LabContent />
    </Suspense>
  );
}
