export type FlavorSeverity = "error" | "warn" | "info";

export interface FlavorWarning {
  id: string;
  severity: FlavorSeverity;
  title: string;
  message: string;
  pcreNote?: string;
}

interface FlavorRule {
  id: string;
  pattern: RegExp;
  severity: FlavorSeverity;
  title: string;
  message: string;
  pcreNote?: string;
}

const PCRE_ONLY_RULES: FlavorRule[] = [
  {
    id: "pcre-named-py",
    pattern: /\(\?P[<']/,
    severity: "error",
    title: "Python/PCRE grup adı (?P<name>)",
    message: "JavaScript'te named group sözdizimi (?<name>...) şeklindedir; (?P<name>) desteklenmez.",
    pcreNote: "PCRE/Python: (?P<name>...)",
  },
  {
    id: "pcre-anchor-a",
    pattern: /\\A/,
    severity: "error",
    title: "PCRE \\A anchor",
    message: "JavaScript'te \\A yoktur. Metin başı için ^ kullanın (m bayrağı ile satır başı).",
    pcreNote: "PCRE: \\A string başlangıcı",
  },
  {
    id: "pcre-anchor-z",
    pattern: /\\[Zz]/,
    severity: "error",
    title: "PCRE \\Z / \\z anchor",
    message: "JavaScript'te \\Z/\\z yoktur. Metin sonu için $ kullanın.",
    pcreNote: "PCRE: \\Z string sonu",
  },
  {
    id: "pcre-reset-k",
    pattern: /\\K/,
    severity: "error",
    title: "PCRE \\K (match reset)",
    message: "JavaScript regex motoru \\K desteklemez.",
  },
  {
    id: "atomic-group",
    pattern: /\(\?>/,
    severity: "error",
    title: "Atomic grup (?>)",
    message: "Possessive/atomic grup (?>) yalnızca PCRE/Perl'de vardır; JS'te yoktur.",
  },
  {
    id: "branch-reset",
    pattern: /\(\?\|/,
    severity: "error",
    title: "Branch reset (?|...)",
    message: "Branch reset grupları JavaScript'te desteklenmez.",
  },
  {
    id: "quoted-literal",
    pattern: /\\Q/,
    severity: "warn",
    title: "Quoted literal \\Q...\\E",
    message: "\\Q...\\E PCRE özelliğidir. JS'te özel karakterleri manuel kaçırın.",
  },
  {
    id: "conditional",
    pattern: /\(\?\(/,
    severity: "error",
    title: "Koşullu ifade (?(...)...)",
    message: "Koşullu regex grupları JavaScript'te desteklenmez.",
  },
  {
    id: "possessive-quant",
    pattern: /[*+?]\+/,
    severity: "error",
    title: "Possessive quantifier (++  *+  ?+)",
    message: "Possessive nicelendiriciler (++ , *+ , ?+) JavaScript'te yoktur.",
    pcreNote: "PCRE: a++ , a*+ , a?+",
  },
  {
    id: "pcre-comment",
    pattern: /\(\?#/,
    severity: "warn",
    title: "Satır içi yorum (?#...)",
    message: "PCRE yorum sözdizimi (?#...) JavaScript'te geçersizdir.",
  },
  {
    id: "pcre-newline-r",
    pattern: /\\R/,
    severity: "warn",
    title: "Unicode satır sonu \\R",
    message: "\\R PCRE'ye özgüdür. JS'te \\r\\n|\\r|\\n gibi alternatifler kullanın.",
  },
];

export function analyzeFlavorCompatibility(
  pattern: string,
  flags: string
): FlavorWarning[] {
  if (!pattern) return [];

  const warnings: FlavorWarning[] = [];

  for (const rule of PCRE_ONLY_RULES) {
    if (rule.pattern.test(pattern)) {
      warnings.push({
        id: rule.id,
        severity: rule.severity,
        title: rule.title,
        message: rule.message,
        pcreNote: rule.pcreNote,
      });
    }
  }

  if (/\\p[{<]/.test(pattern) && !flags.includes("u")) {
    warnings.push({
      id: "unicode-property",
      severity: "warn",
      title: "Unicode property (\\p{...})",
      message: "\\p{...} kullanımı için u (unicode) bayrağını etkinleştirin.",
    });
  }

  if (/\\k[<']/.test(pattern)) {
    warnings.push({
      id: "backref-named",
      severity: "info",
      title: "Named backreference \\k<name>",
      message: "JS'te \\k<name> modern motorlarda çalışır; eski ortamlarda \\1 kullanın.",
      pcreNote: "PCRE: \\k<name> ve \\k'name'",
    });
  }

  return warnings;
}

/** g bayrağı olmadan kaç eşleşme olacağını tahmin et */
export function countGlobalMatches(
  pattern: string,
  flags: string,
  testText: string
): number | null {
  if (!pattern || !testText || flags.includes("g")) return null;

  try {
    const regex = new RegExp(pattern, flags.includes("g") ? flags : flags + "g");
    let count = 0;
    let lastIndex = -1;
    let match: RegExpExecArray | null;
    const startedAt = Date.now();

    while ((match = regex.exec(testText)) !== null) {
      if (Date.now() - startedAt > 500) break;
      if (regex.lastIndex === lastIndex) {
        regex.lastIndex++;
        continue;
      }
      lastIndex = regex.lastIndex;
      count++;
      if (count > 500) break;
    }

    return count;
  } catch {
    return null;
  }
}
