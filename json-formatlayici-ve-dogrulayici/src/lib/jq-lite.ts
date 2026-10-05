/**
 * jq-lite: eval kullanmadan sınırlı pipeline.
 * Adımlar: `.` `.key` `.["k"]` `.[n]` `.[]` `keys` `length` `first` `last`
 * Pipeline: `.users | .[] | .name`
 */

export interface JqLiteResult {
  ok: boolean;
  result: unknown;
  error: string | null;
}

function splitPipeline(expr: string): string[] {
  const steps: string[] = [];
  let current = "";
  let depth = 0;
  let inString = false;

  for (let i = 0; i < expr.length; i++) {
    const c = expr[i];
    if (c === '"' && expr[i - 1] !== "\\") inString = !inString;
    if (!inString) {
      if (c === "[" || c === "(") depth++;
      if (c === "]" || c === ")") depth--;
      if (c === "|" && depth === 0) {
        if (current.trim()) steps.push(current.trim());
        current = "";
        continue;
      }
    }
    current += c;
  }
  if (current.trim()) steps.push(current.trim());
  return steps.length ? steps : [expr.trim()];
}

function applyStep(values: unknown[], step: string): unknown[] {
  const out: unknown[] = [];

  for (const value of values) {
    if (step === "." || step === "") {
      out.push(value);
      continue;
    }

    if (step === ".[]") {
      if (Array.isArray(value)) out.push(...value);
      continue;
    }

    if (step === "keys") {
      if (value !== null && typeof value === "object" && !Array.isArray(value)) {
        out.push(Object.keys(value as Record<string, unknown>));
      }
      continue;
    }

    if (step === "length") {
      if (typeof value === "string" || Array.isArray(value)) out.push(value.length);
      continue;
    }

    if (step === "first") {
      if (Array.isArray(value) && value.length > 0) out.push(value[0]);
      continue;
    }

    if (step === "last") {
      if (Array.isArray(value) && value.length > 0) out.push(value[value.length - 1]);
      continue;
    }

    const bracketIndex = step.match(/^\.?\[(\d+)\]$/);
    if (bracketIndex) {
      const idx = parseInt(bracketIndex[1], 10);
      if (Array.isArray(value) && idx >= 0 && idx < value.length) out.push(value[idx]);
      continue;
    }

    const bracketKey = step.match(/^\.?\["([^"\\]*(?:\\.[^"\\]*)*)"\]$/);
    if (bracketKey) {
      const key = bracketKey[1].replace(/\\"/g, '"');
      if (value !== null && typeof value === "object" && !Array.isArray(value)) {
        out.push((value as Record<string, unknown>)[key]);
      }
      continue;
    }

    if (step.startsWith(".")) {
      const rest = step.slice(1);
      const parts = rest.split(/\.(?!\d)/).filter(Boolean);
      let cur: unknown = value;
      for (const part of parts) {
        if (part === "[]") {
          if (!Array.isArray(cur)) {
            cur = undefined;
            break;
          }
          out.push(...cur);
          cur = undefined;
          break;
        }
        const idxMatch = part.match(/^\[(\d+)\]$/);
        if (idxMatch) {
          const idx = parseInt(idxMatch[1], 10);
          cur = Array.isArray(cur) ? cur[idx] : undefined;
        } else {
          cur =
            cur !== null && typeof cur === "object" && !Array.isArray(cur)
              ? (cur as Record<string, unknown>)[part]
              : undefined;
        }
      }
      if (cur !== undefined && !rest.includes("[]")) out.push(cur);
      continue;
    }

    throw new Error(`Desteklenmeyen adım: ${step}`);
  }

  return out;
}

export function runJqLite(data: unknown, expression: string): JqLiteResult {
  const expr = expression.trim();
  if (!expr) {
    return { ok: true, result: data, error: null };
  }

  try {
    const pipeline = splitPipeline(expr);
    let values: unknown[] = [data];

    for (const step of pipeline) {
      values = applyStep(values, step.startsWith(".") || step === "keys" || step === "length" || step === "first" || step === "last" ? step : `.${step}`);
      if (values.length === 0) break;
    }

    const result = values.length === 1 ? values[0] : values;
    return { ok: true, result, error: null };
  } catch (err) {
    return {
      ok: false,
      result: null,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}
