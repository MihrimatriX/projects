import { describe, expect, it } from "vitest";
import {
  contentContainsMention,
  extractMentions,
  highlightMentions,
} from "@/lib/mentions";

describe("extractMentions", () => {
  it("parses @username mentions", () => {
    expect(extractMentions("Merhaba @Ayşe ve @mehmet")).toEqual([
      "ayşe",
      "mehmet",
    ]);
  });

  it("returns empty for no mentions", () => {
    expect(extractMentions("selam dünya")).toEqual([]);
  });
});

describe("highlightMentions", () => {
  it("wraps mentions in span", () => {
    expect(highlightMentions("@Ayşe bak")).toContain('class="mention"');
    expect(highlightMentions("@Ayşe bak")).toContain("@Ayşe");
  });
});

describe("contentContainsMention", () => {
  it("detects mention of user", () => {
    expect(contentContainsMention("@Ayşe kontrol et", "Ayşe")).toBe(true);
    expect(contentContainsMention("selam", "Ayşe")).toBe(false);
  });
});
