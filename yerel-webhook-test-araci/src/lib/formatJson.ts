export function tryPrettyJson(body: string): { pretty: string; isJson: boolean } {
  const trimmed = body.trim();
  if (!trimmed.startsWith("{") && !trimmed.startsWith("[")) {
    return { pretty: body, isJson: false };
  }
  try {
    return { pretty: JSON.stringify(JSON.parse(trimmed), null, 2), isJson: true };
  } catch {
    return { pretty: body, isJson: false };
  }
}
