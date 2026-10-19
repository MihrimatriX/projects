import {
  Decoration,
  DecorationSet,
  EditorView,
  ViewPlugin,
  ViewUpdate,
} from "@codemirror/view";

const styles = {
  group: "cm-regex-group",
  quantifier: "cm-regex-quantifier",
  charClass: "cm-regex-charclass",
  anchor: "cm-regex-anchor",
  meta: "cm-regex-meta",
  escape: "cm-regex-escape",
  alternation: "cm-regex-alternation",
};

function addRange(
  ranges: { from: number; to: number; className: string }[],
  from: number,
  to: number,
  className: string
) {
  if (from < to) ranges.push({ from, to, className });
}

function buildDecorations(text: string): DecorationSet {
  const ranges: { from: number; to: number; className: string }[] = [];
  let i = 0;

  while (i < text.length) {
    const ch = text[i];

    if (ch === "\\" && i + 1 < text.length) {
      const next = text[i + 1];
      if ("dDwWsS".includes(next)) {
        addRange(ranges, i, i + 2, styles.meta);
      } else if ("bB".includes(next)) {
        addRange(ranges, i, i + 2, styles.anchor);
      } else {
        addRange(ranges, i, i + 2, styles.escape);
      }
      i += 2;
      continue;
    }

    if (ch === "[") {
      let j = i + 1;
      if (text[j] === "^") j++;
      while (j < text.length && text[j] !== "]") {
        if (text[j] === "\\") j++;
        j++;
      }
      addRange(ranges, i, Math.min(j + 1, text.length), styles.charClass);
      i = Math.min(j + 1, text.length);
      continue;
    }

    if (ch === "(") {
      let depth = 1;
      let j = i + 1;
      while (j < text.length && depth > 0) {
        if (text[j] === "\\") j++;
        else if (text[j] === "(") depth++;
        else if (text[j] === ")") depth--;
        j++;
      }
      addRange(ranges, i, j, styles.group);
      i = j;
      continue;
    }

    if (ch === "^" || ch === "$") {
      addRange(ranges, i, i + 1, styles.anchor);
      i++;
      continue;
    }

    if ("+*?".includes(ch)) {
      addRange(ranges, i, i + 1, styles.quantifier);
      i++;
      continue;
    }

    if (ch === "{") {
      const close = text.indexOf("}", i);
      addRange(ranges, i, close >= 0 ? close + 1 : i + 1, styles.quantifier);
      i = close >= 0 ? close + 1 : i + 1;
      continue;
    }

    if (ch === "|") {
      addRange(ranges, i, i + 1, styles.alternation);
      i++;
      continue;
    }

    if (ch === ".") {
      addRange(ranges, i, i + 1, styles.meta);
    }

    i++;
  }

  return Decoration.set(
    ranges.map(({ from, to, className }) =>
      Decoration.mark({ class: className }).range(from, to)
    )
  );
}

const regexHighlighter = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      this.decorations = buildDecorations(view.state.doc.toString());
    }

    update(update: ViewUpdate) {
      if (update.docChanged) {
        this.decorations = buildDecorations(update.state.doc.toString());
      }
    }
  },
  { decorations: (plugin) => plugin.decorations }
);

export const regexEditorTheme = EditorView.theme({
  "&": {
    backgroundColor: "transparent",
    fontSize: "14px",
    maxHeight: "120px",
  },
  ".cm-scroller": {
    overflow: "auto",
    fontFamily: "var(--font-mono), 'JetBrains Mono', monospace",
  },
  ".cm-content": {
    caretColor: "#f43f5e",
    padding: "12px 14px",
  },
  ".cm-line": {
    padding: "0 2px",
  },
  ".cm-cursor": {
    borderLeftColor: "#f43f5e",
  },
  ".cm-selectionBackground, &.cm-focused .cm-selectionBackground": {
    backgroundColor: "rgba(244, 63, 94, 0.2) !important",
  },
  ".cm-regex-group": { color: "#fb7185" },
  ".cm-regex-quantifier": { color: "#34d399", fontWeight: "700" },
  ".cm-regex-charclass": { color: "#22d3ee" },
  ".cm-regex-anchor": { color: "#fbbf24", fontWeight: "700" },
  ".cm-regex-meta": { color: "#a78bfa" },
  ".cm-regex-escape": { color: "#94a3b8" },
  ".cm-regex-alternation": { color: "#f472b6", fontWeight: "700" },
});

export function regexHighlightExtension() {
  return [regexHighlighter, regexEditorTheme];
}
