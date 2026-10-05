export type PiiKind = "email" | "phone_tr" | "tckn" | "credit_card" | "iban";

export interface PiiFinding {
  kind: PiiKind;
  label: string;
  count: number;
}

const PII_PATTERNS: { kind: PiiKind; label: string; pattern: RegExp }[] = [
  {
    kind: "email",
    label: "e-posta adresi",
    pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g,
  },
  {
    kind: "phone_tr",
    label: "telefon numarası",
    pattern: /(?:\+90|0)?\s*5\d{2}[\s-]?\d{3}[\s-]?\d{2}[\s-]?\d{2}/g,
  },
  {
    kind: "tckn",
    label: "TC kimlik numarası",
    pattern: /\b[1-9]\d{9}[02468]\b/g,
  },
  {
    kind: "credit_card",
    label: "kart numarası",
    pattern: /\b(?:\d{4}[\s-]?){3}\d{4}\b/g,
  },
  {
    kind: "iban",
    label: "IBAN",
    pattern: /\bTR\d{2}\s?\d{4}\s?\d{4}\s?[\d\s]{1,16}\b/gi,
  },
];

export function detectPii(text: string): PiiFinding[] {
  if (!text.trim()) return [];

  const findings: PiiFinding[] = [];

  for (const { kind, label, pattern } of PII_PATTERNS) {
    const matches = text.match(pattern);
    if (matches && matches.length > 0) {
      findings.push({ kind, label, count: matches.length });
    }
  }

  return findings;
}

export function formatPiiWarning(findings: PiiFinding[]): string {
  if (findings.length === 0) return "";

  const parts = findings.map((f) =>
    f.count > 1 ? `${f.count} ${f.label}` : `1 ${f.label}`
  );

  return `Test metninde ${parts.join(", ")} tespit edildi. Paylaşım linki metni URL'de taşır — gizli veri paylaşmayın.`;
}
