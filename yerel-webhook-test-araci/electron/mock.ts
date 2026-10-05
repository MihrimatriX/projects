import type { MockRule } from "../src/types";

export function matchMockRule(
  rules: MockRule[],
  endpointId: string,
  method: string,
  url: string
): MockRule | null {
  const path = url.split("?")[0];
  const candidates = rules
    .filter((r) => r.endpointId === endpointId)
    .filter((r) => !r.method || r.method.toUpperCase() === method.toUpperCase())
    .filter((r) => {
      if (!r.pathPattern) return true;
      try {
        return new RegExp(r.pathPattern).test(path);
      } catch {
        return path.includes(r.pathPattern);
      }
    })
    .sort((a, b) => b.priority - a.priority);
  return candidates[0] ?? null;
}
