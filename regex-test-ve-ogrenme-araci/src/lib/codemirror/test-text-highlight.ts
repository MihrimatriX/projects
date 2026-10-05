import { Facet } from "@codemirror/state";
import {
  Decoration,
  DecorationSet,
  EditorView,
  ViewPlugin,
  ViewUpdate,
} from "@codemirror/view";
import type { RegexMatch } from "@/lib/regex/types";

export interface MatchHighlightState {
  matches: RegexMatch[];
  selectedIndex: number | null;
}

export const matchHighlightFacet = Facet.define<MatchHighlightState, MatchHighlightState>({
  combine: (values) => values[values.length - 1] ?? { matches: [], selectedIndex: null },
});

const MATCH_CLASSES = [
  "cm-match-0",
  "cm-match-1",
  "cm-match-2",
  "cm-match-3",
];

function buildMatchDecorations(
  text: string,
  matches: RegexMatch[],
  selectedIndex: number | null
): DecorationSet {
  const sorted = [...matches].sort((a, b) => a.index - b.index);
  const ranges: ReturnType<Decoration["range"]>[] = [];
  let lastIndex = 0;

  sorted.forEach((match, index) => {
    // Boş eşleşme (a*, ^, ) mark olamaz: RangeError fırlatır ve CodeMirror eklentiyi kalıcı kapatır.
    // Eşleşmeler async geldiğinden, kısalmış metnin dışına taşan eski aralıklar da atlanır.
    if (match.index < lastIndex || match.length === 0 || match.index + match.length > text.length) return;

    const className = MATCH_CLASSES[index % MATCH_CLASSES.length];
    const selected = selectedIndex === index ? " cm-match-selected" : "";

    ranges.push(
      Decoration.mark({ class: `${className}${selected}` }).range(
        match.index,
        match.index + match.length
      )
    );

    lastIndex = match.index + match.length;
  });

  return Decoration.set(ranges, true);
}

const matchHighlighter = ViewPlugin.fromClass(
  class {
    decorations: DecorationSet;

    constructor(view: EditorView) {
      const { matches, selectedIndex } = view.state.facet(matchHighlightFacet);
      this.decorations = buildMatchDecorations(
        view.state.doc.toString(),
        matches,
        selectedIndex
      );
    }

    update(update: ViewUpdate) {
      const prev = update.startState.facet(matchHighlightFacet);
      const next = update.state.facet(matchHighlightFacet);
      const facetChanged =
        prev.matches !== next.matches || prev.selectedIndex !== next.selectedIndex;

      if (update.docChanged || facetChanged) {
        this.decorations = buildMatchDecorations(
          update.state.doc.toString(),
          next.matches,
          next.selectedIndex
        );
      }
    }
  },
  { decorations: (plugin) => plugin.decorations }
);

export const testTextEditorTheme = EditorView.theme({
  "&": {
    backgroundColor: "transparent",
    fontSize: "14px",
    height: "100%",
  },
  ".cm-scroller": {
    overflow: "auto",
    fontFamily: "var(--font-mono), 'JetBrains Mono', monospace",
    lineHeight: "1.625",
  },
  ".cm-content": {
    caretColor: "#f43f5e",
    padding: "16px",
    color: "#cbd5e1",
  },
  ".cm-line": {
    padding: "0",
  },
  ".cm-cursor": {
    borderLeftColor: "#f43f5e",
  },
  ".cm-selectionBackground, &.cm-focused .cm-selectionBackground": {
    backgroundColor: "rgba(244, 63, 94, 0.2) !important",
  },
  ".cm-match-0": {
    backgroundColor: "var(--match-0)",
    borderRadius: "2px",
    fontWeight: "600",
  },
  ".cm-match-1": {
    backgroundColor: "var(--match-1)",
    borderRadius: "2px",
    fontWeight: "600",
  },
  ".cm-match-2": {
    backgroundColor: "var(--match-2)",
    borderRadius: "2px",
    fontWeight: "600",
  },
  ".cm-match-3": {
    backgroundColor: "var(--match-3)",
    borderRadius: "2px",
    fontWeight: "600",
  },
  ".cm-match-selected": {
    outline: "2px solid rgba(255,255,255,0.75)",
    outlineOffset: "1px",
  },
});

export function testTextHighlightExtension(state: MatchHighlightState) {
  return [matchHighlightFacet.of(state), matchHighlighter, testTextEditorTheme];
}

export function scrollToMatch(view: EditorView, match: RegexMatch) {
  const line = view.state.doc.line(Math.min(view.state.doc.lines, Math.max(1, match.line)));
  view.dispatch({
    effects: EditorView.scrollIntoView(line.from, { y: "center" }),
  });
}
