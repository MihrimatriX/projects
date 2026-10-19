import { JSONPath } from "jsonpath-plus";
import { escapePointerSegment } from "./json-utils";

export interface JsonPathQueryResult {
  ok: boolean;
  paths: string[];
  values: unknown[];
  error: string | null;
  count: number;
}

/** JSONPath sonuçlarını JSON Pointer setine çevirir (ağaç vurgusu için). */
export function valueToPointerPaths(root: unknown, target: unknown, base = "/"): string[] {
  const found: string[] = [];

  const walk = (node: unknown, path: string) => {
    if (node === target) {
      found.push(path);
      return;
    }
    if (node === null || typeof node !== "object") return;

    if (Array.isArray(node)) {
      node.forEach((item, i) => walk(item, `${path}/${i}`));
    } else {
      for (const key of Object.keys(node as Record<string, unknown>)) {
        const seg = escapePointerSegment(key);
        const next = path === "/" ? `/${seg}` : `${path}/${seg}`;
        walk((node as Record<string, unknown>)[key], next);
      }
    }
  };

  walk(root, base);
  return found;
}

export function queryJsonPath(data: unknown, expression: string): JsonPathQueryResult {
  const expr = expression.trim();
  if (!expr) {
    return { ok: true, paths: [], values: [], error: null, count: 0 };
  }

  try {
    // wrap: true -> her zaman eslesme dizisi (eslesme yoksa bos; tek eslesmeli dizi degeri de tek oge).
    const list = (JSONPath({ path: expr, json: data as object, wrap: true }) as unknown[] | undefined) ?? [];
    // Vurgu için eşleşmelerin gerçek JSON Pointer'ları alınır. Değer eşitliğiyle arama
    // (valueToPointerPaths) aynı ilkel değere sahip ilgisiz düğümleri de vurguluyordu.
    // Kök pointer "" → ağaçtaki kök yolu "/".
    const pointers = JSONPath({ path: expr, json: data as object, resultType: "pointer", wrap: true }) as string[];
    const paths = new Set<string>(pointers.map((p) => p || "/"));

    return {
      ok: true,
      paths: [...paths],
      values: list,
      error: null,
      count: list.length,
    };
  } catch (err) {
    return {
      ok: false,
      paths: [],
      values: [],
      error: err instanceof Error ? err.message : String(err),
      count: 0,
    };
  }
}
