"use client";

import { useEffect, useRef } from "react";
import { Compartment, EditorState } from "@codemirror/state";
import { EditorView, keymap, placeholder } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, isolateHistory } from "@codemirror/commands";
import type { RegexMatch } from "@/lib/regex/types";
import {
  scrollToMatch,
  testTextHighlightExtension,
} from "@/lib/codemirror/test-text-highlight";

interface TestTextEditorProps {
  value: string;
  onChange: (value: string) => void;
  matches: RegexMatch[];
  isValid: boolean;
  selectedMatchIndex: number | null;
}

export default function TestTextEditor({
  value,
  onChange,
  matches,
  isValid,
  selectedMatchIndex,
}: TestTextEditorProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const onChangeRef = useRef(onChange);
  const highlightCompartment = useRef(new Compartment());

  onChangeRef.current = onChange;

  useEffect(() => {
    if (!hostRef.current) return;

    const view = new EditorView({
      state: EditorState.create({
        doc: value,
        extensions: [
          history(),
          keymap.of([...defaultKeymap, ...historyKeymap]),
          placeholder("Test etmek istediğiniz metni buraya yazın..."),
          highlightCompartment.current.of(
            testTextHighlightExtension({
              matches: isValid ? matches : [],
              selectedIndex: selectedMatchIndex,
            })
          ),
          EditorView.lineWrapping,
          EditorView.contentAttributes.of({ "aria-label": "Test metni" }),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) {
              onChangeRef.current(update.state.doc.toString());
            }
          }),
        ],
      }),
      parent: hostRef.current,
    });

    viewRef.current = view;

    return () => {
      view.destroy();
      viewRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;

    const current = view.state.doc.toString();
    if (current !== value) {
      view.dispatch({
        changes: { from: 0, to: current.length, insert: value },
        // Sablon/gecmis yuklemesi kendi geri-al adimi olur (yazimla birlesmez).
        annotations: isolateHistory.of("full"),
      });
    }
  }, [value]);

  useEffect(() => {
    const view = viewRef.current;
    if (!view) return;

    view.dispatch({
      effects: highlightCompartment.current.reconfigure(
        testTextHighlightExtension({
          matches: isValid ? matches : [],
          selectedIndex: selectedMatchIndex,
        })
      ),
    });
  }, [matches, isValid, selectedMatchIndex]);

  useEffect(() => {
    const view = viewRef.current;
    if (!view || selectedMatchIndex == null || selectedMatchIndex < 0) return;
    const match = matches[selectedMatchIndex];
    if (match) scrollToMatch(view, match);
  }, [selectedMatchIndex, matches]);

  return (
    <div
      ref={hostRef}
      className="absolute inset-0 z-10"
      aria-label="Regex test metni editörü"
    />
  );
}
