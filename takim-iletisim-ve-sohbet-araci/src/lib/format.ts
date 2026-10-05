export function formatTime(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleTimeString("tr-TR", { hour: "2-digit", minute: "2-digit" });
}

export function formatDate(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  if (d.toDateString() === today.toDateString()) return "Bugün";
  return d.toLocaleDateString("tr-TR", {
    day: "numeric",
    month: "short",
  });
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export function channelLabel(
  name: string,
  type: string,
  dmPartner?: { name: string } | null,
): string {
  if (type === "DM") return dmPartner?.name ?? "DM";
  return `# ${name}`;
}
