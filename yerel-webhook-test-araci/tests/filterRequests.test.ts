import { describe, expect, it } from "vitest";
import { filterActive, matchesFilters } from "../src/lib/filterRequests";
import type { WebhookRequest } from "../src/types";

const base: WebhookRequest = {
  id: "1",
  method: "POST",
  url: "/hook/test",
  headers: {},
  body: '{"event":"checkout"}',
  timestamp: new Date().toISOString(),
  endpointId: "ep1",
};

describe("matchesFilters", () => {
  it("filters by method chips", () => {
    expect(matchesFilters(base, { methods: ["GET"], path: "" })).toBe(false);
    expect(matchesFilters(base, { methods: ["POST"], path: "" })).toBe(true);
    expect(matchesFilters(base, { methods: [], path: "" })).toBe(true);
  });

  it("searches path, body and header values (case-insensitive)", () => {
    expect(matchesFilters(base, { methods: [], path: "/hook/" })).toBe(true);
    expect(matchesFilters(base, { methods: [], path: "CHECKOUT" })).toBe(true);
    expect(matchesFilters({ ...base, headers: { "x-github-event": "push" } }, { methods: [], path: "push" })).toBe(true);
    expect(matchesFilters(base, { methods: [], path: "refund" })).toBe(false);
  });

  it("detects active filters", () => {
    expect(filterActive({ methods: [], path: "" })).toBe(false);
    expect(filterActive({ methods: ["POST"], path: "" })).toBe(true);
    expect(filterActive({ methods: [], path: "x" })).toBe(true);
  });
});
