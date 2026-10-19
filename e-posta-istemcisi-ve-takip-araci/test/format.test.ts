import { describe, expect, it } from "vitest";
import {
  applyTemplate,
  formatMailDate,
  previewBody,
  senderName,
  trackingDaysLeft,
} from "../src/format";

describe("format", () => {
  it("formats sender name from address", () => {
    expect(senderName("Ahmet Yılmaz <ahmet@test.com>")).toBe("Ahmet Yılmaz");
    expect(senderName("ahmet@test.com")).toBe("ahmet");
  });

  it("previews body text", () => {
    expect(previewBody("  hello   world  ", 8)).toBe("hello wo…");
  });

  it("applies template variables", () => {
    expect(applyTemplate("Merhaba {ad}", { ad: "Ayşe" })).toBe("Merhaba Ayşe");
  });

  it("computes tracking days left", () => {
    const started = new Date(Date.now() - 86400000).toISOString();
    expect(trackingDaysLeft(started, 3)).toBe(2);
  });

  it("formats mail date for today", () => {
    const iso = new Date().toISOString();
    expect(formatMailDate(iso)).toMatch(/\d{2}:\d{2}/);
  });
});
