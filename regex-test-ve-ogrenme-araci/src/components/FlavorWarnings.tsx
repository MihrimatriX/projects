"use client";

import { useRegexStore } from "@/lib/store";
import type { FlavorWarning } from "@/lib/regex/flavor";

const severityStyles: Record<FlavorWarning["severity"], string> = {
  error: "border-red-500/40 bg-[var(--error-bg)] text-red-200",
  warn: "border-[var(--warning)]/30 bg-yellow-950/15 text-yellow-100",
  info: "border-sky-500/30 bg-sky-950/15 text-sky-100",
};

export default function FlavorWarnings() {
  const { flavorWarnings, globalMatchHint, flags, toggleFlag, isValid, pattern } =
    useRegexStore();

  if (!pattern) return null;

  const showGlobalHint =
    isValid && globalMatchHint !== null && globalMatchHint > 1 && !flags.includes("g");

  if (flavorWarnings.length === 0 && !showGlobalHint) return null;

  return (
    <div className="flex flex-col gap-2 mt-1">
      {showGlobalHint && (
        <div className="rounded-lg border border-indigo-500/30 bg-indigo-950/20 px-3.5 py-3 flex items-start gap-3">
          <span className="text-indigo-300 text-sm">ℹ️</span>
          <div className="flex-1 flex flex-col gap-1.5">
            <p className="text-xs text-indigo-100/90 leading-relaxed">
              <b>g</b> bayrağı kapalı — yalnızca ilk eşleşme gösteriliyor. Global arama ile{" "}
              <b>{globalMatchHint}</b> eşleşme bulunabilir.
            </p>
            <button
              type="button"
              onClick={() => toggleFlag("g")}
              className="self-start text-[10px] px-2.5 py-1 rounded bg-indigo-500/20 border border-indigo-500/40 text-indigo-200 hover:bg-indigo-500/30 cursor-pointer"
            >
              g bayrağını aç
            </button>
          </div>
        </div>
      )}

      {flavorWarnings.length > 0 && (
        <div className="rounded-lg border border-violet-500/30 bg-violet-950/15 px-3.5 py-3 flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <span className="text-violet-300 text-sm">🔄</span>
            <h4 className="text-xs font-bold text-violet-200">
              Flavor uyarısı — JavaScript vs PCRE
            </h4>
          </div>
          <ul className="space-y-2">
            {flavorWarnings.map((w) => (
              <li
                key={w.id}
                className={`rounded-md border px-3 py-2 text-xs leading-relaxed ${severityStyles[w.severity]}`}
              >
                <span className="font-bold block mb-0.5">{w.title}</span>
                <span className="opacity-90">{w.message}</span>
                {w.pcreNote && (
                  <span className="block mt-1 text-[10px] opacity-70 font-mono">{w.pcreNote}</span>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
