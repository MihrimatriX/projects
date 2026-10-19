const rtf = new Intl.RelativeTimeFormat("tr", { numeric: "auto" });

function startOfDay(d: Date) {
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

export function formatBoardDate(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const time = date.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  const dayDiff = Math.round(
    (startOfDay(date).getTime() - startOfDay(now).getTime()) / 86_400_000
  );

  if (dayDiff === 0) return `Son düzenleme · bugün ${time}`;
  if (dayDiff === -1) return `Son düzenleme · dün ${time}`;
  if (dayDiff > -7) return `Son düzenleme · ${rtf.format(dayDiff, "day")} ${time}`;
  return `Son düzenleme · ${date.toLocaleDateString("tr-TR", { day: "numeric", month: "short" })}`;
}

export function formatBoardDateShort(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const time = date.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
  const dayDiff = Math.round(
    (startOfDay(date).getTime() - startOfDay(now).getTime()) / 86_400_000
  );

  if (dayDiff === 0) return `bugün ${time}`;
  if (dayDiff === -1) return `dün ${time}`;
  if (dayDiff > -7) return rtf.format(dayDiff, "day");
  return date.toLocaleDateString("tr-TR", { day: "numeric", month: "short" });
}
