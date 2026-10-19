import { useState } from "react";
import { IconCopy, IconMock, IconSettings } from "./Icons";
import type { WebhookEndpoint } from "../types";

type Props = {
  endpoints: WebhookEndpoint[];
  activeId: string | null;
  port: number;
  isRunning: boolean;
  portInput: string;
  serverError: string | null;
  drawerOpen: boolean;
  onPortChange: (v: string) => void;
  onToggleServer: () => void;
  onSelect: (id: string) => void;
  onCreate: () => void;
  onDelete: (id: string) => void;
  onCopyUrl: (url: string) => void;
  onOpenSettings: () => void;
  onOpenMockRules: () => void;
  requestCounts: Record<string, number>;
};

export function EndpointSidebar({
  endpoints,
  activeId,
  port,
  isRunning,
  portInput,
  serverError,
  drawerOpen,
  onPortChange,
  onToggleServer,
  onSelect,
  onCreate,
  onDelete,
  onCopyUrl,
  onOpenSettings,
  onOpenMockRules,
  requestCounts,
}: Props) {
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);

  async function handleCopy(id: string, url: string) {
    await onCopyUrl(url);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 1500);
  }

  return (
    <aside className={`sidebar ${drawerOpen ? "open" : ""}`} aria-label="Endpoint listesi">
      <div className="panel-header">
        <h2>Endpoint&apos;ler</h2>
        <div className="panel-header-actions">
          <button
            type="button"
            className="icon-btn"
            aria-label="Mock kuralları"
            title="Mock kuralları"
            disabled={!activeId}
            onClick={onOpenMockRules}
          >
            <IconMock />
          </button>
          <button type="button" className="icon-btn" aria-label="Ayarlar" title="Ayarlar" onClick={onOpenSettings}>
            <IconSettings />
          </button>
        </div>
      </div>

      <div className="server-strip">
        <div className="server-row">
          <input
            id="port-input"
            type="number"
            className="input input-mono"
            value={portInput}
            disabled={isRunning}
            min={1024}
            max={65535}
            aria-label="Port"
            onChange={(e) => onPortChange(e.target.value)}
          />
        </div>
        {serverError && <p className="error-text">{serverError}</p>}
        <button
          type="button"
          className={`btn-server ${isRunning ? "stop" : "start"}`}
          onClick={onToggleServer}
        >
          {isRunning ? "Durdur" : "Sunucuyu başlat"}
        </button>
      </div>

      <ul className="endpoint-list">
        {endpoints.map((ep) => {
          const url = `http://127.0.0.1:${port}/hook/${ep.slug}`;
          const active = ep.id === activeId;
          const count = requestCounts[ep.id] ?? 0;
          return (
            <li key={ep.id} style={{ position: "relative" }}>
              <button
                type="button"
                className={`endpoint-card ${active ? "active" : ""}`}
                onClick={() => onSelect(ep.id)}
              >
                <div className="endpoint-top">
                  {isRunning && active && <span className="live-dot" aria-label="Canlı dinleme" />}
                  <span className="hook-id">{ep.slug}</span>
                </div>
                <div className="endpoint-meta">
                  <span>
                    {count} istek · :{port}
                  </span>
                </div>
              </button>
              {/* Kopyala düğmesi kartın dışında: önceden düğme içinde düğme (role=button span) vardı. */}
              <button
                type="button"
                className={`icon-btn copy-btn ${copiedId === ep.id ? "copied" : ""}`}
                aria-label={`${ep.slug} URL kopyala`}
                title="URL kopyala"
                onClick={() => void handleCopy(ep.id, url)}
              >
                <IconCopy />
              </button>
              {endpoints.length > 1 && (
                // Endpoint ve tüm istekleri silinir: ikinci tık onaylar.
                <button
                  type="button"
                  className={`icon-btn endpoint-delete ${confirmDeleteId === ep.id ? "confirm" : ""}`}
                  aria-label={confirmDeleteId === ep.id ? `${ep.slug} silinsin mi? Onayla` : `${ep.slug} endpoint sil`}
                  title={confirmDeleteId === ep.id ? "Tekrar tıklayın: endpoint ve istekleri silinir" : "Sil"}
                  onClick={() => {
                    if (confirmDeleteId !== ep.id) return setConfirmDeleteId(ep.id);
                    setConfirmDeleteId(null);
                    onDelete(ep.id);
                  }}
                  onBlur={() => setConfirmDeleteId(null)}
                >
                  {confirmDeleteId === ep.id ? "Sil?" : "×"}
                </button>
              )}
            </li>
          );
        })}
      </ul>

      <div className="sidebar-footer">
        <button type="button" className="btn-new" onClick={onCreate}>
          + Endpoint oluştur
        </button>
      </div>
    </aside>
  );
}
