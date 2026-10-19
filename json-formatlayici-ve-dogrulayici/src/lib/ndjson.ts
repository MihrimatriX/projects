import { JsonError, parseJsonError } from "./json-utils";

export type InputMode = "json" | "ndjson";

export interface NdjsonLineError {
  line: number;
  message: string;
}

export interface NdjsonParseResult {
  ok: boolean;
  lines: unknown[];
  errors: NdjsonLineError[];
  error: JsonError | null;
}

export function detectNdjson(text: string): boolean {
  const trimmed = text.trim();
  if (!trimmed) return false;
  const lines = trimmed.split(/\r?\n/).filter((l) => l.trim());
  if (lines.length < 2) return false;
  const jsonLike = lines.filter((l) => /^[\s]*[\[{]/.test(l.trim())).length;
  return jsonLike >= Math.ceil(lines.length * 0.8);
}

export function parseNdjson(text: string): NdjsonParseResult {
  const lines = text.split(/\r?\n/);
  const values: unknown[] = [];
  const errors: NdjsonLineError[] = [];

  lines.forEach((line, index) => {
    const trimmed = line.trim();
    if (!trimmed) return;
    try {
      values.push(JSON.parse(trimmed));
    } catch (err) {
      errors.push({
        line: index + 1,
        message: err instanceof Error ? err.message : String(err),
      });
    }
  });

  if (errors.length > 0) {
    const first = errors[0];
    return {
      ok: false,
      lines: values,
      errors,
      error: {
        message: `NDJSON satır ${first.line}: ${first.message}`,
        line: first.line,
        column: 1,
      },
    };
  }

  return { ok: true, lines: values, errors: [], error: null };
}

export function formatNdjson(text: string, indent = 2): string {
  return text
    .split(/\r?\n/)
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return "";
      return JSON.stringify(JSON.parse(trimmed), null, indent);
    })
    .filter((l, i, arr) => l !== "" || arr.slice(i).some((x) => x.trim()))
    .join("\n");
}

export function minifyNdjson(text: string): string {
  return text
    .split(/\r?\n/)
    .map((line) => {
      const trimmed = line.trim();
      if (!trimmed) return "";
      return JSON.stringify(JSON.parse(trimmed));
    })
    .filter(Boolean)
    .join("\n");
}

export function ndjsonToArray(text: string): unknown[] {
  return parseNdjson(text).lines;
}

export function arrayToNdjson(values: unknown[]): string {
  return values.map((v) => JSON.stringify(v)).join("\n");
}

export function parseJsonErrorForNdjson(text: string, err: Error): JsonError {
  const base = parseJsonError(text, err);
  const lineMatch = base.message.match(/NDJSON satır (\d+)/);
  if (lineMatch) {
    return { ...base, line: parseInt(lineMatch[1], 10) };
  }
  return base;
}
