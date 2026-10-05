export function formatMailDate(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();

  if (sameDay) {
    return date.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  }

  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  const isYesterday =
    date.getFullYear() === yesterday.getFullYear() &&
    date.getMonth() === yesterday.getMonth() &&
    date.getDate() === yesterday.getDate();

  if (isYesterday) return "Dün";

  return date.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
}

export function formatFullDate(iso: string): string {
  return new Date(iso).toLocaleString("tr-TR", {
    day: "numeric",
    month: "long",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function previewBody(body: string, max = 90): string {
  const flat = body.replace(/\s+/g, " ").trim();
  return flat.length > max ? `${flat.slice(0, max)}…` : flat;
}

export function applyTemplate(text: string, vars: Record<string, string>): string {
  return text.replace(/\{(\w+)\}/g, (_, key: string) => vars[key] ?? `{${key}}`);
}

export function snoozeUntil(hoursFromNow: number): string {
  const d = new Date();
  d.setHours(d.getHours() + hoursFromNow);
  return d.toISOString();
}

export function snoozeTomorrowMorning(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  d.setHours(9, 0, 0, 0);
  return d.toISOString();
}

export function snoozeTonight(): string {
  const d = new Date();
  d.setHours(18, 0, 0, 0);
  if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1);
  return d.toISOString();
}

export function snoozeNextWeek(): string {
  const d = new Date();
  d.setDate(d.getDate() + 7);
  d.setHours(9, 0, 0, 0);
  return d.toISOString();
}

export function formatSnoozeLabel(iso: string): string {
  const d = new Date(iso);
  const now = new Date();
  const sameDay =
    d.getFullYear() === now.getFullYear() &&
    d.getMonth() === now.getMonth() &&
    d.getDate() === now.getDate();
  const time = d.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  if (sameDay) return `Bugün ${time}`;
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  const isTomorrow =
    d.getFullYear() === tomorrow.getFullYear() &&
    d.getMonth() === tomorrow.getMonth() &&
    d.getDate() === tomorrow.getDate();
  if (isTomorrow) return `Yarın ${time}`;
  return d.toLocaleString("tr-TR", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function trackingDaysLeft(startedAt: string, reminderDays: number): number {
  const start = new Date(startedAt).getTime();
  const due = start + reminderDays * 86400000;
  return Math.max(0, Math.ceil((due - Date.now()) / 86400000));
}

export function extractEmail(from: string): string {
  const match = from.match(/<([^>]+)>/);
  return match ? match[1].trim() : from.trim();
}

export function senderName(from: string): string {
  const match = from.match(/^"?([^"<]+)"?\s*</);
  if (match) return match[1].trim();
  return from.split("@")[0] ?? from;
}

export function bodyToHtml(text: string): string {
  const escaped = text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
  return escaped
    .split(/\n{2,}/)
    .map((p) => `<p>${p.replace(/\n/g, "<br>")}</p>`)
    .join("");
}
