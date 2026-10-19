import { useState } from "react";

type Props = {
  open: boolean;
  onClose: () => void;
  onImport: (text: string) => void;
};

export function GitDiffDialog({ open, onClose, onImport }: Props) {
  const [text, setText] = useState("");

  if (!open) return null;

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="git-diff-title"
    >
      <div className="modal">
        <h2 id="git-diff-title">Git diff içe aktar</h2>
        <p className="modal-hint">
          <code>git diff</code> çıktısını yapıştırın. Birden fazla dosya varsa ilk dosya açılır.
        </p>
        <textarea
          className="modal-textarea"
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder="diff --git a/... b/..."
          spellCheck={false}
          aria-label="Git diff metni"
          autoFocus
        />
        <div className="modal-actions">
          <button type="button" className="btn" onClick={onClose}>
            İptal
          </button>
          <button
            type="button"
            className="btn btn-primary"
            disabled={!text.trim()}
            onClick={() => {
              onImport(text);
              setText("");
              onClose();
            }}
          >
            İçe Aktar
          </button>
        </div>
      </div>
    </div>
  );
}
