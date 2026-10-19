import type { DiffStats, MergeDirection } from "../types";
import { IconFolder, IconSidebar, IconSwap } from "./icons";

type Props = {
  left: string;
  right: string;
  onLeftChange: (v: string) => void;
  onRightChange: (v: string) => void;
  onPickLeft: () => void;
  onPickRight: () => void;
  onSwap: () => void;
  onCompare: () => void;
  onMerge: (direction: MergeDirection) => void;
  onExportPatch: () => void;
  onGitImport: () => void;
  onToggleSidebar: () => void;
  sidebarOpen: boolean;
  showSidebarToggle: boolean;
  loading: boolean;
  stats: DiffStats | null;
  mergeDirections: MergeDirection[];
  canPatch: boolean;
};

export function Toolbar({
  left,
  right,
  onLeftChange,
  onRightChange,
  onPickLeft,
  onPickRight,
  onSwap,
  onCompare,
  onMerge,
  onExportPatch,
  onGitImport,
  onToggleSidebar,
  sidebarOpen,
  showSidebarToggle,
  loading,
  stats,
  mergeDirections,
  canPatch,
}: Props) {
  return (
    <header className="toolbar">
      {showSidebarToggle && (
        <button
          type="button"
          className="sidebar-toggle"
          onClick={onToggleSidebar}
          aria-label="Klasör ağacını aç/kapat"
          aria-expanded={sidebarOpen}
        >
          <IconSidebar />
        </button>
      )}
      <div className="path-wrap">
        <input
          className="path-input"
          value={left}
          onChange={(e) => onLeftChange(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && onCompare()}
          aria-label="Sol dosya yolu"
          placeholder="Sol dosya veya klasör (yapıştırın veya seçin)"
          spellCheck={false}
        />
        <button type="button" className="btn-icon" onClick={onPickLeft} aria-label="Sol yolu seç" title="Gözat…">
          <IconFolder />
        </button>
      </div>
      <button type="button" className="btn-icon" onClick={onSwap} aria-label="Yolları değiştir" title="Yolları değiştir">
        <IconSwap />
      </button>
      <div className="path-wrap">
        <input
          className="path-input"
          value={right}
          onChange={(e) => onRightChange(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && onCompare()}
          aria-label="Sağ dosya yolu"
          placeholder="Sağ dosya veya klasör (yapıştırın veya seçin)"
          spellCheck={false}
        />
        <button type="button" className="btn-icon" onClick={onPickRight} aria-label="Sağ yolu seç" title="Gözat…">
          <IconFolder />
        </button>
      </div>
      {stats && (
        <div className="summary" aria-live="polite">
          <span className="add">+{stats.additions}</span>{" "}
          <span className="del">−{stats.deletions}</span>
        </div>
      )}
      {mergeDirections.includes("left-to-right") && (
        <button
          type="button"
          className="btn btn-ghost"
          onClick={() => onMerge("left-to-right")}
          title="Sol dosyayı sağa kopyala (hedef varsa .bak yedeği alınır)"
        >
          Birleştir →
        </button>
      )}
      {mergeDirections.includes("right-to-left") && (
        <button
          type="button"
          className="btn btn-ghost"
          onClick={() => onMerge("right-to-left")}
          title="Sağ dosyayı sola kopyala (hedef varsa .bak yedeği alınır)"
        >
          ← Birleştir
        </button>
      )}
      <button type="button" className="btn btn-ghost" onClick={onGitImport}>
        Git&apos;ten Yükle
      </button>
      <button type="button" className="btn" onClick={onExportPatch} disabled={!canPatch}>
        Patch Dışa Aktar
      </button>
      <button type="button" className="btn btn-primary" onClick={onCompare} disabled={loading}>
        {loading ? "Karşılaştırılıyor…" : "Karşılaştır"}
      </button>
    </header>
  );
}
