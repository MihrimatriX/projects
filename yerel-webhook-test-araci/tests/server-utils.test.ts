import { describe, expect, it } from "vitest";
import { isLoopbackHost, maskBody, maskHeaders, parseHookSlug, truncateBody } from "../electron/server-utils";

describe("parseHookSlug", () => {
  it("extracts slug from hook path", () => {
    expect(parseHookSlug("/hook/abc123")).toBe("abc123");
    expect(parseHookSlug("/hook/a8f3k2?x=1")).toBe("a8f3k2");
  });
  it("returns null for non-hook paths", () => {
    expect(parseHookSlug("/webhook")).toBeNull();
  });
});

describe("maskHeaders", () => {
  it("masks authorization", () => {
    const out = maskHeaders({ Authorization: "Bearer secret", "X-Custom": "ok" });
    expect(out.Authorization).toContain("••••");
    expect(out["X-Custom"]).toBe("ok");
  });
});

describe("maskBody", () => {
  it("masks token fields in json", () => {
    const body = '{"access_token":"abc123","name":"x"}';
    const out = maskBody(body);
    expect(out).toContain("••••");
    expect(out).not.toContain("abc123");
  });
});

describe("truncateBody", () => {
  it("truncates large bodies", () => {
    const big = "x".repeat(600_000);
    const out = truncateBody(big, 1000);
    expect(out.length).toBeLessThan(big.length);
    expect(out).toContain("kısaltıldı");
  });
});

describe("isLoopbackHost", () => {
  it("allows only this machine (incl. bracketed IPv6)", () => {
    expect(["127.0.0.1", "localhost", "::1", "[::1]"].every(isLoopbackHost)).toBe(true);
    expect(isLoopbackHost("example.com")).toBe(false);
    expect(isLoopbackHost("192.168.1.5")).toBe(false);
  });
});
