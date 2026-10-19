import fs from "fs";

const BYTES_PER_LINE = 16;
const MAX_HEX_BYTES = 256 * 1024;

export function formatHexDump(buf: Buffer, maxBytes = MAX_HEX_BYTES): string {
  const len = Math.min(buf.length, maxBytes);
  const lines: string[] = [];
  for (let offset = 0; offset < len; offset += BYTES_PER_LINE) {
    const slice = buf.subarray(offset, Math.min(offset + BYTES_PER_LINE, len));
    const hex = [...slice].map((b) => b.toString(16).padStart(2, "0")).join(" ");
    const ascii = [...slice]
      .map((b) => (b >= 32 && b < 127 ? String.fromCharCode(b) : "."))
      .join("");
    const pad = "   ".repeat(BYTES_PER_LINE - slice.length);
    lines.push(
      `${offset.toString(16).padStart(8, "0")}  ${hex.padEnd(BYTES_PER_LINE * 3 - 1)}${pad}  |${ascii}|`
    );
  }
  if (buf.length > maxBytes) {
    lines.push(`... (${buf.length - maxBytes} bayt daha)`);
  }
  return lines.join("\n");
}

export function readHexFile(filePath: string): { hex: string; size: number; truncated: boolean } {
  const stat = fs.statSync(filePath);
  const readLen = Math.min(stat.size, MAX_HEX_BYTES);
  const fd = fs.openSync(filePath, "r");
  const buf = Buffer.alloc(readLen);
  fs.readSync(fd, buf, 0, readLen, 0);
  fs.closeSync(fd);
  return {
    hex: formatHexDump(buf, readLen),
    size: stat.size,
    truncated: stat.size > MAX_HEX_BYTES,
  };
}
