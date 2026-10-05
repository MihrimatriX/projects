import { countNodes, getJsonByteSize, JsonError, parseJsonError } from "../json-utils";
import {
  arrayToNdjson,
  InputMode,
  parseNdjson,
} from "../ndjson";

export const WORKER_PARSE_THRESHOLD = 512 * 1024;

export interface ParseSuccess {
  ok: true;
  parsed: unknown;
  parseTime: number;
  nodeCount: number;
  fileSize: number;
}

export interface ParseFailure {
  ok: false;
  error: JsonError;
  parseTime: number;
  fileSize: number;
}

export type ParseOutcome = ParseSuccess | ParseFailure;

function syncParseJson(text: string): ParseOutcome {
  const fileSize = getJsonByteSize(text);
  const start = performance.now();
  try {
    const parsed = JSON.parse(text);
    const parseTime = parseFloat((performance.now() - start).toFixed(2));
    return {
      ok: true,
      parsed,
      parseTime,
      nodeCount: countNodes(parsed),
      fileSize,
    };
  } catch (err) {
    return {
      ok: false,
      error: parseJsonError(text, err instanceof Error ? err : new Error(String(err))),
      parseTime: parseFloat((performance.now() - start).toFixed(2)),
      fileSize,
    };
  }
}

function syncParseNdjson(text: string): ParseOutcome {
  const fileSize = getJsonByteSize(text);
  const start = performance.now();
  const result = parseNdjson(text);
  const parseTime = parseFloat((performance.now() - start).toFixed(2));

  if (!result.ok || result.error) {
    return {
      ok: false,
      error: result.error ?? {
        message: "NDJSON doğrulama hatası",
        line: 1,
        column: 1,
      },
      parseTime,
      fileSize,
    };
  }

  const parsed = result.lines;
  return {
    ok: true,
    parsed,
    parseTime,
    nodeCount: countNodes(parsed),
    fileSize,
  };
}

let worker: Worker | null = null;

function getParseWorker(): Worker | null {
  if (typeof window === "undefined") return null;
  if (worker) return worker;

  const script = `
    self.onmessage = function(ev) {
      if (ev.data.type !== "parse") return;
      var id = ev.data.id;
      var text = ev.data.text;
      var fileSize = new Blob([text]).size;
      var start = performance.now();
      try {
        var parsed = JSON.parse(text);
        self.postMessage({
          id: id,
          ok: true,
          parsed: parsed,
          parseTime: parseFloat((performance.now() - start).toFixed(2)),
          nodeCount: 1,
          fileSize: fileSize
        });
      } catch (err) {
        var msg = err && err.message ? err.message : String(err);
        var line = 1, column = 1, position = 0;
        var posMatch = msg.match(/at position (\\d+)/i);
        var lineColMatch = msg.match(/line (\\d+) column (\\d+)/i);
        if (lineColMatch) {
          line = parseInt(lineColMatch[1], 10);
          column = parseInt(lineColMatch[2], 10);
        } else if (posMatch) {
          position = parseInt(posMatch[1], 10);
          var sub = text.substring(0, position);
          var lines = sub.split("\\n");
          line = lines.length;
          column = lines[lines.length - 1].length + 1;
        }
        self.postMessage({
          id: id,
          ok: false,
          error: { message: msg.replace(/in JSON at position \\d+/i, "").trim(), line: line, column: column, position: position || undefined },
          parseTime: parseFloat((performance.now() - start).toFixed(2)),
          fileSize: fileSize
        });
      }
    };
  `;

  const blob = new Blob([script], { type: "application/javascript" });
  worker = new Worker(URL.createObjectURL(blob));
  return worker;
}

let workerRequestSeq = 0;

// Büyük metin (>= 512 KB) ana thread'i kilitlememek için Blob URL'li inline worker'da parse edilir.
// Worker tek ve paylaşımlı: her istek bir id taşır, yanıt id'si eşleşmeyen dinleyici yok sayar
// (aksi halde hızlı yazarken eski metnin sonucu yeni isteğe dönüyordu).
function workerParseJson(text: string): Promise<ParseOutcome> {
  return new Promise((resolve) => {
    const w = getParseWorker();
    if (!w) {
      resolve(syncParseJson(text));
      return;
    }

    const id = ++workerRequestSeq;
    const onMessage = (ev: MessageEvent<ParseOutcome & { nodeCount?: number; id?: number }>) => {
      if (ev.data.id !== id) return;
      w.removeEventListener("message", onMessage);
      const data = ev.data;
      if (data.ok && data.parsed !== undefined) {
        resolve({
          ...data,
          nodeCount: countNodes(data.parsed),
        });
      } else {
        resolve(data);
      }
    };

    w.addEventListener("message", onMessage);
    w.postMessage({ type: "parse", id, text });
  });
}

export async function parseContent(
  text: string,
  mode: InputMode
): Promise<ParseOutcome> {
  if (text.trim() === "") {
    return {
      ok: true,
      parsed: null,
      parseTime: 0,
      nodeCount: 0,
      fileSize: 0,
    };
  }

  if (mode === "ndjson") {
    return syncParseNdjson(text);
  }

  if (typeof window !== "undefined" && text.length >= WORKER_PARSE_THRESHOLD) {
    return workerParseJson(text);
  }

  return syncParseJson(text);
}

export function stringifyFormatted(data: unknown, indent: number, mode: InputMode): string {
  if (mode === "ndjson" && Array.isArray(data)) {
    return arrayToNdjson(data);
  }
  return JSON.stringify(data, null, indent);
}

export function stringifyMinified(data: unknown, mode: InputMode): string {
  if (mode === "ndjson" && Array.isArray(data)) {
    return arrayToNdjson(data);
  }
  return JSON.stringify(data);
}
