import type { ExplanationBlock, RegexMatch } from "./types";

function previewAt(text: string, position: number, radius = 18): string {
  if (!text) return "";

  const start = Math.max(0, position - radius);
  const end = Math.min(text.length, position + radius);
  let snippet = text.slice(start, end);

  if (start > 0) snippet = "…" + snippet;
  if (end < text.length) snippet = snippet + "…";

  return snippet.replace(/\n/g, "↵");
}

export function enrichExplanationContext(
  blocks: ExplanationBlock[],
  testText: string,
  matches: RegexMatch[]
): ExplanationBlock[] {
  if (!testText || blocks.length === 0) return blocks;

  const anchor = matches[0]?.index ?? 0;
  const span = Math.max(1, matches[0]?.length ?? 1);

  return blocks.map((block, idx) => {
    const progress = blocks.length === 1 ? 0 : idx / (blocks.length - 1);
    const position = Math.min(
      testText.length,
      Math.max(0, anchor + Math.floor(progress * span))
    );

    return {
      ...block,
      contextSnippet: previewAt(testText, position),
    };
  });
}
