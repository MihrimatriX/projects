export type RedosRisk = "low" | "medium" | "high";

export interface RedosAnalysis {
  risk: RedosRisk;
  reasons: string[];
}

const NESTED_QUANTIFIER =
  /(\([^)]*[+*][^)]*\)[+*?]|[+*?]\)[+*?]|\([^)]*[+*][^)]*\)\{|\(\?:[^)]*[+*][^)]*\)[+*?])/;

const OVERLAPPING_ALTERNATION = /\([^)]*\|[^)]*\)[+*?]/;

const DANGEROUS_PATTERNS: { pattern: RegExp; reason: string }[] = [
  {
    pattern: /\(\?:[^)]*\)\+\+/,
    reason: "Possessive quantifier benzeri iç içe tekrar yapısı",
  },
  {
    pattern: /(\w+\|\w+)[+*]/,
    reason: "Alternatifler üzerinde greedy quantifier (çakışan eşleşme riski)",
  },
  {
    pattern: /\(\.\*\)[+*]/,
    reason: "Dot-star grubu üzerinde quantifier (klasik ReDoS kalıbı)",
  },
  {
    pattern: /\(\.\+\)[+*]/,
    reason: "Dot-plus grubu üzerinde quantifier",
  },
  {
    pattern: /(\([^)]*[+*][^)]*\)){2,}/,
    reason: "Birden fazla quantifier'lı grup zinciri",
  },
];

export function analyzeRedosRisk(pattern: string): RedosAnalysis {
  if (!pattern) {
    return { risk: "low", reasons: [] };
  }

  const reasons: string[] = [];

  if (NESTED_QUANTIFIER.test(pattern)) {
    reasons.push("İç içe quantifier (ör. (a+)+) — geri izleme patlaması riski");
  }

  if (OVERLAPPING_ALTERNATION.test(pattern)) {
    reasons.push("Alternatif gruplar üzerinde quantifier — yavaş eşleşme riski");
  }

  for (const { pattern: re, reason } of DANGEROUS_PATTERNS) {
    if (re.test(pattern)) {
      reasons.push(reason);
    }
  }

  const uniqueReasons = [...new Set(reasons)];

  if (
    NESTED_QUANTIFIER.test(pattern) ||
    uniqueReasons.length >= 2 ||
    DANGEROUS_PATTERNS.some(({ pattern: re }) => re.test(pattern))
  ) {
    return { risk: "high", reasons: uniqueReasons };
  }
  if (uniqueReasons.length === 1) {
    return { risk: "medium", reasons: uniqueReasons };
  }
  return { risk: "low", reasons: [] };
}

export const MATCH_TIMEOUT_MS = 2000;

/** Design-aligned 0–99 score for banner display. */
export function getRedosScore(pattern: string): number {
  if (!pattern.trim()) return 0;
  const { risk, reasons } = analyzeRedosRisk(pattern);
  if (risk === "low") return Math.min(40, 12 + reasons.length * 4);
  if (risk === "medium") return Math.min(74, 55 + reasons.length * 8);
  return Math.min(99, 72 + reasons.length * 6);
}
