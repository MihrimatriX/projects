import { DiffEditor } from "@monaco-editor/react";
import type { editor } from "monaco-editor";
import { useEffect, useRef } from "react";
import type { FilePairContent } from "../types";
import { HexPane } from "./HexPane";

type Props = {
  content: FilePairContent | null;
  loading: boolean;
  viewMode: "side-by-side" | "inline" | "hex";
  paneTitle?: string;
  theme?: "dark" | "light";
};

function LoadingShimmer() {
  return (
    <div className="loading-shimmer show" aria-hidden>
      {[90, 75, 82, 68, 88].map((w) => (
        <div key={w} className="shimmer-line" style={{ width: `${w}%` }} />
      ))}
    </div>
  );
}

export function DiffPane({ content, loading, viewMode, paneTitle, theme = "dark" }: Props) {
  const editorRef = useRef<editor.IStandaloneDiffEditor | null>(null);

  // Alt+Aşağı / Alt+Yukarı: sonraki / önceki farka git (Meld/WinMerge alışkanlığı).
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (!e.altKey || (e.key !== "ArrowDown" && e.key !== "ArrowUp")) return;
      if (!editorRef.current) return;
      e.preventDefault();
      editorRef.current.goToDiff(e.key === "ArrowDown" ? "next" : "previous");
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  // Editör çizilmeyecekse eski (dispose edilmiş) örneğe gitme komutu gönderilmesin.
  if (loading || !content || viewMode === "hex" || content.binary || content.missingSide) {
    editorRef.current = null;
  }

  if (loading) {
    return <LoadingShimmer />;
  }

  if (!content) {
    return null;
  }

  if (viewMode === "hex" || content.binary) {
    return (
      <HexPane
        leftHex={content.leftHex ?? ""}
        rightHex={content.rightHex ?? ""}
        leftSize={content.leftSize}
        rightSize={content.rightSize}
        truncated={content.truncated}
        leftLabel={content.leftPath}
        rightLabel={content.rightPath}
      />
    );
  }

  if (content.missingSide) {
    return (
      <div className="binary-msg">
        {content.missingSide === "left"
          ? "Dosya yalnızca sağ tarafta mevcut."
          : "Dosya yalnızca sol tarafta mevcut."}
      </div>
    );
  }

  const title = paneTitle ?? content.leftPath;
  const go = (target: "next" | "previous") => editorRef.current?.goToDiff(target);
  const showHeaders = viewMode === "side-by-side";

  return (
    <>
      {showHeaders && (
        <div className="pane-headers">
          <div className="pane-header">Sol — {title}</div>
          <div className="pane-header">Sağ — {title}</div>
        </div>
      )}
      <div className="diff-nav">
        <button type="button" className="btn" onClick={() => go("previous")} title="Alt+Yukarı">
          ↑ Önceki fark
        </button>
        <button type="button" className="btn" onClick={() => go("next")} title="Alt+Aşağı">
          ↓ Sonraki fark
        </button>
      </div>
      <div className="diff-editor-wrap">
        <DiffEditor
          onMount={(ed) => {
            editorRef.current = ed;
          }}
          height="100%"
          language={content.language}
          original={content.left}
          modified={content.right}
          theme={theme === "light" ? "vs" : "vs-dark"}
          options={{
            readOnly: true,
            renderSideBySide: viewMode === "side-by-side",
            scrollBeyondLastLine: false,
            minimap: { enabled: false },
            fontFamily: "JetBrains Mono, Consolas, monospace",
            fontSize: 13,
            lineHeight: 20,
            automaticLayout: true,
            diffWordWrap: "on",
          }}
        />
      </div>
    </>
  );
}
