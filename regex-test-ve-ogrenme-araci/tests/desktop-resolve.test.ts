import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterAll, describe, expect, it } from "vitest";
const { resolveStaticFile } = require("../desktop/resolve.cjs") as {
  resolveStaticFile: (root: string, urlPath: string) => string | null;
};

const root = fs.mkdtempSync(path.join(os.tmpdir(), "regex-out-"));
fs.writeFileSync(path.join(root, "index.html"), "i");
fs.writeFileSync(path.join(root, "lab.html"), "l");
fs.mkdirSync(path.join(root, "lab"));
fs.mkdirSync(path.join(root, "_next", "static"), { recursive: true });
fs.writeFileSync(path.join(root, "_next", "static", "a b.js"), "js");
fs.writeFileSync(path.join(os.tmpdir(), "gizli.txt"), "x");
afterAll(() => fs.rmSync(root, { recursive: true, force: true }));

describe("Electron statik dosya cozumleyici", () => {
  it("rota, .html ve index.html eslestirir", () => {
    expect(resolveStaticFile(root, "/")).toBe(path.join(root, "index.html"));
    expect(resolveStaticFile(root, "/lab")).toBe(path.join(root, "lab.html"));
    expect(resolveStaticFile(root, "/_next/static/a%20b.js?v=1")).toBe(path.join(root, "_next", "static", "a b.js"));
  });
  it("olmayan dosya ve kok disina cikma null doner", () => {
    expect(resolveStaticFile(root, "/yok")).toBeNull();
    expect(resolveStaticFile(root, "/../gizli.txt")).toBeNull();
    expect(resolveStaticFile(root, "/..%5Cgizli.txt")).toBeNull();
    expect(resolveStaticFile(root, "/%E0%A4%A")).toBeNull();
  });
});
