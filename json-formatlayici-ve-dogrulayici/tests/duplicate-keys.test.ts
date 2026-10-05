import { describe, expect, it } from "vitest";
import { findDuplicateKeys } from "../src/lib/duplicate-keys";

describe("findDuplicateKeys", () => {
  it("detects duplicate keys in same object", () => {
    const json = '{\n  "a": 1,\n  "a": 2\n}';
    const hits = findDuplicateKeys(json);
    expect(hits.some((h) => h.key === "a")).toBe(true);
  });

  it("returns empty for unique keys", () => {
    const json = '{"a":1,"b":2}';
    expect(findDuplicateKeys(json)).toHaveLength(0);
  });

  it("ignores repeated string values inside arrays", () => {
    const json = '{"a":1,"tags":["x","a","a"]}';
    expect(findDuplicateKeys(json)).toHaveLength(0);
  });
});
