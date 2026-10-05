"use client";

import { useEffect } from "react";

interface HelpModalProps {
  open: boolean;
  onClose: () => void;
}

const SHORTCUTS = [
  ["Ctrl+Shift+F", "Format"],
  ["Ctrl+Shift+M", "Minify"],
  ["Ctrl+Shift+K", "Anahtarları sırala"],
  ["Ctrl+O", "Dosya aç"],
  ["Ctrl+S", "Kaydet / indir"],
  ["Ctrl+Z / Ctrl+Y", "Geri al / yinele (editörde)"],
  ["F1", "Yardım"],
];

export default function HelpModal({ open, onClose }: HelpModalProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="modal-overlay open" role="presentation" onClick={onClose}>
      <div className="modal" role="dialog" aria-labelledby="help-title" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2 className="modal-title" id="help-title">
            Klavye kısayolları
          </h2>
          <button type="button" className="btn-ghost modal-close" aria-label="Kapat" onClick={onClose}>
            Esc
          </button>
        </div>
        <div className="modal-body">
          {SHORTCUTS.map(([k, v]) => (
            <div key={k} className="shortcut-row">
              <span>{v}</span>
              <kbd>{k}</kbd>
            </div>
          ))}
          <p className="help-note">
            JSONC yorumları parse öncesi soyulur. Editör içeriği otomatik saklanır ve sonraki açılışta geri
            yüklenir. <code>#d=</code> ile açılan paylaşım linkleri (lz-string) editöre yüklenir.
          </p>
        </div>
      </div>
    </div>
  );
}
