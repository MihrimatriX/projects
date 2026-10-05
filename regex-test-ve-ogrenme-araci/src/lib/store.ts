import { create } from "zustand";
import LZString from "lz-string";
import { clearHistory, loadHistory, loadSession, pushHistory, saveSession, type HistoryEntry } from "./history";
import type { RedosRisk } from "./redos";
import {
  evaluateRegex,
  INITIAL_FLAGS,
  INITIAL_PATTERN,
  INITIAL_REPLACE_TEXT,
  INITIAL_TEST_TEXT,
} from "./regex/evaluate";
import { runEvaluation } from "./regex/evaluate-worker-client";
import { REGEX_PRESETS } from "./regex/presets";
import type {
  AstTreeNode,
  ExplanationBlock,
  MatchGroup,
  RegexMatch,
} from "./regex/types";
import type { FlavorWarning } from "./regex/flavor";

export type { MatchGroup, RegexMatch, ExplanationBlock, AstTreeNode, HistoryEntry, FlavorWarning };
export { REGEX_PRESETS };

interface RegexState {
  pattern: string;
  flags: string;
  testText: string;
  replaceText: string;
  isValid: boolean;
  error: string | null;
  matches: RegexMatch[];
  explanation: ExplanationBlock[];
  astTree: AstTreeNode[];
  replacedText: string;
  redosRisk: RedosRisk;
  redosReasons: string[];
  matchTimedOut: boolean;
  flavorWarnings: FlavorWarning[];
  globalMatchHint: number | null;
  debugStep: number;
  selectedMatchIndex: number | null;
  history: HistoryEntry[];
  isEvaluating: boolean;

  setPattern: (pattern: string) => void;
  setFlags: (flags: string) => void;
  setTestText: (text: string) => void;
  setReplaceText: (text: string) => void;
  toggleFlag: (flag: string) => void;
  loadPreset: (presetId: string) => void;
  loadPattern: (pattern: string, flags?: string, testText?: string) => void;
  loadFromShareLink: (hash: string) => void;
  loadFromHistory: (entryId: string) => void;
  refreshHistory: () => void;
  clearHistoryEntries: () => void;
  getShareLink: () => string;
  getPatternLiteral: () => string;
  getMatchesJson: () => string;
  clearAll: () => void;
  rerun: () => void;
  restoreSession: () => boolean;
  setSelectedMatchIndex: (index: number | null) => void;
  setDebugStep: (step: number) => void;
  nextDebugStep: () => void;
  prevDebugStep: () => void;
  resetDebugStep: () => void;
}

const INITIAL_EVAL = evaluateRegex(
  INITIAL_PATTERN,
  INITIAL_FLAGS,
  INITIAL_TEST_TEXT,
  INITIAL_REPLACE_TEXT
);

let historyDebounceTimer: ReturnType<typeof setTimeout> | null = null;
let evalGeneration = 0;

function scheduleHistorySave(get: () => RegexState, set: (partial: Partial<RegexState>) => void) {
  if (typeof window === "undefined") return;
  if (historyDebounceTimer) clearTimeout(historyDebounceTimer);
  historyDebounceTimer = setTimeout(() => {
    const { pattern, flags, testText } = get();
    if (pattern.trim()) {
      set({ history: pushHistory({ pattern, flags, testText }) });
    }
  }, 2000);
}

function applyResult(
  set: (partial: Partial<RegexState>) => void,
  result: ReturnType<typeof evaluateRegex>,
  extra: Partial<RegexState> = {},
  saveHistory = false,
  get?: () => RegexState
) {
  set({
    ...result,
    debugStep: 0,
    selectedMatchIndex: result.matches.length > 0 ? 0 : null,
    ...extra,
  });

  if (saveHistory && get) {
    const { pattern, flags, testText } = { ...get(), ...extra };
    if (pattern.trim() && typeof window !== "undefined") {
      set({ history: pushHistory({ pattern, flags, testText }) });
    }
  }
}

// Tüm değerlendirmeler buradan geçer: kuşak (generation) sayacı geç gelen eski sonuçları atar,
// riskli kalıp / büyük metin runEvaluation içinde Web Worker'a gider (ana thread donmaz).
function triggerEvaluation(
  set: (partial: Partial<RegexState>) => void,
  get: () => RegexState,
  extra: Partial<RegexState> = {},
  saveHistory = false
) {
  const gen = ++evalGeneration;
  const merged = { ...get(), ...extra };
  const { pattern, flags, testText, replaceText } = merged;

  set({ ...extra, isEvaluating: true });

  runEvaluation(pattern, flags, testText, replaceText).then((result) => {
    if (gen !== evalGeneration) return;
    applyResult(set, result, extra, saveHistory, get);
    set({ isEvaluating: false });
  });
}

export const useRegexStore = create<RegexState>((set, get) => ({
  pattern: INITIAL_PATTERN,
  flags: INITIAL_FLAGS,
  testText: INITIAL_TEST_TEXT,
  replaceText: INITIAL_REPLACE_TEXT,
  debugStep: 0,
  selectedMatchIndex: INITIAL_EVAL.matches.length > 0 ? 0 : null,
  history: [],
  isEvaluating: false,
  ...INITIAL_EVAL,

  setPattern: (pattern) => {
    triggerEvaluation(set, get, { pattern });
    scheduleHistorySave(get, set);
  },

  setFlags: (flags) => {
    triggerEvaluation(set, get, { flags });
    scheduleHistorySave(get, set);
  },

  setTestText: (testText) => {
    triggerEvaluation(set, get, { testText });
    scheduleHistorySave(get, set);
  },

  setReplaceText: (replaceText) => {
    triggerEvaluation(set, get, { replaceText });
  },

  toggleFlag: (flag) => {
    const { flags } = get();
    const nextFlags = flags.includes(flag) ? flags.replace(flag, "") : flags + flag;
    get().setFlags(nextFlags);
  },

  loadPreset: (presetId) => {
    const preset = REGEX_PRESETS.find((p) => p.id === presetId);
    if (!preset) return;

    triggerEvaluation(
      set,
      get,
      { pattern: preset.pattern, flags: preset.flags, testText: preset.testText },
      true
    );
  },

  loadPattern: (pattern, flags = "g", testText = "Örnek metin buraya") => {
    // URL'den (?p=, #d=) gelen kalıp güvenilmez: senkron değerlendirme ReDoS ile sekmeyi dondurabilir
    triggerEvaluation(set, get, { pattern, flags, testText });
  },

  loadFromHistory: (entryId) => {
    const entry = get().history.find((item) => item.id === entryId);
    if (!entry) return;

    triggerEvaluation(
      set,
      get,
      { pattern: entry.pattern, flags: entry.flags, testText: entry.testText },
      true
    );
  },

  refreshHistory: () => set({ history: loadHistory() }),

  clearHistoryEntries: () => {
    clearHistory();
    set({ history: [] });
  },

  getShareLink: () => {
    const { pattern, flags, testText } = get();
    const state = { p: pattern, f: flags, t: testText };
    const compressed = LZString.compressToEncodedURIComponent(JSON.stringify(state));
    if (typeof window !== "undefined") {
      return `${window.location.origin}${window.location.pathname}?s=${compressed}`;
    }
    return `?s=${compressed}`;
  },

  getPatternLiteral: () => {
    const { pattern, flags } = get();
    const escaped = pattern.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    return `/${escaped}/${flags}`;
  },

  getMatchesJson: () => {
    const { matches, pattern, flags } = get();
    return JSON.stringify({ pattern, flags, matches }, null, 2);
  },

  loadFromShareLink: (hash) => {
    try {
      const decompressed = LZString.decompressFromEncodedURIComponent(hash);
      if (!decompressed) return;

      const state = JSON.parse(decompressed);
      if (state?.p !== undefined) {
        triggerEvaluation(
          set,
          get,
          { pattern: state.p, flags: state.f || "", testText: state.t || "" },
          true
        );
      }
    } catch {
      // Ignore invalid share links
    }
  },

  clearAll: () => {
    evalGeneration++; // bekleyen (worker) degerlendirme sonucu temizlenen ekrani ezmesin
    set({
      pattern: "",
      flags: "g",
      testText: "",
      replaceText: "",
      isValid: true,
      error: null,
      matches: [],
      explanation: [],
      astTree: [],
      replacedText: "",
      redosRisk: "low",
      redosReasons: [],
      matchTimedOut: false,
      flavorWarnings: [],
      globalMatchHint: null,
      debugStep: 0,
      selectedMatchIndex: null,
      isEvaluating: false,
    });
  },

  rerun: () => triggerEvaluation(set, get),

  restoreSession: () => {
    const session = loadSession();
    if (!session) return false;
    triggerEvaluation(set, get, session);
    return true;
  },

  setSelectedMatchIndex: (index) => set({ selectedMatchIndex: index }),

  setDebugStep: (step) => {
    const max = Math.max(0, get().explanation.length - 1);
    set({ debugStep: Math.min(Math.max(0, step), max) });
  },

  nextDebugStep: () => {
    const { debugStep, explanation } = get();
    if (explanation.length === 0) return;
    set({ debugStep: Math.min(debugStep + 1, explanation.length - 1) });
  },

  prevDebugStep: () => {
    set({ debugStep: Math.max(0, get().debugStep - 1) });
  },

  resetDebugStep: () => set({ debugStep: 0 }),
}));

/** Pattern/bayrak/metin degisikliklerini gecikmeli olarak oturum kaydina yazar. */
export function startSessionAutosave(delayMs = 500): () => void {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const write = () => {
    timer = undefined;
    const s = useRegexStore.getState();
    saveSession({ pattern: s.pattern, flags: s.flags, testText: s.testText, replaceText: s.replaceText });
  };
  // Sayfa/pencere kapanirken bekleyen kayit hemen yazilir (son tuslar kaybolmaz).
  const flush = () => {
    if (timer === undefined) return;
    clearTimeout(timer);
    write();
  };
  const unsubscribe = useRegexStore.subscribe((s, prev) => {
    if (
      s.pattern === prev.pattern &&
      s.flags === prev.flags &&
      s.testText === prev.testText &&
      s.replaceText === prev.replaceText
    )
      return;
    clearTimeout(timer);
    timer = setTimeout(write, delayMs);
  });
  const win = typeof window !== "undefined" && typeof window.addEventListener === "function" ? window : null;
  win?.addEventListener("pagehide", flush);
  return () => {
    win?.removeEventListener("pagehide", flush);
    clearTimeout(timer);
    unsubscribe();
  };
}
