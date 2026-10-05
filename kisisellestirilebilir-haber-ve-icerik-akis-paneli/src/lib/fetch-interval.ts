export const FETCH_INTERVAL_OPTIONS = [5, 15, 30, 60] as const;
export type FetchIntervalMinutes = (typeof FETCH_INTERVAL_OPTIONS)[number];

const STORAGE_KEY = "rss-fetch-interval-min";
const DEFAULT_MINUTES: FetchIntervalMinutes = 15;

export function getFetchIntervalMinutes(): FetchIntervalMinutes {
  if (typeof window === "undefined") return DEFAULT_MINUTES;
  const raw = localStorage.getItem(STORAGE_KEY);
  const n = raw ? Number(raw) : DEFAULT_MINUTES;
  if (FETCH_INTERVAL_OPTIONS.includes(n as FetchIntervalMinutes)) {
    return n as FetchIntervalMinutes;
  }
  return DEFAULT_MINUTES;
}

export function setFetchIntervalMinutes(minutes: FetchIntervalMinutes): void {
  localStorage.setItem(STORAGE_KEY, String(minutes));
}

export function fetchIntervalMs(minutes: FetchIntervalMinutes): number {
  return minutes * 60 * 1000;
}
