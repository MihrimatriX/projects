import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { downloadName } from "../src/lib/file-io";
import { initFromUrlHash, MAX_DRAFT_CHARS, startDraftAutosave, useJsonStore } from "../src/lib/store";

const settle = () => new Promise((r) => setTimeout(r, 0));

describe("downloadName", () => {
  it("acik dosyanin adini kullanir", () => {
    expect(downloadName("C:\\veri\\ayar.json", "json")).toBe("ayar.json");
    expect(downloadName("/tmp/log.ndjson", "ndjson")).toBe("log.ndjson");
  });
  it("dosya yoksa moda gore varsayilan verir", () => {
    expect(downloadName(null, "json")).toBe("veri.json");
    expect(downloadName("", "ndjson")).toBe("veri.ndjson");
  });
});

describe("store ana akislari", () => {
  let storage: Map<string, string>;

  beforeEach(() => {
    storage = new Map();
    vi.stubGlobal("localStorage", {
      getItem: (k: string) => storage.get(k) ?? null,
      setItem: (k: string, v: string) => void storage.set(k, v),
      removeItem: (k: string) => void storage.delete(k),
    });
    useJsonStore.getState().clearAll();
  });
  afterEach(() => vi.unstubAllGlobals());

  it("format, minify, sort ve onarim", async () => {
    const s = useJsonStore.getState();
    s.setRawJson('{"b":1,"a":[1,2]}');
    await settle();
    s.formatJson();
    await settle();
    expect(useJsonStore.getState().rawJson).toBe('{\n  "b": 1,\n  "a": [\n    1,\n    2\n  ]\n}');
    s.sortKeys();
    await settle();
    expect(useJsonStore.getState().rawJson.indexOf('"a"')).toBeLessThan(useJsonStore.getState().rawJson.indexOf('"b"'));
    s.minifyJson();
    await settle();
    expect(useJsonStore.getState().rawJson).toBe('{"a":[1,2],"b":1}');

    s.setRawJson("{'x': 'y', \"z\": [1,],}");
    await settle();
    expect(useJsonStore.getState().isValid).toBe(false);
    s.repairAndParse();
    await settle();
    expect(useJsonStore.getState().isValid).toBe(true);
    expect(useJsonStore.getState().parsedJson).toEqual({ x: "y", z: [1] });
  });

  it("clearAll dosya adini da sifirlar", () => {
    useJsonStore.getState().setFileName("a.json");
    useJsonStore.getState().clearAll();
    expect(useJsonStore.getState().fileName).toBeNull();
    expect(useJsonStore.getState().rawJson).toBe("");
  });

  it("taslak otomatik kaydedilir ve geri yuklenir, cok buyukse saklanmaz", async () => {
    vi.useFakeTimers();
    const stop = startDraftAutosave(10);
    useJsonStore.getState().setRawJson('{"taslak":true}');
    vi.advanceTimersByTime(20);
    expect(storage.get("json-formatlayici-draft")).toBe('{"taslak":true}');

    useJsonStore.getState().setRawJson("x".repeat(MAX_DRAFT_CHARS + 1));
    vi.advanceTimersByTime(20);
    expect(storage.get("json-formatlayici-draft")).toBe('{"taslak":true}');

    useJsonStore.getState().clearAll();
    vi.advanceTimersByTime(20);
    expect(storage.has("json-formatlayici-draft")).toBe(false);
    stop();
    vi.useRealTimers();

    storage.set("json-formatlayici-draft", '{"geri":1}');
    vi.stubGlobal("window", { location: { hash: "" } });
    initFromUrlHash();
    await settle();
    expect(useJsonStore.getState().parsedJson).toEqual({ geri: 1 });
  });
});
