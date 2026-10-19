import { describe, expect, it } from "vitest";
import { mergeIgnoreDirs, parseGitignoreContent } from "../electron/gitignoreParser";

describe("gitignoreParser", () => {
  it("parses directory names", () => {
    const dirs = parseGitignoreContent(`
# comment
node_modules/
dist
*.log
!important
`);
    expect(dirs).toContain("node_modules");
    expect(dirs).toContain("dist");
    expect(dirs).not.toContain("*.log");
  });

  it("merges extra ignore", () => {
    const merged = mergeIgnoreDirs(["custom"], undefined, undefined, false);
    expect(merged).toContain("custom");
    expect(merged).not.toContain("node_modules");
  });
});
