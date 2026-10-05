"use client";

import { useEffect, useMemo, useRef } from "react";
import { EditorState, Compartment } from "@codemirror/state";
import {
  EditorView,
  keymap,
  lineNumbers,
  highlightActiveLine,
  highlightActiveLineGutter,
  drawSelection,
  Decoration,
  ViewPlugin,
  ViewUpdate,
} from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, isolateHistory } from "@codemirror/commands";
import { json } from "@codemirror/lang-json";
import { bracketMatching } from "@codemirror/language";
import { linter, type Diagnostic } from "@codemirror/lint";
import { placeholder } from "@codemirror/view";
import { useJsonStore } from "@/lib/store";

function errorLineHighlight(error: { line: number } | null) {
  return ViewPlugin.fromClass(
    class {
      decorations = Decoration.none;

      update(update: ViewUpdate) {
        if (!error) {
          this.decorations = Decoration.none;
          return;
        }
        const lineNo = Math.min(Math.max(1, error.line), update.view.state.doc.lines);
        const line = update.view.state.doc.line(lineNo);
        this.decorations = Decoration.set([
          Decoration.line({
            attributes: { class: "cm-errorLine" },
          }).range(line.from),
        ]);
      }
    },
    {
      decorations: (v) => v.decorations,
    }
  );
}

function buildJsonLinter(error: { message: string; line: number; column: number } | null) {
  return linter((view): Diagnostic[] => {
    if (!error) return [];
    const lineNo = Math.min(Math.max(1, error.line), view.state.doc.lines);
    const line = view.state.doc.line(lineNo);
    const from = Math.min(line.to, line.from + Math.max(0, error.column - 1));
    return [
      {
        from,
        to: line.to,
        severity: "error",
        message: error.message,
      },
    ];
  });
}

export default function CodeMirrorEditor() {
  const containerRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const isUpdatingRef = useRef(false);
  const themeCompartment = useRef(new Compartment());
  const lintCompartment = useRef(new Compartment());
  const errorLineCompartment = useRef(new Compartment());
  const { rawJson, setRawJson, error } = useJsonStore();

  const editorTheme = useMemo(
    () =>
      EditorView.theme(
        {
          "&": {
            color: "var(--text-primary)",
            backgroundColor: "var(--bg-editor)",
            height: "100%",
            fontFamily: "var(--font-mono), 'Fira Code', monospace",
            fontSize: "13px",
          },
          ".cm-content": {
            caretColor: "var(--accent)",
            padding: "10px 0",
          },
          "&.cm-focused .cm-cursor": {
            borderLeftColor: "var(--accent)",
          },
          "&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection": {
            backgroundColor: "var(--selection) !important",
          },
          ".cm-gutters": {
            backgroundColor: "var(--bg-sidebar)",
            color: "var(--text-muted)",
            borderRight: "1px solid var(--border)",
            paddingRight: "6px",
          },
          ".cm-activeLine": {
            backgroundColor: "var(--bg-hover)",
          },
          ".cm-activeLineGutter": {
            backgroundColor: "var(--bg-hover)",
            color: "var(--accent)",
          },
          ".cm-errorLine": {
            backgroundColor: "var(--error-bg)",
          },
          ".cm-lintRange-error": {
            backgroundImage: "underline wavy var(--error)",
          },
        },
        { dark: true }
      ),
    []
  );

  useEffect(() => {
    if (!containerRef.current) return;

    const extensions = [
      lineNumbers(),
      highlightActiveLineGutter(),
      highlightActiveLine(),
      drawSelection(),
      bracketMatching(),
      history(),
      json(),
      editorTheme,
      themeCompartment.current.of([]),
      lintCompartment.current.of(buildJsonLinter(error)),
      errorLineCompartment.current.of(errorLineHighlight(error)),
      placeholder("JSON yapıştırın veya Demo Yükle ile başlayın…"),
      keymap.of([...defaultKeymap, ...historyKeymap]),
      EditorView.updateListener.of((update) => {
        if (update.docChanged && !isUpdatingRef.current) {
          setRawJson(update.state.doc.toString());
        }
      }),
      EditorView.lineWrapping,
      EditorView.contentAttributes.of({ "aria-label": "JSON metni" }),
    ];

    const state = EditorState.create({
      doc: rawJson,
      extensions,
    });

    const view = new EditorView({ state, parent: containerRef.current });
    viewRef.current = view;

    return () => {
      view.destroy();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- mount once
  }, []);

  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;
    view.dispatch({
      effects: [
        themeCompartment.current.reconfigure(editorTheme),
        lintCompartment.current.reconfigure(buildJsonLinter(error)),
        errorLineCompartment.current.reconfigure(errorLineHighlight(error)),
      ],
    });
  }, [editorTheme, error]);

  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;

    const editorValue = view.state.doc.toString();
    if (editorValue !== rawJson) {
      isUpdatingRef.current = true;
      view.dispatch({
        changes: { from: 0, to: editorValue.length, insert: rawJson },
        // Format/Minify/Onar gibi islemler kendi geri-al adimi olur (yazimla birlesmez).
        annotations: isolateHistory.of("full"),
      });
      isUpdatingRef.current = false;
    }
  }, [rawJson]);

  useEffect(() => {
    const view = viewRef.current;
    if (!view || !error) return;

    try {
      let pos = 0;
      if (error.position !== undefined) {
        pos = error.position;
      } else {
        const doc = view.state.doc;
        let currentLine = 1;
        let charIndex = 0;
        while (currentLine < error.line && charIndex < doc.length) {
          const lineObj = doc.line(currentLine);
          charIndex = lineObj.to + 1;
          currentLine++;
        }
        pos = Math.min(doc.length, charIndex + (error.column - 1));
      }

      view.dispatch({
        selection: { anchor: pos },
        scrollIntoView: true,
      });
    } catch {
      /* ignore */
    }
  }, [error]);

  return (
    <div className="editor-wrap flex-1 min-h-0" role="region" aria-label="JSON editörü">
      <div ref={containerRef} className="flex-1 min-h-0 h-full" />
    </div>
  );
}
