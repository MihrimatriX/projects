import { describe, it, expect } from "vitest";
import { parseOmnivoreExport, omnivoreToClipPayload } from "@/lib/omnivore";
import { normalizeTagName, extractDomain, estimateReadingMinutes } from "@/lib/format";

describe("omnivore import", () => {
  it("parses array export", () => {
    const items = parseOmnivoreExport([
      { url: "https://a.com", title: "A", labels: ["tech"] },
    ]);
    expect(items).toHaveLength(1);
    const payload = omnivoreToClipPayload(items[0]);
    expect(payload.url).toBe("https://a.com");
    expect(payload.tags).toContain("tech");
  });

  it("parses wrapped links export", () => {
    const items = parseOmnivoreExport({
      links: [{ url: "https://b.com", title: "B" }],
    });
    expect(items).toHaveLength(1);
  });
});

describe("format helpers", () => {
  it("extracts domain", () => {
    expect(extractDomain("https://www.example.com/path")).toBe("example.com");
  });

  it("normalizes tags", () => {
    expect(normalizeTagName("  AI  ")).toBe("ai");
  });

  it("estimates reading minutes", () => {
    const words = Array(400).fill("word").join(" ");
    expect(estimateReadingMinutes(words)).toBe(2);
  });
});
