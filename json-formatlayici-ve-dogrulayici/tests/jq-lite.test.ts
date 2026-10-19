import { describe, expect, it } from "vitest";
import { runJqLite } from "../src/lib/jq-lite";
import { stripJsonc } from "../src/lib/jsonc";

describe("jq-lite", () => {
  const data = {
    users: [
      { name: "Ali", age: 30 },
      { name: "Veli", age: 25 },
    ],
  };

  it("selects nested field via pipeline", () => {
    const r = runJqLite(data, ".users | .[] | .name");
    expect(r.ok).toBe(true);
    expect(r.result).toEqual(["Ali", "Veli"]);
  });

  it("returns keys", () => {
    const r = runJqLite(data, "keys");
    expect(r.ok).toBe(true);
    expect(r.result).toEqual(["users"]);
  });
});

describe("jsonc", () => {
  it("strips line comments outside strings", () => {
    const raw = '{\n  "a": 1 // comment\n}';
    expect(JSON.parse(stripJsonc(raw))).toEqual({ a: 1 });
  });
});
