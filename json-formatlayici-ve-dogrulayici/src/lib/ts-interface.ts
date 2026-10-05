function typeOfValue(value: unknown, name: string): string {
  if (value === null) return "null";
  if (Array.isArray(value)) {
    if (value.length === 0) return "unknown[]";
    const types = new Set(value.map((v) => typeOfValue(v, name)));
    if (types.size === 1) return `${[...types][0]}[]`;
    return `(${[...types].join(" | ")})[]`;
  }
  if (typeof value === "object") {
    return toInterface(value as Record<string, unknown>, name);
  }
  if (typeof value === "number") return Number.isInteger(value) ? "number" : "number";
  if (typeof value === "boolean") return "boolean";
  if (typeof value === "string") return "string";
  return "unknown";
}

function safePropName(key: string): string {
  return /^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(key) ? key : `"${key.replace(/"/g, '\\"')}"`;
}

export function jsonToTypeScript(rootName: string, data: unknown): string {
  const body = typeOfValue(data, rootName);
  if (body.startsWith("{")) {
    return `export type ${rootName} = ${body};\n`;
  }
  return `export type ${rootName} = ${body};\n`;
}

function toInterface(obj: Record<string, unknown>, name: string): string {
  const lines = Object.entries(obj).map(([key, val]) => {
    return `  ${safePropName(key)}: ${typeOfValue(val, key)};`;
  });
  return `{\n${lines.join("\n")}\n}`;
}
