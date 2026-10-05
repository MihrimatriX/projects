import type { WebhookRequest } from "../types";

export function toCurl(req: WebhookRequest, port: number): string {
  const headerLines = Object.entries(req.headers)
    .filter(([k]) => !k.startsWith(":"))
    .map(([k, v]) => `-H "${k}: ${v}"`)
    .join(" ");
  const body =
    req.body && !["GET", "HEAD"].includes(req.method.toUpperCase())
      ? `-d '${req.body.replace(/'/g, "'\\''")}'`
      : "";
  return `curl -X ${req.method} ${headerLines} ${body} "http://127.0.0.1:${port}${req.url}"`
    .replace(/\s+/g, " ")
    .trim();
}
