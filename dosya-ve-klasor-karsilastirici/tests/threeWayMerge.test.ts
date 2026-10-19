import { describe, expect, it } from "vitest";
import { applyConflictResolutions, threeWayMerge } from "../electron/threeWayMerge";

describe("threeWayMerge", () => {
  it("auto-merges non-conflicting lines", () => {
    const base = "a\nb\nc";
    const left = "a\nB\nc";
    const right = "a\nb\nC";
    const result = threeWayMerge(base, left, right);
    expect(result.conflicts.length).toBe(0);
    expect(result.merged).toBe("a\nB\nC");
  });

  it("detects conflicts", () => {
    const base = "x";
    const left = "left";
    const right = "right";
    const result = threeWayMerge(base, left, right);
    expect(result.conflicts.length).toBe(1);
    expect(result.conflicts[0].left).toBe("left");
    expect(result.conflicts[0].right).toBe("right");
  });

  it("applies resolutions", () => {
    const merged = applyConflictResolutions("b", "L", "R", { 1: "right" });
    expect(merged).toBe("R");
    expect(applyConflictResolutions("b", "L", "R", { 1: "both" })).toBe("L\nR");
  });
});
