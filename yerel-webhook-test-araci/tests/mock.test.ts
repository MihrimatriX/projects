import { describe, expect, it } from "vitest";
import { matchMockRule } from "../electron/mock";
import type { MockRule } from "../src/types";

const rules: MockRule[] = [
  {
    id: "1",
    endpointId: "ep1",
    method: "POST",
    pathPattern: "^/hook/stripe",
    statusCode: 200,
    body: "{}",
    contentType: "application/json",
    priority: 10,
  },
  {
    id: "2",
    endpointId: "ep1",
    method: null,
    pathPattern: null,
    statusCode: 404,
    body: "not found",
    contentType: "text/plain",
    priority: 1,
  },
];

describe("matchMockRule", () => {
  it("picks highest priority matching rule", () => {
    const m = matchMockRule(rules, "ep1", "POST", "/hook/stripe");
    expect(m?.statusCode).toBe(200);
  });

  it("falls back to catch-all", () => {
    const m = matchMockRule(rules, "ep1", "GET", "/other");
    expect(m?.statusCode).toBe(404);
  });

  it("returns null for wrong endpoint", () => {
    expect(matchMockRule(rules, "ep2", "POST", "/hook/stripe")).toBeNull();
  });
});
