import { createTwoFilesPatch } from "diff";

export type ParsedGitDiff = {
  fileName: string;
  left: string;
  right: string;
};

export function createUnifiedPatch(
  fileName: string,
  oldContent: string,
  newContent: string
): string {
  return createTwoFilesPatch(
    fileName,
    fileName,
    oldContent,
    newContent,
    "",
    ""
  );
}

/** Tek veya çok dosyalı `git diff` / unified diff metnini ayrıştırır. */
export function parseGitDiff(text: string): ParsedGitDiff[] {
  const chunks = text.split(/^diff --git /m).filter((c) => c.trim());
  const results: ParsedGitDiff[] = [];

  for (const chunk of chunks) {
    const lines = chunk.split("\n");
    const header = lines[0] ?? "";
    const fileMatch = header.match(/a\/(.+?)\s+b\/(.+)/) ?? header.match(/(.+?)\s+(.+)/);
    const fileName = fileMatch ? (fileMatch[2] || fileMatch[1]).trim() : "unknown";

    let leftLines: string[] = [];
    let rightLines: string[] = [];
    let inHunk = false;

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i];
      if (line.startsWith("@@")) {
        inHunk = true;
        continue;
      }
      if (!inHunk) continue;
      if (line.startsWith("---") || line.startsWith("+++") || line.startsWith("\\")) continue;
      if (line.startsWith("-")) leftLines.push(line.slice(1));
      else if (line.startsWith("+")) rightLines.push(line.slice(1));
      else if (line.startsWith(" ")) {
        const content = line.slice(1);
        leftLines.push(content);
        rightLines.push(content);
      }
    }

    // Hunk içermeyen parça (düz metin, yalnızca mod değişikliği) diff sayılmaz.
    if (!inHunk) continue;
    results.push({
      fileName,
      left: leftLines.join("\n"),
      right: rightLines.join("\n"),
    });
  }

  if (results.length === 0 && text.includes("@@")) {
    const single = parseSingleHunkDiff(text);
    if (single) results.push(single);
  }

  return results;
}

function parseSingleHunkDiff(text: string): ParsedGitDiff | null {
  const lines = text.split("\n");
  const leftLines: string[] = [];
  const rightLines: string[] = [];
  let started = false;

  for (const line of lines) {
    if (line.startsWith("@@")) {
      started = true;
      continue;
    }
    if (!started) continue;
    if (line.startsWith("---") || line.startsWith("+++") || line.startsWith("diff ")) continue;
    if (line.startsWith("-")) leftLines.push(line.slice(1));
    else if (line.startsWith("+")) rightLines.push(line.slice(1));
    else if (line.startsWith(" ")) {
      leftLines.push(line.slice(1));
      rightLines.push(line.slice(1));
    }
  }

  if (leftLines.length === 0 && rightLines.length === 0) return null;
  return { fileName: "pasted.diff", left: leftLines.join("\n"), right: rightLines.join("\n") };
}
