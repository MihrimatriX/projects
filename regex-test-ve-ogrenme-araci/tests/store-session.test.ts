import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MAX_SESSION_TEXT } from "@/lib/history";
import { startSessionAutosave, useRegexStore } from "@/lib/store";

const settle = () => new Promise((r) => setTimeout(r, 0));

describe("store: oturum, temizle, yeniden calistir", () => {
  let storage: Map<string, string>;

  beforeEach(() => {
    storage = new Map();
    vi.stubGlobal("localStorage", {
      getItem: (k: string) => storage.get(k) ?? null,
      setItem: (k: string, v: string) => void storage.set(k, v),
      removeItem: (k: string) => void storage.delete(k),
    });
  });
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it("oturum kaydedilir ve geri yuklenir; cok uzun metin yazilmaz", async () => {
    vi.useFakeTimers();
    const stop = startSessionAutosave(10);
    useRegexStore.getState().loadPattern("([0-9]+)", "gi", "a 12 b 345");
    useRegexStore.getState().setReplaceText("<$1>");
    vi.advanceTimersByTime(20);
    stop();
    vi.useRealTimers();
    expect(JSON.parse(storage.get("regex-lab-session")!)).toEqual({
      pattern: "([0-9]+)",
      flags: "gi",
      testText: "a 12 b 345",
      replaceText: "<$1>",
    });

    useRegexStore.getState().clearAll();
    expect(useRegexStore.getState().pattern).toBe("");
    expect(useRegexStore.getState().restoreSession()).toBe(true);
    await settle();
    const s = useRegexStore.getState();
    expect(s.pattern).toBe("([0-9]+)");
    expect(s.matches.map((m) => m.value)).toEqual(["12", "345"]);
    expect(s.replacedText).toBe("a <12> b <345>");

    storage.clear();
    vi.useFakeTimers();
    const stop2 = startSessionAutosave(10);
    useRegexStore.getState().setTestText("x".repeat(MAX_SESSION_TEXT + 1));
    vi.advanceTimersByTime(20);
    stop2();
    expect(storage.has("regex-lab-session")).toBe(false);
  });

  it("oturum yoksa restoreSession false doner", () => {
    expect(useRegexStore.getState().restoreSession()).toBe(false);
  });

  it("clearAll bekleyen degerlendirmeyi iptal eder, rerun yeniden hesaplar", async () => {
    useRegexStore.getState().loadPattern("a", "g", "aaa");
    useRegexStore.getState().clearAll();
    await settle();
    expect(useRegexStore.getState().matches).toEqual([]);

    useRegexStore.setState({ pattern: "b", testText: "bb", matches: [] });
    useRegexStore.getState().rerun();
    await settle();
    expect(useRegexStore.getState().matches).toHaveLength(2);
  });
});
