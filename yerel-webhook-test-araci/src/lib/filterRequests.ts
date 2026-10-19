import type { RequestFilters, WebhookRequest } from "../types";

export function matchesFilters(req: WebhookRequest, filters: RequestFilters): boolean {
  if (filters.methods.length && !filters.methods.includes(req.method.toUpperCase())) {
    return false;
  }
  const q = filters.path.trim().toLowerCase();
  if (!q) return true;
  // Path'in yanında gövde ve başlık değerlerinde de aranır (ör. olay adı, müşteri id'si)
  return (
    req.url.toLowerCase().includes(q) ||
    req.body.toLowerCase().includes(q) ||
    Object.entries(req.headers).some(([k, v]) => `${k}: ${v}`.toLowerCase().includes(q))
  );
}

export function filterActive(filters: RequestFilters): boolean {
  return filters.methods.length > 0 || filters.path.trim().length > 0;
}
