const MENTION_REGEX = /@([\w\u00C0-\u024F\u0400-\u04FF.-]+)/g;

export function extractMentions(content: string): string[] {
  const matches = content.matchAll(MENTION_REGEX);
  const names = new Set<string>();
  for (const match of matches) {
    if (match[1]) names.add(match[1].toLowerCase());
  }
  return [...names];
}

export function highlightMentions(content: string): string {
  // Sonuç innerHTML ile basılır: önce HTML kaçırılır, sonra yalnızca mention span'ı eklenir
  const escaped = content
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
  return escaped.replace(
    MENTION_REGEX,
    '<span class="mention">@$1</span>',
  );
}

export function contentContainsMention(
  content: string,
  userName: string,
): boolean {
  const mentions = extractMentions(content);
  return mentions.includes(userName.toLowerCase());
}
