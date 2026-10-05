import { describe, expect, it } from "vitest";
import { analyzeFlavorCompatibility, countGlobalMatches } from "@/lib/regex/flavor";

describe("analyzeFlavorCompatibility", () => {
  it("detects PCRE named group syntax", () => {
    const warnings = analyzeFlavorCompatibility("(?P<name>\\w+)", "g");
    expect(warnings.some((w) => w.id === "pcre-named-py")).toBe(true);
  });

  it("detects possessive quantifiers", () => {
    const warnings = analyzeFlavorCompatibility("(a+)++", "g");
    expect(warnings.some((w) => w.id === "possessive-quant")).toBe(true);
  });

  it("warns about unicode property without u flag", () => {
    const warnings = analyzeFlavorCompatibility("\\p{L}+", "g");
    expect(warnings.some((w) => w.id === "unicode-property")).toBe(true);
  });

  it("returns empty for plain JS patterns", () => {
    const warnings = analyzeFlavorCompatibility("[a-z]+", "gi");
    expect(warnings.filter((w) => w.severity === "error")).toHaveLength(0);
  });
});

describe("countGlobalMatches", () => {
  it("counts multiple matches without g flag active", () => {
    const count = countGlobalMatches("\\d", "", "1 2 3");
    expect(count).toBe(3);
  });

  it("returns null when g flag is already set", () => {
    expect(countGlobalMatches("\\d", "g", "1 2 3")).toBeNull();
  });
});
