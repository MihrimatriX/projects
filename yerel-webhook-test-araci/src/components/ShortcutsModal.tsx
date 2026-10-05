import { IconClose } from "./Icons";

type Props = { open: boolean; onClose: () => void };

const SHORTCUTS = [
  ["İstek listesi gezin", "↑ ↓"],
  ["Replay", "r"],
  ["curl kopyala", "c"],
  ["Filtre odak", "f veya /"],
  ["Yeni endpoint", "Ctrl+n"],
  ["Aktif URL kopyala", "Ctrl+l"],
  ["Bu yardım", "?"],
  ["Kapat", "Esc"],
] as const;

export function ShortcutsModal({ open, onClose }: Props) {
  if (!open) return null;

  return (
    <div className="modal-overlay" role="dialog" aria-labelledby="shortcuts-title" aria-modal="true" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2 id="shortcuts-title">Klavye kısayolları</h2>
          <button type="button" className="icon-btn" aria-label="Kapat" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="modal-body">
          {SHORTCUTS.map(([label, key]) => (
            <div key={label} className="shortcut-row">
              <span>{label}</span>
              <kbd>{key}</kbd>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
