"use client";

import type { HighlightItem } from "@/types/clip";

const COLORS: Record<string, string> = {
  yellow: "bg-[var(--highlight)]",
  green: "bg-[color-mix(in_srgb,var(--success)_25%,var(--bg-card))]",
  blue: "bg-[color-mix(in_srgb,var(--accent)_15%,var(--bg-card))]",
  pink: "bg-[color-mix(in_srgb,var(--danger)_12%,var(--bg-card))]",
};

type Props = {
  highlights: HighlightItem[];
  onDelete: (id: string) => void;
  onUpdateNote: (id: string, note: string) => void;
};

export default function HighlightPanel({ highlights, onDelete, onUpdateNote }: Props) {
  if (!highlights.length) return null;

  return (
    <aside className="font-sans mt-8 pt-6 border-t border-[var(--border)]">
      <h2 className="text-sm font-semibold mb-3">Vurgular ({highlights.length})</h2>
      <ul className="space-y-3">
        {highlights.map((h) => (
          <li key={h.id} className="rounded-lg border border-[var(--border)] p-3 bg-[var(--bg-card)]">
            <blockquote className={`text-sm px-2 py-1 rounded ${COLORS[h.color] ?? COLORS.yellow}`}>
              {h.text}
            </blockquote>
            <textarea
              className="w-full mt-2 text-xs border border-[var(--border)] rounded-lg p-2 min-h-[60px] resize-y"
              placeholder="Not ekle…"
              defaultValue={h.note ?? ""}
              onBlur={(e) => onUpdateNote(h.id, e.target.value)}
            />
            <button
              type="button"
              onClick={() => onDelete(h.id)}
              className="text-xs text-[var(--danger)] mt-2 cursor-pointer bg-transparent border-0"
            >
              Sil
            </button>
          </li>
        ))}
      </ul>
    </aside>
  );
}
