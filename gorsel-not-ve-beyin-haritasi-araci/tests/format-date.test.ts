import { describe, expect, it } from "vitest";
import { formatBoardDate, formatBoardDateShort } from "@/lib/format-date";

describe("formatBoardDate", () => {
  it("bugun ve dun icin goreli metin uretir", () => {
    const now = new Date();
    const yesterday = new Date(now.getTime() - 86_400_000);
    expect(formatBoardDate(now.toISOString())).toMatch(/^Son düzenleme · bugün \d{2}:\d{2}$/);
    expect(formatBoardDateShort(yesterday.toISOString())).toMatch(/^dün /);
  });
});
