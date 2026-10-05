import { IconSettings } from "./icons";

type Props = {
  syncing: boolean;
  onSync: () => void;
  onSettings: () => void;
};

export function TitleBar({ syncing, onSync, onSettings }: Props) {
  return (
    <header className="titlebar">
      <span className="titlebar-title">E-posta İstemcisi</span>
      <div className="titlebar-actions">
        <button
          type="button"
          className="sync-indicator"
          onClick={onSync}
          title="IMAP senkronize et"
          aria-live="polite"
        >
          <span className={`sync-dot${syncing ? " syncing" : ""}`} aria-hidden />
          <span>{syncing ? "Senkronize ediliyor…" : "Senkronize"}</span>
        </button>
        <button type="button" className="titlebar-btn" onClick={onSettings} title="Ayarlar" aria-label="Ayarlar">
          <IconSettings />
        </button>
      </div>
    </header>
  );
}
