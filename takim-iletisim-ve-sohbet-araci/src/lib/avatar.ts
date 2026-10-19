const COLORS = ["#1164a3", "#007a5a", "#e8912d", "#cd2553", "#1d9bd1", "#6b4c9a"];

export function avatarColor(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h + name.charCodeAt(i) * 17) % COLORS.length;
  return COLORS[h]!;
}

export function avatarInitials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length >= 2) return (parts[0]![0]! + parts[1]![0]!).toUpperCase();
  return (name.trim()[0] ?? "?").toUpperCase();
}
