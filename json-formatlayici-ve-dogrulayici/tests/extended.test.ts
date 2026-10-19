import { describe, expect, it } from "vitest";
import { diffJson, summarizeDiff } from "../src/lib/json-diff";
import { detectNdjson, parseNdjson, formatNdjson } from "../src/lib/ndjson";
import { repairJson } from "../src/lib/json-repair";
import { queryJsonPath } from "../src/lib/jsonpath-query";
import { validateAgainstSchema } from "../src/lib/schema-validate";
import { buildShareUrl, parseShareHash } from "../src/lib/share-url";
import { jsonToTypeScript } from "../src/lib/ts-interface";
import { buildFlatTree } from "../src/lib/tree-flat";

describe("ndjson", () => {
  it("detects multi-line ndjson", () => {
    const text = '{"a":1}\n{"b":2}';
    expect(detectNdjson(text)).toBe(true);
  });

  it("parses valid lines", () => {
    const r = parseNdjson('{"a":1}\n{"b":2}');
    expect(r.ok).toBe(true);
    expect(r.lines).toHaveLength(2);
  });

  it("formats each line", () => {
    const out = formatNdjson('{"a":1}\n{"b":2}', 2);
    expect(out).toContain('"a"');
    expect(out.split("\n").length).toBeGreaterThanOrEqual(2);
  });
});

describe("repairJson", () => {
  it("removes trailing commas", () => {
    const repaired = repairJson('{"a":1,}');
    expect(() => JSON.parse(repaired)).not.toThrow();
  });
});

describe("jsonpath", () => {
  it("queries nested path", () => {
    const data = { users: [{ name: "Ali" }, { name: "Veli" }] };
    const r = queryJsonPath(data, "$.users[*].name");
    expect(r.ok).toBe(true);
    expect(r.count).toBe(2);
  });

  it("highlights only matched nodes, not equal values elsewhere", () => {
    const r = queryJsonPath({ a: 1, b: 1, c: { "x/y": 2 } }, "$.a");
    expect(r.paths).toEqual(["/a"]);
    expect(queryJsonPath({ c: { "x/y": 2 } }, "$.c['x/y']").paths).toEqual(["/c/x~1y"]);
  });
});

describe("schema", () => {
  it("validates object type", () => {
    const r = validateAgainstSchema({ a: 1 }, '{"type":"object","required":["a"]}');
    expect(r.valid).toBe(true);
  });

  it("reports missing required", () => {
    const r = validateAgainstSchema({}, '{"type":"object","required":["a"]}');
    expect(r.valid).toBe(false);
    expect(r.errors.length).toBeGreaterThan(0);
  });
});

describe("diff", () => {
  it("finds added key", () => {
    const entries = diffJson({ a: 1 }, { a: 1, b: 2 });
    const summary = summarizeDiff(entries);
    expect(summary.added).toBeGreaterThan(0);
  });
});

describe("share url", () => {
  it("round-trips payload", () => {
    const url = buildShareUrl('{"x":1}', "json", "https://example.com/app");
    expect(url).toContain("#d=");
    const payload = parseShareHash(url!.slice(url!.indexOf("#")));
    expect(payload?.j).toBe('{"x":1}');
  });
});

describe("typescript export", () => {
  it("generates interface", () => {
    const ts = jsonToTypeScript("Root", { id: 1, active: true });
    expect(ts).toContain("export type Root");
    expect(ts).toContain("id");
  });
});

describe("flat tree", () => {
  it("builds rows for expanded tree", () => {
    const rows = buildFlatTree({ a: { b: 1 } }, new Set(["/", "/a"]));
    expect(rows.length).toBeGreaterThan(2);
  });
});

describe("lineDiff", () => {
  it("marks only differing lines (LCS)", async () => {
    const { lineDiff } = await import("../src/lib/json-diff");
    const r = lineDiff(["{", '"a": 1,', '"b": 2', "}"], ["{", '"a": 1,', '"c": 3', "}"]);
    expect([...r.removed]).toEqual([2]);
    expect([...r.added]).toEqual([2]);
  });

  it("handles empty sides", async () => {
    const { lineDiff } = await import("../src/lib/json-diff");
    expect([...lineDiff([], ["x"]).added]).toEqual([0]);
    expect([...lineDiff(["x"], []).removed]).toEqual([0]);
  });
});

describe("queryJsonPath no match", () => {
  it("returns zero results instead of [undefined]", () => {
    const r = queryJsonPath({ a: 1 }, "$.yok");
    expect(r.ok).toBe(true);
    expect(r.count).toBe(0);
    expect(r.values).toEqual([]);
  });

  it("keeps a single array match as one result", () => {
    const r = queryJsonPath({ a: [1, 2] }, "$.a");
    expect(r.values).toEqual([[1, 2]]);
  });
});
