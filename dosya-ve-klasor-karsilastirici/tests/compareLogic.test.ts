import fs from "fs";
import os from "os";
import path from "path";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import {
  compareFolders,
  diffStats,
  listFiles,
  mergeCopy,
  shouldIgnoreDir,
} from "../electron/compareLogic";

describe("compareLogic", () => {
  let tmp: string;

  beforeEach(() => {
    tmp = fs.mkdtempSync(path.join(os.tmpdir(), "diff-test-"));
  });

  afterEach(() => {
    fs.rmSync(tmp, { recursive: true, force: true });
  });

  it("ignores node_modules", () => {
    expect(shouldIgnoreDir("node_modules")).toBe(true);
    expect(shouldIgnoreDir("src")).toBe(false);
  });

  it("detects identical and different files", () => {
    const left = path.join(tmp, "left");
    const right = path.join(tmp, "right");
    fs.mkdirSync(left);
    fs.mkdirSync(right);
    fs.writeFileSync(path.join(left, "same.txt"), "hello");
    fs.writeFileSync(path.join(right, "same.txt"), "hello");
    fs.writeFileSync(path.join(left, "diff.txt"), "a");
    fs.writeFileSync(path.join(right, "diff.txt"), "b");
    fs.writeFileSync(path.join(left, "only-left.txt"), "x");

    const result = compareFolders(left, right);
    const byPath = Object.fromEntries(result.entries.map((e) => [e.relativePath, e.status]));

    expect(byPath["same.txt"]).toBe("identical");
    expect(byPath["diff.txt"]).toBe("different");
    expect(byPath["only-left.txt"]).toBe("left_only");
    expect(listFiles(left).length).toBe(3);
  });

  it("computes diff stats", () => {
    const stats = diffStats("a\nb\nc", "a\nx\nc");
    expect(stats.additions).toBe(1);
    expect(stats.deletions).toBe(1);
  });

  it("merge creates backup", () => {
    const target = path.join(tmp, "out.txt");
    const source = path.join(tmp, "in.txt");
    fs.writeFileSync(target, "old");
    fs.writeFileSync(source, "new");
    const { backupPath } = mergeCopy(source, target);
    expect(backupPath).toBe(`${target}.bak`);
    expect(fs.readFileSync(target, "utf8")).toBe("new");
    expect(fs.readFileSync(`${target}.bak`, "utf8")).toBe("old");
  });
});
