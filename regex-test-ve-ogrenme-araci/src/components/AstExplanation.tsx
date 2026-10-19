"use client";

import { useRegexStore, ExplanationBlock } from "@/lib/store";

export default function AstExplanation() {
  const { explanation, isValid, pattern, debugStep } = useRegexStore();

  const typeLabels: { [key in ExplanationBlock["type"]]: { name: string; classes: string } } = {
    anchor: { name: "Sınır / Çapa", classes: "bg-amber-500/10 text-[var(--warning)] border border-amber-500/20" },
    meta: { name: "Meta Karakter", classes: "bg-[var(--bg-selected)] text-[var(--syntax-quant)] border border-[var(--border)]/20" },
    quantifier: { name: "Nicelendirici", classes: "bg-[var(--success)]/10 text-[var(--success)] border border-emerald-500/20" },
    group: { name: "Grup", classes: "bg-[var(--bg-selected)] text-[var(--accent)] border border-[var(--accent)]/20" },
    charClass: { name: "Karakter Kümesi", classes: "bg-cyan-500/10 text-[var(--syntax-quant)] border border-cyan-500/20" },
    char: { name: "Karakter", classes: "bg-[var(--bg-hover)] text-[var(--text-primary)] border border-[var(--border)]" }
  };

  if (!isValid) {
    return (
      <div className="flex flex-col items-center justify-center p-8 bg-[var(--bg-editor)] border border-[var(--border)] rounded-lg h-full min-h-[300px]">
        <span className="text-4xl mb-3">⚠️</span>
        <span className="text-sm font-semibold text-[var(--text-secondary)] mb-1">Açıklama Oluşturulamadı</span>
        <p className="text-xs text-[var(--text-muted)] text-center max-w-[280px]">
          Lütfen açıklamayı görmek için regex syntax hatalarını giderin.
        </p>
      </div>
    );
  }

  if (!pattern) {
    return (
      <div className="flex flex-col items-center justify-center p-8 bg-[var(--bg-editor)] border border-[var(--border)] rounded-lg h-full min-h-[300px]">
        <span className="text-4xl mb-3">📖</span>
        <span className="text-sm font-semibold text-[var(--text-primary)] mb-1">Regex Sözlüğü Hazır</span>
        <p className="text-xs text-[var(--text-muted)] text-center max-w-[280px]">
          Yukarıdaki kutuya bir regex yazıp adım adım ne anlama geldiğini Türkçe okuyun.
        </p>
      </div>
    );
  }

  return (
    <div className="w-full h-full border border-[var(--border)] rounded-lg overflow-hidden bg-[var(--bg-editor)] flex flex-col shadow-inner select-text">
      {/* Header title */}
      <div className="flex items-center justify-between px-4 py-2.5 bg-[var(--bg-toolbar)] border-b border-[var(--border)] text-xs font-semibold text-[var(--text-secondary)] select-none">
        <span className="flex items-center gap-1.5">
          📖 Adım Adım Regex Açıklaması
        </span>
        <span className="text-[10px] text-[var(--text-muted)]">
          AST Çözümleyici
        </span>
      </div>

      {/* Explanations List Container */}
      <div className="flex-1 overflow-auto p-4 space-y-3">
        {explanation.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-xs text-[var(--text-muted)]">
              Bu kalıp için detaylı AST açıklaması çıkarılamadı. Basit karakterler veya genel arama yapılıyor olabilir.
            </p>
          </div>
        ) : (
          explanation.map((block, idx) => {
            const meta = typeLabels[block.type] || typeLabels.char;
            return (
              <div 
                key={block.id || idx}
                className={`bg-[var(--bg-editor)] border rounded-lg p-3.5 flex items-start gap-4 transition-all duration-200 ${
                  idx === debugStep
                    ? "border-[var(--accent)]/50 shadow-md shadow-[var(--bg-app)]/10"
                    : "border-[var(--border)] hover:border-[var(--border)]"
                } ${idx < debugStep ? "opacity-60" : ""}`}
              >
                {/* Node counter */}
                <span className="w-5 h-5 rounded-full bg-[var(--bg-sidebar)] border border-[var(--border)] flex items-center justify-center text-[10px] text-[var(--text-muted)] font-bold select-none mt-0.5">
                  {idx + 1}
                </span>

                {/* Info block */}
                <div className="flex-1 flex flex-col gap-1">
                  <div className="flex items-center flex-wrap gap-2">
                    <h4 className="text-xs font-bold text-[var(--text-primary)]">
                      {block.title}
                    </h4>
                    <span className={`text-[9px] font-semibold px-2 py-0.5 rounded ${meta.classes} select-none`}>
                      {meta.name}
                    </span>
                  </div>
                  <p className="text-xs text-[var(--text-secondary)] leading-relaxed font-sans">
                    {block.description}
                  </p>
                </div>

                {/* Match snippet */}
                <div className="bg-[var(--bg-toolbar)] border border-[var(--border)] px-2.5 py-1.5 rounded font-mono text-xs font-semibold text-[var(--accent)] select-all shrink-0">
                  {block.snippet}
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}
