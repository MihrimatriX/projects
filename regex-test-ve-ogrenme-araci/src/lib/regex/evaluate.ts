import { analyzeRedosRisk, MATCH_TIMEOUT_MS } from "../redos";
import { enrichExplanationContext } from "./context";
import { parsePatternAst } from "./explain";
import { analyzeFlavorCompatibility, countGlobalMatches } from "./flavor";
import { indexToPosition } from "./position";
import type { EvaluateResult, MatchGroup, RegexMatch } from "./types";

/**
 * Kaynaktaki yakalayan gruplarin sirali adlari (adsiz grup -> null). Kacislar ve [...] icindeki
 * parantezler atlanir; (?: (?= (?! (?<= (?<! yakalamaz. Ad, numarali grupla eslestirmek icin kullanilir.
 */
export function capturingGroupNames(source: string): (string | null)[] {
  const names: (string | null)[] = [];
  let inClass = false;
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    if (c === "\\") {
      i++;
    } else if (inClass) {
      if (c === "]") inClass = false;
    } else if (c === "[") {
      inClass = true;
    } else if (c === "(") {
      if (source[i + 1] !== "?") names.push(null);
      else if (source[i + 2] === "<" && source[i + 3] !== "=" && source[i + 3] !== "!") {
        const end = source.indexOf(">", i + 3);
        names.push(end > 0 ? source.slice(i + 3, end) : null);
      }
    }
  }
  return names;
}

function collectGroups(match: RegExpExecArray, flags: string, names?: (string | null)[]): MatchGroup[] {
  const groups: MatchGroup[] = [];
  const hasIndices = flags.includes("d") && "indices" in match && match.indices;
  // Ayrıştırıcı grup sayısında motorla uyuşuyorsa adlı gruplar numaralı gruba ad olarak eklenir (çift satır olmaz).
  const named = names && names.length === match.length - 1 ? names : null;

  for (let i = 1; i < match.length; i++) {
    if (match[i] !== undefined) {
      const group: MatchGroup = { index: i, value: match[i] };
      if (named?.[i - 1]) group.name = named[i - 1]!;
      if (hasIndices && match.indices?.[i]) {
        group.start = match.indices[i]![0];
        group.end = match.indices[i]![1];
      }
      groups.push(group);
    }
  }

  const matchGroups = match.groups;
  if (matchGroups && !named) {
    Object.keys(matchGroups).forEach((key) => {
      if (matchGroups[key] !== undefined) {
        const group: MatchGroup = { index: -1, value: matchGroups[key], name: key };
        if (hasIndices && match.indices?.groups?.[key]) {
          group.start = match.indices.groups[key]![0];
          group.end = match.indices.groups[key]![1];
        }
        groups.push(group);
      }
    });
  }

  return groups;
}

function buildMatch(match: RegExpExecArray, testText: string, flags: string, names?: (string | null)[]): RegexMatch {
  const { line, column } = indexToPosition(testText, match.index);
  return {
    index: match.index,
    length: match[0].length,
    value: match[0],
    line,
    column,
    groups: collectGroups(match, flags, names),
  };
}

function translateError(errMsg: string): string {
  let msg = errMsg;
  if (msg.includes("Invalid regular expression")) {
    msg = msg.replace("Invalid regular expression: ", "");
  }

  const translations: Record<string, string> = {
    "Nothing to repeat": "Tekrarlanacak bir nesne belirtilmedi (+, * veya ? öncesi boş)",
    "Unterminated group": "Kapatılmamış grup parantezi (Eksik ')')",
    "Unterminated character class": "Kapatılmamış karakter sınıfı (Eksik ']')",
    "Invalid escape": "Geçersiz kaçış (escape) dizisi",
    "numbers out of order in {} quantifier":
      "Nicelendirici süslü parantezlerinde {min,max} aralık sırası geçersiz",
  };

  Object.keys(translations).forEach((key) => {
    if (msg.toLowerCase().includes(key.toLowerCase())) {
      msg = translations[key];
    }
  });

  return msg;
}

export function evaluateRegex(
  pattern: string,
  flags: string,
  testText: string,
  replaceText: string
): EvaluateResult {
  const { risk: redosRisk, reasons: redosReasons } = analyzeRedosRisk(pattern);

  const flavorWarnings = analyzeFlavorCompatibility(pattern, flags);

  if (!pattern) {
    return {
      isValid: true,
      error: null,
      matches: [],
      explanation: [],
      astTree: [],
      replacedText: testText,
      redosRisk,
      redosReasons,
      matchTimedOut: false,
      flavorWarnings,
      globalMatchHint: null,
    };
  }

  const { explanation, astTree } = parsePatternAst(pattern);

  try {
    const regex = new RegExp(pattern, flags);
    const names = capturingGroupNames(pattern);
    const matches: RegexMatch[] = [];
    let replacedText = testText;
    let matchTimedOut = false;
    const startedAt = Date.now();

    try {
      replacedText = testText.replace(regex, replaceText);
    } catch {
      // Ignore replacement errors
    }

    if (flags.includes("g")) {
      let match: RegExpExecArray | null;
      let lastIndex = -1;

      while ((match = regex.exec(testText)) !== null) {
        if (Date.now() - startedAt > MATCH_TIMEOUT_MS) {
          matchTimedOut = true;
          break;
        }

        if (regex.lastIndex === lastIndex) {
          regex.lastIndex++;
          continue;
        }
        lastIndex = regex.lastIndex;

        matches.push(buildMatch(match, testText, flags, names));
      }
    } else {
      const match = regex.exec(testText);
      if (match) {
        matches.push(buildMatch(match, testText, flags, names));
      }
    }

    const globalTotal = countGlobalMatches(pattern, flags, testText);
    const globalMatchHint =
      globalTotal !== null && globalTotal > matches.length ? globalTotal : null;

    const enrichedExplanation = enrichExplanationContext(explanation, testText, matches);

    return {
      isValid: true,
      error: null,
      matches,
      explanation: enrichedExplanation,
      astTree,
      replacedText,
      redosRisk,
      redosReasons,
      matchTimedOut,
      flavorWarnings,
      globalMatchHint,
    };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : "Bilinmeyen regex hatası";

    return {
      isValid: false,
      error: translateError(message),
      matches: [],
      explanation: [],
      astTree: [],
      replacedText: testText,
      redosRisk,
      redosReasons,
      matchTimedOut: false,
      flavorWarnings,
      globalMatchHint: null,
    };
  }
}

export const INITIAL_PATTERN = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";
export const INITIAL_FLAGS = "g";
export const INITIAL_TEST_TEXT =
  "Destek ekibimize support@masterstudio.dev adresinden, satış departmanına ise sales@example.com üzerinden ulaşabilirsiniz.";
export const INITIAL_REPLACE_TEXT = "[E-POSTA GİZLENDİ]";
