"use client";

import { useEffect, useRef } from "react";
import { EditorState } from "@codemirror/state";
import { EditorView, keymap, placeholder } from "@codemirror/view";
import { defaultKeymap, history, historyKeymap, isolateHistory } from "@codemirror/commands";

interface RegexEditorProps {
  value: string;
  onChange: (value: string) => void;
  placeholderText?: string;
}

export default function RegexEditor({ value, onChange, placeholderText }: RegexEditorProps) {
  const hostRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const onChangeRef = useRef(onChange);
  const valueRef = useRef(value);

  onChangeRef.current = onChange;
  valueRef.current = value;

  useEffect(() => {
    if (!hostRef.current) return;

    let cancelled = false;

    import("@/lib/codemirror/regex-highlight").then(({ regexHighlightExtension }) => {
      if (cancelled || !hostRef.current) return;

      const view = new EditorView({
        state: EditorState.create({
          // Editör dinamik import sonrası oluşur; bu arada değişen (ör. ?preset=) değeri kaçırmamak için ref
          doc: valueRef.current,
          extensions: [
            history(),
            keymap.of([...defaultKeymap, ...historyKeymap]),
            placeholder(placeholderText || "Regex kalıbını yazın..."),
            regexHighlightExtension(),
            EditorView.lineWrapping,
            EditorView.contentAttributes.of({ "aria-label": "Regex pattern" }),
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
    });

    return () => {
      cancelled = true;
      viewRef.current?.destroy();
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

  return (
    <div
      ref={hostRef}
      className="flex-1 min-w-0 overflow-hidden"
      aria-label="Regex pattern editörü"
    />
  );
}
