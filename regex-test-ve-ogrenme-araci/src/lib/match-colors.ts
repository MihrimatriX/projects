export const MATCH_HIGHLIGHT_CLASSES = [
  "bg-[var(--match-0)] border-b-2 border-[var(--accent)]/70 text-[var(--text-primary)]",
  "bg-[var(--match-1)] border-b-2 border-[var(--success)]/70 text-[var(--text-primary)]",
  "bg-[var(--match-2)] border-b-2 border-[var(--warning)]/70 text-[var(--text-primary)]",
  "bg-[var(--match-3)] border-b-2 border-[var(--error)]/70 text-[var(--text-primary)]",
  "bg-[var(--match-0)] border-b-2 border-[var(--syntax-quant)]/70 text-[var(--text-primary)]",
  "bg-[var(--match-1)] border-b-2 border-[var(--syntax-group)]/70 text-[var(--text-primary)]",
] as const;

export function getMatchHighlightClass(index: number): string {
  return MATCH_HIGHLIGHT_CLASSES[index % MATCH_HIGHLIGHT_CLASSES.length];
}
