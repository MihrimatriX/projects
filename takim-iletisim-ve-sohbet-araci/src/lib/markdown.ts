export function stripDangerousContent(content: string): string {
  return content
    .replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, "")
    .replace(/javascript:/gi, "")
    .replace(/on\w+\s*=/gi, "data-blocked=")
    .trim();
}

const BLOCKED_MIME = [
  "application/x-msdownload",
  "application/x-executable",
  "application/vnd.microsoft.portable-executable",
];

export function isAllowedMime(mime: string): boolean {
  if (!mime) return true;
  return !BLOCKED_MIME.some((b) => mime.startsWith(b));
}
