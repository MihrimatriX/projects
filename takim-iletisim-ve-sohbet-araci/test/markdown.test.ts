import { describe, expect, it } from "vitest";
import { isAllowedMime, stripDangerousContent } from "@/lib/markdown";

describe("stripDangerousContent", () => {
  it("removes script tags", () => {
    expect(stripDangerousContent('<script>alert(1)</script>selam')).toBe("selam");
  });

  it("blocks javascript urls", () => {
    expect(stripDangerousContent("javascript:alert(1)")).not.toContain("javascript:");
  });
});

describe("isAllowedMime", () => {
  it("blocks executables", () => {
    expect(isAllowedMime("application/x-msdownload")).toBe(false);
    expect(isAllowedMime("image/png")).toBe(true);
  });
});
