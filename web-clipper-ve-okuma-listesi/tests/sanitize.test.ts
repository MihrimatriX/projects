import { describe, it, expect } from "vitest";
import { sanitizeHtml, stripDangerous } from "@/lib/sanitize";

describe("sanitizeHtml", () => {
  it("keeps safe paragraph content", () => {
    const out = sanitizeHtml("<p>Merhaba <strong>dünya</strong></p>");
    expect(out).toContain("Merhaba");
    expect(out).toContain("<strong>");
  });

  it("strips script tags", () => {
    const out = sanitizeHtml('<p>ok</p><script>alert(1)</script>');
    expect(out.toLowerCase()).not.toContain("<script");
  });

  it("stripDangerous rejects script remnants", () => {
    const out = stripDangerous('<img onerror="alert(1)" src=x>');
    expect(out.toLowerCase()).not.toContain("onerror");
  });
});
