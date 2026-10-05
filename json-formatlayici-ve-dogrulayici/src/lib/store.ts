import { create } from "zustand";
import { diffJson, type DiffEntry } from "./json-diff";
import { isLargeJson, JsonError, sortObjectKeys } from "./json-utils";
import { queryJsonPath } from "./jsonpath-query";
import { detectNdjson, formatNdjson, InputMode, minifyNdjson } from "./ndjson";
import {
  parseContent,
  stringifyFormatted,
  stringifyMinified,
} from "./parse/index";
import { findDuplicateKeys, type DuplicateKeyHit } from "./duplicate-keys";
import { stripJsonc } from "./jsonc";
import { runJqLite } from "./jq-lite";
import { repairJson } from "./json-repair";
import { validateAgainstSchema } from "./schema-validate";
import { parseShareHash } from "./share-url";
import { collectAllPaths } from "./tree-flat";

export type { JsonError };
export type { InputMode } from "./ndjson";

export type RecentFile = { name: string; path: string };

const SAMPLE_SCHEMA = `{
  "type": "object",
  "required": ["uygulama", "surum"],
  "properties": {
    "uygulama": { "type": "string" },
    "surum": { "type": "string" },
    "aktif": { "type": "boolean" },
    "ozellikler": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "ad"],
        "properties": {
          "id": { "type": "string" },
          "ad": { "type": "string" },
          "durum": { "type": "string" }
        }
      }
    }
  }
}`;

interface JsonState {
  rawJson: string;
  parsedJson: unknown;
  isValid: boolean;
  error: JsonError | null;
  parseTime: number;
  nodeCount: number;
  fileSize: number;
  isLargeFile: boolean;
  isParsing: boolean;
  searchQuery: string;
  expandedPaths: Set<string>;
  showLargeFileModal: boolean;
  pendingLargeContent: string | null;
  inputMode: InputMode;
  indentSize: 2 | 4;
  jsonPathQuery: string;
  jsonPathHighlight: Set<string>;
  jsonPathCount: number;
  jsonPathError: string | null;
  schemaText: string;
  schemaValid: boolean | null;
  schemaErrors: string[];
  diffLeft: string;
  diffRight: string;
  diffEntries: DiffEntry[];
  /** Son karsilastirmanin hatasi (bos/gecersiz JSON) ya da null. */
  diffError: string | null;
  /** Metinler degistikten sonra karsilastirma calistirildi mi. */
  diffRan: boolean;
  parseRequestId: number;
  allowJsonc: boolean;
  jqExpression: string;
  jqResult: unknown;
  jqError: string | null;
  duplicateKeys: DuplicateKeyHit[];
  isTauriApp: boolean;
  watchedFilePath: string | null;
  fileName: string | null;
  recentFiles: RecentFile[];
  fileChangedExternally: boolean;
  watchEnabled: boolean;

  setRawJson: (json: string) => void;
  loadJsonContent: (content: string, options?: { bypassWarning?: boolean }) => void;
  confirmLargeFileLoad: () => void;
  cancelLargeFileLoad: () => void;
  formatJson: () => void;
  minifyJson: () => void;
  sortKeys: () => void;
  repairAndParse: () => void;
  clearAll: () => void;
  loadDemo: () => void;
  setSearchQuery: (query: string) => void;
  togglePath: (path: string) => void;
  expandAll: () => void;
  collapseAll: () => void;
  setInputMode: (mode: InputMode) => void;
  setIndentSize: (size: 2 | 4) => void;
  setJsonPathQuery: (q: string) => void;
  runJsonPathQuery: () => void;
  setSchemaText: (text: string) => void;
  validateSchema: () => void;
  setDiffLeft: (text: string) => void;
  setDiffRight: (text: string) => void;
  runDiff: () => void;
  applySharePayload: (json: string, mode?: InputMode) => void;
  setQueryExpression: (expr: string) => void;
  setAllowJsonc: (v: boolean) => void;
  runJqLiteQuery: () => void;
  applyJqResultToEditor: () => void;
  loadSampleSchema: () => void;
  setWatchedFilePath: (path: string | null) => void;
  setFileName: (name: string | null) => void;
  addRecentFile: (path: string) => void;
  setFileChangedExternally: (v: boolean) => void;
  setWatchEnabled: (v: boolean) => void;
}

const DEMO_JSON = `{
  "uygulama": "JSON Formatlayıcı ve Doğrulayıcı",
  "surum": "1.1.0",
  "tarih": "2026-06-03",
  "aktif": true,
  "gelistirici": {
    "ad": "Örnek Kullanıcı",
    "beceriler": ["TypeScript", "Next.js", "JSON"],
    "dogrulanmis": true
  },
  "ozellikler": [
    { "id": "fmt", "ad": "Pretty Format", "durum": "hazir" },
    { "id": "tree", "ad": "Ağaç Gezgini", "durum": "hazir" }
  ]
}`;

const INDENT_KEY = "json-formatlayici-indent";
const JSONC_KEY = "json-formatlayici-jsonc";
const RECENT_KEY = "json-formatlayici-recent";
const DRAFT_KEY = "json-formatlayici-draft";
/** Bundan buyuk metin taslak olarak saklanmaz (localStorage kotasi ~5 MB). */
export const MAX_DRAFT_CHARS = 1_000_000;

function readAllowJsonc(): boolean {
  if (typeof window === "undefined") return true;
  return localStorage.getItem(JSONC_KEY) !== "false";
}

function persistAllowJsonc(v: boolean) {
  if (typeof window !== "undefined") localStorage.setItem(JSONC_KEY, String(v));
}

function preprocessForParse(json: string, mode: InputMode, allowJsonc: boolean): string {
  let text = json;
  if (mode === "json" && allowJsonc) text = stripJsonc(text);
  return text;
}

function readRecentFiles(): RecentFile[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(RECENT_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as RecentFile[];
    return Array.isArray(parsed) ? parsed.slice(0, 8) : [];
  } catch {
    return [];
  }
}

function persistRecent(files: RecentFile[]) {
  if (typeof window !== "undefined") {
    localStorage.setItem(RECENT_KEY, JSON.stringify(files.slice(0, 8)));
  }
}

function fileNameFromPath(path: string): string {
  const parts = path.replace(/\\/g, "/").split("/");
  return parts[parts.length - 1] || path;
}

function readIndent(): 2 | 4 {
  if (typeof window === "undefined") return 2;
  return localStorage.getItem(INDENT_KEY) === "4" ? 4 : 2;
}

function persistIndent(size: 2 | 4) {
  if (typeof window !== "undefined") localStorage.setItem(INDENT_KEY, String(size));
}

// Tüm editör değişiklikleri buradan geçer: metin hemen state'e yazılır, (JSONC ise yorumlar
// soyulup) parse edilir. parseRequestId ile yalnızca en son isteğin sonucu uygulanır.
async function applyParse(
  get: () => JsonState,
  set: (partial: Partial<JsonState>) => void,
  json: string,
  mode: InputMode
) {
  const requestId = get().parseRequestId + 1;
  set({ isParsing: true, parseRequestId: requestId, rawJson: json });

  const textToParse = preprocessForParse(json, mode, get().allowJsonc);
  const outcome = await parseContent(textToParse, mode);
  if (get().parseRequestId !== requestId) return;

  const isLarge = isLargeJson(json);

  if (!json.trim()) {
    set({
      isParsing: false,
      parsedJson: null,
      isValid: true,
      error: null,
      parseTime: 0,
      nodeCount: 0,
      fileSize: 0,
      isLargeFile: false,
      schemaValid: null,
      schemaErrors: [],
      jsonPathHighlight: new Set(),
      jsonPathCount: 0,
      duplicateKeys: [],
    });
    return;
  }

  if (outcome.ok) {
    const duplicateKeys =
      mode === "json" && json.trim() ? findDuplicateKeys(json) : [];
    set({
      isParsing: false,
      parsedJson: outcome.parsed,
      isValid: true,
      error: null,
      parseTime: outcome.parseTime,
      nodeCount: outcome.nodeCount,
      fileSize: outcome.fileSize,
      isLargeFile: isLarge,
      duplicateKeys,
    });
    get().runJsonPathQuery();
    if (get().schemaText.trim()) get().validateSchema();
  } else {
    set({
      isParsing: false,
      parsedJson: null,
      isValid: false,
      error: outcome.error,
      parseTime: outcome.parseTime,
      nodeCount: 0,
      fileSize: outcome.fileSize,
      isLargeFile: isLarge,
      jsonPathHighlight: new Set(),
      jsonPathCount: 0,
      duplicateKeys: [],
    });
  }
}

export const useJsonStore = create<JsonState>((set, get) => ({
  rawJson: "",
  parsedJson: null,
  isValid: true,
  error: null,
  parseTime: 0,
  nodeCount: 0,
  fileSize: 0,
  isLargeFile: false,
  isParsing: false,
  searchQuery: "",
  expandedPaths: new Set<string>(["/"]),
  showLargeFileModal: false,
  pendingLargeContent: null,
  inputMode: "json",
  indentSize: 2,
  jsonPathQuery: "$.store.book[*].title",
  jsonPathHighlight: new Set(),
  jsonPathCount: 0,
  jsonPathError: null,
  schemaText: "",
  schemaValid: null,
  schemaErrors: [],
  diffLeft: "",
  diffRight: "",
  diffEntries: [],
  diffError: null,
  diffRan: false,
  parseRequestId: 0,
  allowJsonc: true,
  jqExpression: "$.store.book[*].title",
  jqResult: null,
  jqError: null,
  duplicateKeys: [],
  isTauriApp: false,
  watchedFilePath: null,
  fileName: null,
  recentFiles: [],
  fileChangedExternally: false,
  watchEnabled: true,

  setRawJson: (json) => {
    void applyParse(get, set, json, get().inputMode);
  },

  loadJsonContent: (content, options) => {
    if (!options?.bypassWarning && isLargeJson(content)) {
      set({ pendingLargeContent: content, showLargeFileModal: true });
      return;
    }
    const mode = detectNdjson(content) && get().inputMode === "json" ? "ndjson" : get().inputMode;
    if (mode !== get().inputMode) set({ inputMode: mode });
    void applyParse(get, set, content, mode);
  },

  confirmLargeFileLoad: () => {
    const { pendingLargeContent } = get();
    if (pendingLargeContent) void applyParse(get, set, pendingLargeContent, get().inputMode);
    set({ pendingLargeContent: null, showLargeFileModal: false });
  },

  cancelLargeFileLoad: () => set({ pendingLargeContent: null, showLargeFileModal: false }),

  formatJson: () => {
    const { parsedJson, rawJson, isValid, indentSize, inputMode } = get();
    if (!isValid || !rawJson.trim()) return;
    try {
      const data = parsedJson ?? JSON.parse(rawJson);
      if (inputMode === "ndjson") {
        void applyParse(get, set, formatNdjson(rawJson, indentSize), inputMode);
      } else {
        void applyParse(get, set, stringifyFormatted(data, indentSize, inputMode), inputMode);
      }
    } catch {
      /* keep */
    }
  },

  minifyJson: () => {
    const { parsedJson, rawJson, isValid, inputMode } = get();
    if (!isValid || !rawJson.trim()) return;
    try {
      const data = parsedJson ?? JSON.parse(rawJson);
      if (inputMode === "ndjson") {
        void applyParse(get, set, minifyNdjson(rawJson), inputMode);
      } else {
        void applyParse(get, set, stringifyMinified(data, inputMode), inputMode);
      }
    } catch {
      /* keep */
    }
  },

  sortKeys: () => {
    const { parsedJson, rawJson, isValid, indentSize, inputMode } = get();
    if (!isValid || !rawJson.trim() || inputMode === "ndjson") return;
    try {
      const sorted = sortObjectKeys(parsedJson ?? JSON.parse(rawJson));
      void applyParse(get, set, stringifyFormatted(sorted, indentSize, inputMode), inputMode);
    } catch {
      /* keep */
    }
  },

  repairAndParse: () => {
    const repaired = repairJson(get().rawJson);
    void applyParse(get, set, repaired, get().inputMode);
  },

  clearAll: () => {
    set({
      rawJson: "",
      parsedJson: null,
      isValid: true,
      error: null,
      parseTime: 0,
      nodeCount: 0,
      fileSize: 0,
      isLargeFile: false,
      isParsing: false,
      searchQuery: "",
      expandedPaths: new Set<string>(["/"]),
      showLargeFileModal: false,
      pendingLargeContent: null,
      jsonPathHighlight: new Set(),
      jsonPathCount: 0,
      jsonPathError: null,
      schemaValid: null,
      schemaErrors: [],
      diffEntries: [],
      diffRan: false,
      jqResult: null,
      jqError: null,
      duplicateKeys: [],
      watchedFilePath: null,
      fileName: null,
      inputMode: "json",
    });
  },

  loadDemo: () => {
    void applyParse(get, set, DEMO_JSON, "json");
  },

  setSearchQuery: (query) => set({ searchQuery: query }),

  togglePath: (path) => {
    set((state) => {
      const next = new Set(state.expandedPaths);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return { expandedPaths: next };
    });
  },

  expandAll: () => {
    const { parsedJson } = get();
    if (parsedJson) set({ expandedPaths: collectAllPaths(parsedJson) });
  },

  collapseAll: () => set({ expandedPaths: new Set<string>(["/"]) }),

  setInputMode: (mode) => {
    set({ inputMode: mode });
    const { rawJson } = get();
    if (rawJson.trim()) void applyParse(get, set, rawJson, mode);
  },

  setIndentSize: (size) => {
    persistIndent(size);
    set({ indentSize: size });
  },

  setJsonPathQuery: (q) => set({ jsonPathQuery: q }),

  setQueryExpression: (expr) => set({ jsonPathQuery: expr, jqExpression: expr }),

  runJsonPathQuery: () => {
    const { parsedJson, jsonPathQuery, isValid } = get();
    if (!isValid || parsedJson === null) {
      set({ jsonPathHighlight: new Set(), jsonPathCount: 0, jsonPathError: null });
      return;
    }
    const result = queryJsonPath(parsedJson, jsonPathQuery);
    if (!result.ok) {
      set({
        jsonPathHighlight: new Set(),
        jsonPathCount: 0,
        jsonPathError: result.error,
      });
      return;
    }
    set({
      jsonPathHighlight: new Set(result.paths),
      jsonPathCount: result.count,
      jsonPathError: null,
    });
  },

  setSchemaText: (text) => set({ schemaText: text }),

  validateSchema: () => {
    const { parsedJson, schemaText, isValid } = get();
    if (!schemaText.trim()) {
      set({ schemaValid: null, schemaErrors: [] });
      return;
    }
    if (!isValid || parsedJson === null) {
      set({ schemaValid: false, schemaErrors: ["Önce geçerli JSON gerekli"] });
      return;
    }
    const result = validateAgainstSchema(parsedJson, schemaText);
    set({ schemaValid: result.valid, schemaErrors: result.errors });
  },

  setDiffLeft: (text) => set({ diffLeft: text, diffRan: false, diffError: null }),
  setDiffRight: (text) => set({ diffRight: text, diffRan: false, diffError: null }),

  runDiff: () => {
    const { diffLeft, diffRight } = get();
    const parseSide = (text: string, side: string) => {
      if (!text.trim()) throw new Error(`${side} JSON boş`);
      try {
        return JSON.parse(text);
      } catch (err) {
        throw new Error(`${side} JSON geçersiz: ${err instanceof Error ? err.message : String(err)}`);
      }
    };
    try {
      const entries = diffJson(parseSide(diffLeft, "Sol"), parseSide(diffRight, "Sağ"));
      set({ diffEntries: entries, diffError: null, diffRan: true });
    } catch (err) {
      set({ diffEntries: [], diffError: (err as Error).message, diffRan: true });
    }
  },

  applySharePayload: (json, mode) => {
    if (mode) set({ inputMode: mode });
    void applyParse(get, set, json, mode ?? get().inputMode);
  },

  setAllowJsonc: (v) => {
    persistAllowJsonc(v);
    set({ allowJsonc: v });
    const { rawJson, inputMode } = get();
    if (rawJson.trim()) void applyParse(get, set, rawJson, inputMode);
  },

  runJqLiteQuery: () => {
    const { parsedJson, isValid } = get();
    if (!isValid || parsedJson === null) {
      set({ jqResult: null, jqError: "Geçerli JSON gerekli" });
      return;
    }
    const expr = get().jqExpression.trim();
    // "$" ile baslayan ifadeler JSONPath (eslesme listesi), digerleri jq-lite pipeline.
    if (expr.startsWith("$")) {
      const q = queryJsonPath(parsedJson, expr);
      if (q.ok) set({ jqResult: q.values, jqError: null });
      else set({ jqResult: null, jqError: q.error });
      return;
    }
    const r = runJqLite(parsedJson, expr);
    if (r.ok) set({ jqResult: r.result, jqError: null });
    else set({ jqResult: null, jqError: r.error });
  },

  applyJqResultToEditor: () => {
    const { jqResult, indentSize } = get();
    if (jqResult === null) return;
    void applyParse(get, set, JSON.stringify(jqResult, null, indentSize), "json");
  },

  loadSampleSchema: () => {
    set({ schemaText: SAMPLE_SCHEMA });
    get().validateSchema();
  },

  setWatchedFilePath: (path) => set({ watchedFilePath: path }),
  setFileName: (name) => set({ fileName: name }),

  addRecentFile: (path) => {
    const entry = { name: fileNameFromPath(path), path };
    const next = [entry, ...get().recentFiles.filter((f) => f.path !== path)].slice(0, 8);
    persistRecent(next);
    set({ recentFiles: next });
  },

  setFileChangedExternally: (v) => set({ fileChangedExternally: v }),
  setWatchEnabled: (v) => set({ watchEnabled: v }),
}));

export function initFromStorage() {
  useJsonStore.setState({
    indentSize: readIndent(),
    allowJsonc: readAllowJsonc(),
    recentFiles: readRecentFiles(),
  });
}

export function initFromUrlHash() {
  if (typeof window === "undefined") return;
  const payload = parseShareHash(window.location.hash);
  if (payload) {
    useJsonStore.getState().applySharePayload(payload.j, payload.m);
  } else if (!useJsonStore.getState().rawJson) {
    // Paylasim linki yoksa son oturumdaki editor icerigini geri yukle.
    const draft = readDraft();
    if (draft) useJsonStore.getState().loadJsonContent(draft, { bypassWarning: true });
  }
}

function readDraft(): string {
  try {
    return localStorage.getItem(DRAFT_KEY) ?? "";
  } catch {
    return "";
  }
}

/** Editor icerigini (MAX_DRAFT_CHARS'a kadar) gecikmeli olarak localStorage'a yazar. */
export function startDraftAutosave(delayMs = 500): () => void {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const write = () => {
    timer = undefined;
    const { rawJson } = useJsonStore.getState();
    try {
      if (!rawJson) localStorage.removeItem(DRAFT_KEY);
      else if (rawJson.length <= MAX_DRAFT_CHARS) localStorage.setItem(DRAFT_KEY, rawJson);
    } catch {
      /* kota dolu: taslak saklanmaz, editor etkilenmez */
    }
  };
  // Sayfa/pencere kapanirken bekleyen yazim hemen yapilir (son tuslar kaybolmaz).
  const flush = () => {
    if (timer === undefined) return;
    clearTimeout(timer);
    write();
  };
  const unsubscribe = useJsonStore.subscribe((state, prev) => {
    if (state.rawJson === prev.rawJson) return;
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
