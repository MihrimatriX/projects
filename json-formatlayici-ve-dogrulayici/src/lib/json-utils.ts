export const LARGE_FILE_BYTES = 5 * 1024 * 1024;

export interface JsonError {
  message: string;
  line: number;
  column: number;
  position?: number;
}

export function getJsonByteSize(json: string): number {
  return new Blob([json]).size;
}

export function isLargeJson(json: string): boolean {
  return getJsonByteSize(json) > LARGE_FILE_BYTES;
}

export function countNodes(obj: unknown): number {
  if (obj === null || typeof obj !== "object") return 1;
  let count = 1;
  if (Array.isArray(obj)) {
    for (const val of obj) {
      count += countNodes(val);
    }
  } else {
    for (const key of Object.keys(obj as Record<string, unknown>)) {
      count += countNodes((obj as Record<string, unknown>)[key]);
    }
  }
  return count;
}

export function sortObjectKeys(obj: unknown): unknown {
  if (obj === null || typeof obj !== "object") return obj;
  if (Array.isArray(obj)) {
    return obj.map(sortObjectKeys);
  }

  const sorted: Record<string, unknown> = {};
  const keys = Object.keys(obj as Record<string, unknown>).sort();
  for (const key of keys) {
    sorted[key] = sortObjectKeys((obj as Record<string, unknown>)[key]);
  }
  return sorted;
}

export function parseJsonError(json: string, err: Error): JsonError {
  const msg = err.message;
  let line = 1;
  let column = 1;
  let position = 0;

  const posMatch = msg.match(/at position (\d+)/i);
  const lineColMatch = msg.match(/line (\d+) column (\d+)/i);

  if (lineColMatch) {
    line = parseInt(lineColMatch[1], 10);
    column = parseInt(lineColMatch[2], 10);
  } else if (posMatch) {
    position = parseInt(posMatch[1], 10);
    const subStr = json.substring(0, position);
    const lines = subStr.split("\n");
    line = lines.length;
    column = lines[lines.length - 1].length + 1;
  }

  return {
    message: msg.replace(/in JSON at position \d+/i, "").trim(),
    line,
    column,
    position: position || undefined,
  };
}

export function pointerToJsonPath(pointerPath: string): string {
  if (pointerPath === "/") return "$";
  const parts = pointerPath.split("/").slice(1);
  let jsonPath = "$";
  for (const part of parts) {
    const decoded = part.replace(/~1/g, "/").replace(/~0/g, "~");
    if (/^\d+$/.test(decoded)) {
      jsonPath += `[${decoded}]`;
    } else if (/^[a-zA-Z_$][a-zA-Z0-9_$]*$/.test(decoded)) {
      jsonPath += `.${decoded}`;
    } else {
      jsonPath += `["${decoded.replace(/"/g, '\\"')}"]`;
    }
  }
  return jsonPath;
}

export function escapePointerSegment(key: string): string {
  return key.replace(/~/g, "~0").replace(/\//g, "~1");
}

export function formatFileSize(bytes: number): string {
  if (bytes === 0) return "0 B";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}
