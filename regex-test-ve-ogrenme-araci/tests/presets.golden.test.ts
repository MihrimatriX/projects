import { describe, expect, it } from "vitest";
import { detectPii, formatPiiWarning } from "@/lib/pii";
import { enrichExplanationContext } from "@/lib/regex/context";
import { evaluateRegex } from "@/lib/regex/evaluate";
import { parsePatternAst } from "@/lib/regex/explain";
import { REGEX_PRESETS } from "@/lib/regex/presets";
import { shouldUseMatchWorker } from "@/lib/regex/evaluate-worker-client";

describe("detectPii", () => {
  it("detects email in test text", () => {
    const findings = detectPii("Bize user@example.com yazın");
    expect(findings.some((f) => f.kind === "email")).toBe(true);
  });

  it("returns empty for safe text", () => {
    expect(detectPii("Merhaba dünya")).toHaveLength(0);
  });

  it("formats warning message in Turkish", () => {
    const msg = formatPiiWarning([{ kind: "email", label: "e-posta adresi", count: 2 }]);
    expect(msg).toContain("2 e-posta adresi");
    expect(msg).toContain("Paylaşım");
  });
});

describe("d flag (hasIndices)", () => {
  it("includes group start/end when d flag is set", () => {
    const result = evaluateRegex("(\\w+)@(\\w+)", "gd", "a@b", "");
    expect(result.matches).toHaveLength(1);
    const groups = result.matches[0].groups;
    expect(groups[0].start).toBe(0);
    expect(groups[0].end).toBe(1);
    expect(groups[1].start).toBe(2);
    expect(groups[1].end).toBe(3);
  });
});

describe("enrichExplanationContext", () => {
  it("adds context snippets from test text", () => {
    const { explanation } = parsePatternAst("\\w+");
    const enriched = enrichExplanationContext(explanation, "Merhaba dünya", [
      {
        index: 0,
        length: 7,
        value: "Merhaba",
        line: 1,
        column: 1,
        groups: [],
      },
    ]);
    expect(enriched.some((b) => b.contextSnippet?.includes("Merhaba"))).toBe(true);
  });
});

describe("shouldUseMatchWorker", () => {
  it("returns false on server-side", () => {
    expect(shouldUseMatchWorker("(a+)+", "short")).toBe(false);
  });
});

describe("REGEX_PRESETS golden — all presets", () => {
  it.each(REGEX_PRESETS.map((p) => [p.id, p] as const))(
    "preset %s evaluates without syntax error",
    (_id, preset) => {
      const result = evaluateRegex(preset.pattern, preset.flags, preset.testText, "");
      expect(result.isValid).toBe(true);
    }
  );

  it.each(
    REGEX_PRESETS.filter((p) => p.id !== "password").map((p) => [p.id, p] as const)
  )("preset %s finds at least one match", (_id, preset) => {
    const result = evaluateRegex(preset.pattern, preset.flags, preset.testText, "");
    expect(result.matches.length).toBeGreaterThan(0);
  });
});

describe("REGEX_PRESETS golden — expected counts", () => {
  it.each([
    ["email", 2],
    ["ipv4", 2],
    ["turkish_chars", 4],
    ["time_24h", 2],
    ["url", 1],
    ["phone_tr", 2],
    ["markdown_link", 1],
    ["hashtag", 2],
    ["json_string", 3],
    ["whitespace_trim", 3],
  ] as const)("preset %s finds at least %i matches", (id, minMatches) => {
    const preset = REGEX_PRESETS.find((p) => p.id === id);
    expect(preset).toBeDefined();
    const result = evaluateRegex(preset!.pattern, preset!.flags, preset!.testText, "");
    expect(result.matches.length).toBeGreaterThanOrEqual(minMatches);
  });
});
