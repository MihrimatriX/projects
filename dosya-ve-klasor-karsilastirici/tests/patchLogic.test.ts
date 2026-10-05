import { describe, expect, it } from "vitest";
import { createUnifiedPatch, parseGitDiff } from "../electron/patchLogic";

describe("patchLogic", () => {
  it("creates unified patch", () => {
    const patch = createUnifiedPatch("test.txt", "a\nb", "a\nc");
    expect(patch).toContain("---");
    expect(patch).toContain("+++");
    expect(patch).toContain("-b");
    expect(patch).toContain("+c");
  });

  it("parses git diff", () => {
    const text = `diff --git a/foo.txt b/foo.txt
--- a/foo.txt
+++ b/foo.txt
@@ -1,2 +1,2 @@
 line1
-old
+new
`;
    const parsed = parseGitDiff(text);
    expect(parsed.length).toBeGreaterThan(0);
    expect(parsed[0].fileName).toContain("foo");
    expect(parsed[0].left).toContain("old");
    expect(parsed[0].right).toContain("new");
  });

  it("rejects plain text without hunks", () => {
    expect(parseGitDiff("bu bir diff değil")).toEqual([]);
    expect(parseGitDiff("diff --git a/x b/x\nold mode 100644\nnew mode 100755\n")).toEqual([]);
  });
});
