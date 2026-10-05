import os from "os";

/** TextMate-style placeholders: {{date}}, {{time}}, {{user}}, {{hostname}} */
export function expandPlaceholders(code: string): string {
  const now = new Date();
  const pad = (n: number) => String(n).padStart(2, "0");
  const date = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  const time = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;

  return code
    .replace(/\{\{date\}\}/gi, date)
    .replace(/\{\{time\}\}/gi, time)
    .replace(/\{\{datetime\}\}/gi, now.toISOString())
    .replace(/\{\{user\}\}/gi, os.userInfo().username)
    .replace(/\{\{hostname\}\}/gi, os.hostname())
    .replace(/\{\{year\}\}/gi, String(now.getFullYear()));
}
