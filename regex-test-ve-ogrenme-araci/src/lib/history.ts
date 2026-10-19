export interface HistoryEntry {
  id: string;
  pattern: string;
  flags: string;
  testText: string;
  savedAt: number;
}

const STORAGE_KEY = "regex-lab-history";
const MAX_ENTRIES = 8;

export function loadHistory(): HistoryEntry[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as HistoryEntry[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function pushHistory(entry: Pick<HistoryEntry, "pattern" | "flags" | "testText">): HistoryEntry[] {
  if (typeof window === "undefined" || !entry.pattern.trim()) return loadHistory();

  const existing = loadHistory().filter(
    (item) => !(item.pattern === entry.pattern && item.flags === entry.flags)
  );

  const next: HistoryEntry[] = [
    {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
      ...entry,
      savedAt: Date.now(),
    },
    ...existing,
  ].slice(0, MAX_ENTRIES);

  localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  return next;
}

export function clearHistory(): void {
  if (typeof window === "undefined") return;
  localStorage.removeItem(STORAGE_KEY);
}

// Son oturum (pattern, bayraklar, metinler): uygulama yeniden acildiginda geri yuklenir.
export interface SessionState {
  pattern: string;
  flags: string;
  testText: string;
  replaceText: string;
}

const SESSION_KEY = "regex-lab-session";
/** Bundan uzun test metni oturuma yazilmaz (localStorage kotasi). */
export const MAX_SESSION_TEXT = 200_000;

export function loadSession(): SessionState | null {
  if (typeof localStorage === "undefined") return null;
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const s = JSON.parse(raw) as Partial<SessionState>;
    if (typeof s.pattern !== "string" || typeof s.testText !== "string") return null;
    return { pattern: s.pattern, flags: s.flags ?? "g", testText: s.testText, replaceText: s.replaceText ?? "" };
  } catch {
    return null;
  }
}

export function saveSession(state: SessionState): void {
  if (typeof localStorage === "undefined" || state.testText.length > MAX_SESSION_TEXT) return;
  try {
    localStorage.setItem(SESSION_KEY, JSON.stringify(state));
  } catch {
    /* kota dolu: oturum saklanmaz */
  }
}
