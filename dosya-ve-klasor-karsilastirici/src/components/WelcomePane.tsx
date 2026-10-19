import type { DragEvent } from "react";
import type { RecentPair } from "../types";

type Props = {
  dragOver: boolean;
  recentPairs: RecentPair[];
  onDragOver: (e: DragEvent) => void;
  onDragLeave: () => void;
  onDrop: (e: DragEvent) => void;
  onSelectRecent: (left: string, right: string) => void;
};

export function WelcomePane({
  dragOver,
  recentPairs,
  onDragOver,
  onDragLeave,
  onDrop,
  onSelectRecent,
}: Props) {
  return (
    <div className="welcome">
      <h2>Dosya ve Klasör Karşılaştırıcı</h2>
      <p className="hint">
        İki dosyayı veya klasörü seçin. Klasör taramasında <code>.gitignore</code> ve hash önbelleği
        kullanılır. Birleştirmede otomatik <code>.bak</code> yedeği.
      </p>
      <div
        className={`drop-zone${dragOver ? " drag-over" : ""}`}
        onDragOver={onDragOver}
        onDragLeave={onDragLeave}
        onDrop={onDrop}
      >
        Sol ve sağ yolları buraya sürükleyip bırakın
        <br />
        <span className="drop-hint">veya üstteki araç çubuğundan seçin · F5 karşılaştır</span>
      </div>
      {recentPairs.length > 0 && (
        <div className="recent-block">
          <h3>Son karşılaştırmalar</h3>
          <ul className="recent-list">
            {recentPairs.map((p) => (
              <li key={`${p.left}|${p.right}`}>
                <button
                  type="button"
                  className="recent-btn"
                  onClick={() => onSelectRecent(p.left, p.right)}
                  title={`${p.left}\n↔\n${p.right}`}
                >
                  <span className="recent-path">{shortPath(p.left)}</span>
                  <span className="recent-arrow">↔</span>
                  <span className="recent-path">{shortPath(p.right)}</span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function shortPath(p: string): string {
  if (p.length <= 48) return p;
  return "…" + p.slice(-45);
}
