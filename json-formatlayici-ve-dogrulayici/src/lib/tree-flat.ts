import { escapePointerSegment } from "./json-utils";

export type FlatTreeRowKind = "branch" | "primitive" | "close";

export interface FlatTreeRow {
  id: string;
  path: string;
  name: string;
  value: unknown;
  depth: number;
  kind: FlatTreeRowKind;
  isArray: boolean;
  childCount: number;
  isExpanded: boolean;
}

export function buildFlatTree(
  root: unknown,
  expandedPaths: Set<string>,
  options?: { highlightPaths?: Set<string> }
): FlatTreeRow[] {
  const rows: FlatTreeRow[] = [];
  const highlight = options?.highlightPaths;

  const pushBranch = (
    path: string,
    name: string,
    value: unknown,
    depth: number,
    isArray: boolean
  ) => {
    const keys = value !== null && typeof value === "object" ? Object.keys(value as object) : [];
    const isExpanded = expandedPaths.has(path);
    rows.push({
      id: path,
      path,
      name,
      value,
      depth,
      kind: "branch",
      isArray,
      childCount: keys.length,
      isExpanded,
    });

    if (!isExpanded || keys.length === 0) return;

    if (Array.isArray(value)) {
      (value as unknown[]).forEach((item, idx) => {
        visit(item, `${path}/${idx}`, "", depth + 1);
      });
    } else {
      for (const key of keys) {
        const seg = escapePointerSegment(key);
        const childPath = path === "/" ? `/${seg}` : `${path}/${seg}`;
        visit(
          (value as Record<string, unknown>)[key],
          childPath,
          key,
          depth + 1
        );
      }
    }

    rows.push({
      id: `${path}__close`,
      path,
      name: "",
      value: null,
      depth,
      kind: "close",
      isArray,
      childCount: 0,
      isExpanded: true,
    });
  };

  const visit = (value: unknown, path: string, name: string, depth: number) => {
    const isObject = value !== null && typeof value === "object";
    if (isObject) {
      pushBranch(path, name, value, depth, Array.isArray(value));
      return;
    }

    rows.push({
      id: path,
      path,
      name,
      value,
      depth,
      kind: "primitive",
      isArray: false,
      childCount: 0,
      isExpanded: false,
    });

    if (highlight?.has(path)) {
      /* highlight handled in UI via path set */
    }
  };

  visit(root, "/", "", 0);
  return rows;
}

export function collectAllPaths(root: unknown): Set<string> {
  const paths = new Set<string>(["/"]);

  const walk = (value: unknown, path: string) => {
    paths.add(path);
    if (value === null || typeof value !== "object") return;

    if (Array.isArray(value)) {
      value.forEach((item, i) => walk(item, `${path}/${i}`));
    } else {
      for (const key of Object.keys(value as Record<string, unknown>)) {
        const seg = escapePointerSegment(key);
        const next = path === "/" ? `/${seg}` : `${path}/${seg}`;
        walk((value as Record<string, unknown>)[key], next);
      }
    }
  };

  walk(root, "/");
  return paths;
}
