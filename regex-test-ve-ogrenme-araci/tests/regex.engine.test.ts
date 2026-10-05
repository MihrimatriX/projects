import { describe, expect, it } from "vitest";
import { evaluateRegex } from "@/lib/regex/evaluate";
import { parsePatternAst } from "@/lib/regex/explain";
import { REGEX_PRESETS } from "@/lib/regex/presets";
import { analyzeRedosRisk } from "@/lib/redos";

describe("evaluateRegex", () => {
  it("finds global email matches", () => {
    const result = evaluateRegex("[a-z]+@[a-z]+", "g", "a@b c@d", "");
    expect(result.isValid).toBe(true);
    expect(result.matches).toHaveLength(2);
    expect(result.matches[0].value).toBe("a@b");
    expect(result.matches[0].line).toBe(1);
    expect(result.matches[0].column).toBeGreaterThan(0);
  });

  it("extracts capture groups", () => {
    const result = evaluateRegex(
      "(\\w+)@(\\w+)",
      "g",
      "a@b",
      ""
    );
    expect(result.matches[0].groups).toHaveLength(2);
    expect(result.matches[0].groups[0].value).toBe("a");
    expect(result.matches[0].groups[1].value).toBe("b");
  });

  it("applies replacement preview", () => {
    const result = evaluateRegex(
      "@\\w+",
      "g",
      "Merhaba @ali",
      "[GİZLİ]"
    );
    expect(result.replacedText).toBe("Merhaba [GİZLİ]");
  });

  it("returns Turkish error for invalid pattern", () => {
    const result = evaluateRegex("(", "g", "test", "");
    expect(result.isValid).toBe(false);
    expect(result.error).toContain("Kapatılmamış grup");
  });

  it("returns empty matches for non-matching pattern", () => {
    const result = evaluateRegex("\\d+", "g", "abc", "");
    expect(result.matches).toHaveLength(0);
  });
});

describe("parsePatternAst", () => {
  it("builds explanation steps for quantifiers", () => {
    const { explanation } = parsePatternAst("\\d+");
    expect(explanation.some((step) => step.type === "quantifier")).toBe(true);
    expect(explanation.some((step) => step.snippet === "\\d")).toBe(true);
  });

  it("builds AST tree nodes", () => {
    const { astTree } = parsePatternAst("(abc)+");
    expect(astTree.length).toBeGreaterThan(0);
    expect(astTree[0].children.length).toBeGreaterThan(0);
  });
});

describe("analyzeRedosRisk", () => {
  it("flags nested quantifiers as high risk", () => {
    const analysis = analyzeRedosRisk("(a+)+");
    expect(analysis.risk).toBe("high");
    expect(analysis.reasons.length).toBeGreaterThan(0);
  });

  it("returns low risk for simple patterns", () => {
    const analysis = analyzeRedosRisk("^\\d{4}$");
    expect(analysis.risk).toBe("low");
  });
});

describe("REGEX_PRESETS golden", () => {
  it("has 20 built-in presets", () => {
    expect(REGEX_PRESETS).toHaveLength(20);
  });

  it.each([
    ["email", 2],
    ["ipv4", 2],
    ["turkish_chars", 4],
    ["time_24h", 2],
  ] as const)("preset %s finds expected matches", (id, minMatches) => {
    const preset = REGEX_PRESETS.find((p) => p.id === id);
    expect(preset).toBeDefined();
    const result = evaluateRegex(preset!.pattern, preset!.flags, preset!.testText, "");
    expect(result.isValid).toBe(true);
    expect(result.matches.length).toBeGreaterThanOrEqual(minMatches);
  });
});

describe("capturingGroupNames", () => {
  it("orders named and unnamed capturing groups, skipping non-capturing ones", async () => {
    const { capturingGroupNames } = await import("../src/lib/regex/evaluate");
    expect(capturingGroupNames("(?<u>\\w+)@(?:x)(\\w+)(?=a)(?<!b)[(]\\(")).toEqual(["u", null]);
  });

  it("names numbered groups instead of duplicating them", async () => {
    const { evaluateRegex } = await import("../src/lib/regex/evaluate");
    const r = evaluateRegex("(?<u>\\w+)@(\\w+)", "g", "a@b", "");
    expect(r.matches[0].groups).toEqual([
      { index: 1, value: "a", name: "u" },
      { index: 2, value: "b" },
    ]);
  });
});
