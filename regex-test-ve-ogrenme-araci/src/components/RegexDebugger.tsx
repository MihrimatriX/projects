"use client";

import { useEffect } from "react";
import { useRegexStore, ExplanationBlock } from "@/lib/store";

const typeLabels: Record<
  ExplanationBlock["type"],
  { name: string; classes: string }
> = {
  anchor: {
    name: "Sınır / Çapa",
    classes: "bg-amber-500/10 text-[var(--warning)] border border-amber-500/20",
  },
  meta: {
    name: "Meta Karakter",
    classes: "bg-[var(--bg-selected)] text-[var(--syntax-quant)] border border-[var(--border)]/20",
  },
  quantifier: {
    name: "Nicelendirici",
    classes: "bg-[var(--success)]/10 text-[var(--success)] border border-emerald-500/20",
  },
  group: {
    name: "Grup",
    classes: "bg-[var(--bg-selected)] text-[var(--accent)] border border-[var(--accent)]/20",
  },
  charClass: {
    name: "Karakter Kümesi",
    classes: "bg-cyan-500/10 text-[var(--syntax-quant)] border border-cyan-500/20",
  },
  char: {
    name: "Karakter",
    classes: "bg-[var(--bg-hover)] text-[var(--text-primary)] border border-[var(--border)]",
  },
};

export default function RegexDebugger() {
  const {
    explanation,
    isValid,
    pattern,
    debugStep,
    nextDebugStep,
    prevDebugStep,
    resetDebugStep,
    setDebugStep,
  } = useRegexStore();

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "F10") {
        e.preventDefault();
        if (e.shiftKey) prevDebugStep();
        else nextDebugStep();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [nextDebugStep, prevDebugStep]);

  if (!isValid) {
    return (
      <EmptyState
        icon="⚠️"
        title="Debugger Kullanılamıyor"
        desc="Regex sözdizimi hatasını giderin, ardından adım adım inceleyebilirsiniz."
      />
    );
  }

  if (!pattern) {
    return (
      <EmptyState
        icon="🐛"
        title="Debugger Hazır"
        desc="Bir regex yazın; her token için ne yaptığını adım adım görün."
      />
    );
  }

  if (explanation.length === 0) {
    return (
      <EmptyState
        icon="🔍"
        title="Adım Bulunamadı"
        desc="Bu kalıp için debugger adımları üretilemedi."
      />
    );
  }

  const current = explanation[debugStep];
  const meta = typeLabels[current.type];
  const progress = ((debugStep + 1) / explanation.length) * 100;

  return (
    <div className="w-full h-full border border-[var(--border)] rounded-lg overflow-hidden bg-[var(--bg-editor)] flex flex-col shadow-inner">
      <div className="flex items-center justify-between px-4 py-2.5 bg-[var(--bg-toolbar)] border-b border-[var(--border)] text-xs font-semibold text-[var(--text-secondary)] select-none">
        <span>🐛 Adım Adım Debugger</span>
        <span className="text-[10px] text-[var(--text-muted)]">
          Adım {debugStep + 1} / {explanation.length} · F10 ileri · Shift+F10 geri
        </span>
      </div>

      <div className="h-1 bg-[var(--bg-sidebar)]">
        <div
          className="h-full bg-[var(--accent)]/70 transition-all duration-200"
          style={{ width: `${progress}%` }}
        />
      </div>

      <div className="flex-1 overflow-auto p-4 flex flex-col gap-4">
        <div className="bg-[var(--bg-editor)] border-2 border-[var(--border-focus)]/40 rounded-lg p-4 flex flex-col gap-3 shadow-lg shadow-[var(--bg-app)]/20">
          <div className="flex items-center flex-wrap gap-2">
            <span className="text-[10px] font-bold text-[var(--accent)] bg-[var(--bg-selected)] px-2 py-0.5 rounded">
              ŞİMDİ
            </span>
            <h4 className="text-sm font-bold text-[var(--text-primary)]">{current.title}</h4>
            <span
              className={`text-[9px] font-semibold px-2 py-0.5 rounded ${meta.classes}`}
            >
              {meta.name}
            </span>
          </div>
          <p className="text-sm text-[var(--text-primary)] leading-relaxed">{current.description}</p>
          {current.contextSnippet && (
            <div className="flex flex-col gap-1">
              <span className="text-[10px] font-bold text-[var(--text-muted)]">TEST METNİ BAĞLAMI</span>
              <code className="bg-[var(--bg-toolbar)] border border-[var(--border)] px-3 py-2 rounded font-mono text-xs text-[var(--syntax-quant)]/90 break-all">
                {current.contextSnippet}
              </code>
            </div>
          )}
          <code className="self-start bg-[var(--bg-toolbar)] border border-[var(--border)] px-3 py-1.5 rounded font-mono text-sm text-[var(--accent)]">
            {current.snippet}
          </code>
        </div>

        {debugStep > 0 && (
          <div className="opacity-60 border-l-2 border-[var(--border)] pl-3 py-1">
            <span className="text-[10px] text-[var(--text-muted)] font-bold">Önceki adım</span>
            <p className="text-xs text-[var(--text-secondary)] mt-0.5">{explanation[debugStep - 1].title}</p>
          </div>
        )}

        {debugStep < explanation.length - 1 && (
          <div className="opacity-50 border-l-2 border-[var(--border)] pl-3 py-1">
            <span className="text-[10px] text-[var(--text-muted)] font-bold">Sonraki adım</span>
            <p className="text-xs text-[var(--text-muted)] mt-0.5">{explanation[debugStep + 1].title}</p>
          </div>
        )}

        <div className="flex flex-wrap gap-2 pt-2 border-t border-[var(--border)]">
          <button
            onClick={prevDebugStep}
            disabled={debugStep === 0}
            className="text-xs px-3 py-1.5 rounded-md bg-[var(--bg-sidebar)] border border-[var(--border)] text-[var(--text-primary)] disabled:opacity-40 hover:border-[var(--border)] cursor-pointer disabled:cursor-not-allowed"
          >
            ← Geri
          </button>
          <button
            onClick={nextDebugStep}
            disabled={debugStep >= explanation.length - 1}
            className="text-xs px-3 py-1.5 rounded-md bg-[var(--bg-selected)] border border-[var(--accent)]/30 text-[var(--accent)] disabled:opacity-40 hover:bg-[var(--accent)]/20 cursor-pointer disabled:cursor-not-allowed"
          >
            İleri →
          </button>
          <button
            onClick={resetDebugStep}
            className="text-xs px-3 py-1.5 rounded-md bg-[var(--bg-sidebar)] border border-[var(--border)] text-[var(--text-muted)] hover:text-[var(--text-primary)] cursor-pointer"
          >
            Başa dön
          </button>
        </div>

        <div className="flex flex-wrap gap-1.5">
          {explanation.map((block, idx) => (
            <button
              key={block.id}
              onClick={() => setDebugStep(idx)}
              title={block.title}
              className={`w-7 h-7 rounded text-[10px] font-bold border cursor-pointer transition-all ${
                idx === debugStep
                  ? "bg-[var(--accent)] text-white border-[var(--accent)]"
                  : idx < debugStep
                    ? "bg-[var(--bg-hover)] text-[var(--text-secondary)] border-[var(--border)] opacity-70"
                    : "bg-[var(--bg-sidebar)] text-[var(--text-muted)] border-[var(--border)] hover:border-[var(--border)]"
              }`}
            >
              {idx + 1}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

function EmptyState({
  icon,
  title,
  desc,
}: {
  icon: string;
  title: string;
  desc: string;
}) {
  return (
    <div className="flex flex-col items-center justify-center p-8 bg-[var(--bg-editor)] border border-[var(--border)] rounded-lg h-full min-h-[250px]">
      <span className="text-4xl mb-3">{icon}</span>
      <span className="text-sm font-semibold text-[var(--text-primary)] mb-1">{title}</span>
      <p className="text-xs text-[var(--text-muted)] text-center max-w-[280px]">{desc}</p>
    </div>
  );
}
