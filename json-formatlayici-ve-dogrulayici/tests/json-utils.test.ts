import { describe, expect, it } from "vitest";
import {
  countNodes,
  escapePointerSegment,
  formatFileSize,
  isLargeJson,
  parseJsonError,
  pointerToJsonPath,
  sortObjectKeys,
} from "../src/lib/json-utils";

describe("parseJsonError", () => {
  it("extracts line and column from Firefox-style message", () => {
    const err = new Error("JSON.parse: unexpected character at line 4 column 12 of the JSON data");
    const result = parseJsonError('{"a":1,\n"b":}', err);
    expect(result.line).toBe(4);
    expect(result.column).toBe(12);
  });

  it("derives line and column from V8 position", () => {
    const json = '{"a":1}\n{"b":';
    const err = new Error("Unexpected token } in JSON at position 14");
    const result = parseJsonError(json, err);
    expect(result.line).toBeGreaterThan(0);
    expect(result.column).toBeGreaterThan(0);
  });
});

describe("sortObjectKeys", () => {
  it("sorts nested object keys recursively", () => {
    const input = { z: 1, a: { y: 2, b: 3 } };
    expect(sortObjectKeys(input)).toEqual({ a: { b: 3, y: 2 }, z: 1 });
  });
});

describe("pointerToJsonPath", () => {
  it("builds JSONPath for array indices", () => {
    expect(pointerToJsonPath("/users/0/name")).toBe("$.users[0].name");
  });

  it("escapes special property names", () => {
    expect(pointerToJsonPath("/a~1b")).toBe('$["a/b"]');
  });
});

describe("escapePointerSegment", () => {
  it("escapes tilde and slash", () => {
    expect(escapePointerSegment("a/b~c")).toBe("a~1b~0c");
  });
});

describe("countNodes", () => {
  it("counts primitives and containers", () => {
    expect(countNodes({ a: 1, b: [2, 3] })).toBe(5);
  });
});

describe("formatFileSize", () => {
  it("formats kilobytes", () => {
    expect(formatFileSize(2048)).toBe("2 KB");
  });
});

describe("isLargeJson", () => {
  it("flags content over 5MB", () => {
    const big = "x".repeat(5 * 1024 * 1024 + 1);
    expect(isLargeJson(big)).toBe(true);
  });
});
