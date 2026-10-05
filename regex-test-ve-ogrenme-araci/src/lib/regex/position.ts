export function indexToPosition(text: string, index: number): { line: number; column: number } {
  const before = text.slice(0, index);
  const lines = before.split("\n");
  return {
    line: lines.length,
    column: (lines[lines.length - 1]?.length ?? 0) + 1,
  };
}

export function formatPosition(line: number, column: number): string {
  return `Satır ${line}, Sütun ${column}`;
}

export const LARGE_TEXT_THRESHOLD = 50_000;
