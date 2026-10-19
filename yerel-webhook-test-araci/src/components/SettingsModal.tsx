import { useEffect, useState } from "react";
import { IconClose } from "./Icons";
import type { AppSettings } from "../types";

const BODY_OPTIONS = [
  { label: "256 KB", value: 256_000 },
  { label: "512 KB", value: 512_000 },
  { label: "1 MB", value: 1_024_000 },
  { label: "5 MB", value: 5_242_880 },
];

const RETENTION_OPTIONS = [500, 1000, 5000, 10000];

type Props = {
  open: boolean;
  settings: AppSettings;
  onClose: () => void;
  onSave: (s: Partial<AppSettings>) => Promise<void>;
  onExport: () => Promise<void>;
};

export function SettingsModal({ open, settings, onClose, onSave, onExport }: Props) {
  const [draft, setDraft] = useState(settings);

  useEffect(() => {
    if (open) setDraft(settings);
  }, [open, settings]);

  if (!open) return null;
  const portValid = Number.isInteger(draft.defaultPort) && draft.defaultPort >= 1024 && draft.defaultPort <= 65535;

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="settings-title" onClick={onClose}>
      <div className="modal settings-wide" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2 id="settings-title">Ayarlar</h2>
          <button type="button" className="icon-btn" aria-label="Kapat" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="modal-body">
          <div className="settings-section">
            <h3 className="settings-section-title">Sunucu</h3>
            <div className="setting-row">
              <div className="setting-info">
                <div className="setting-label">Varsayılan port</div>
                <div className="setting-desc">Yeni oturumlar için başlangıç portu</div>
              </div>
              <input
                type="number"
                className="input input-mono"
                min={1024}
                max={65535}
                aria-label="Varsayılan port"
                value={draft.defaultPort || ""}
                onChange={(e) => setDraft({ ...draft, defaultPort: Number(e.target.value) })}
              />
            </div>
            <div className="setting-row">
              <div className="setting-info">
                <div className="setting-label">Açılışta sunucuyu başlat</div>
                <div className="setting-desc">Uygulama açılınca varsayılan portta dinlemeye başlar (port doluysa sonraki port)</div>
              </div>
              <button
                type="button"
                className={`toggle ${draft.autoStart ? "on" : ""}`}
                aria-pressed={draft.autoStart}
                aria-label="Açılışta sunucuyu başlat"
                onClick={() => setDraft({ ...draft, autoStart: !draft.autoStart })}
              />
            </div>
            <div className="setting-row">
              <div className="setting-info">
                <div className="setting-label">Maksimum body boyutu</div>
                <div className="setting-desc">Bu sınırı aşan gövdeler kısaltılır</div>
              </div>
              <select
                className="select"
                aria-label="Maksimum body boyutu"
                value={draft.maxBodyBytes}
                onChange={(e) => setDraft({ ...draft, maxBodyBytes: Number(e.target.value) })}
              >
                {BODY_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="setting-row">
              <div className="setting-info">
                <div className="setting-label">localhost-only</div>
                <div className="setting-desc">Yalnızca 127.0.0.1 üzerinden dinle (sabit)</div>
              </div>
              <button type="button" className="toggle on" aria-pressed="true" aria-label="localhost-only" disabled title="Her zaman açık" />
            </div>
          </div>

          <div className="settings-section">
            <h3 className="settings-section-title">Güvenlik</h3>
            <div className="setting-row">
              <div className="setting-info">
                <div className="setting-label">Secret maskeleme</div>
                <div className="setting-desc">Authorization ve imza header&apos;larını gizle</div>
              </div>
              <button
                type="button"
                className={`toggle ${draft.maskSecrets ? "on" : ""}`}
                aria-pressed={draft.maskSecrets}
                aria-label="Secret maskeleme"
                onClick={() => setDraft({ ...draft, maskSecrets: !draft.maskSecrets })}
              />
            </div>
          </div>

          <div className="settings-section">
            <h3 className="settings-section-title">Retention</h3>
            <div className="setting-row">
              <div className="setting-info">
                <div className="setting-label">Global retention limit</div>
                <div className="setting-desc">Tüm endpoint&apos;ler için toplam istek sınırı</div>
              </div>
              <select
                className="select"
                aria-label="Global retention limit"
                value={draft.maxRequests}
                onChange={(e) => setDraft({ ...draft, maxRequests: Number(e.target.value) })}
              >
                {RETENTION_OPTIONS.map((n) => (
                  <option key={n} value={n}>
                    {n.toLocaleString("tr-TR")}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {!portValid && <p className="error-text">Port 1024-65535 arasında bir tam sayı olmalı.</p>}
          <div className="modal-actions">
            <button type="button" className="btn-outline" onClick={() => void onExport()}>
              Günlüğü dışa aktar
            </button>
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              İptal
            </button>
            <button
              type="button"
              className="btn btn-primary"
              style={{ flex: "none" }}
              disabled={!portValid}
              onClick={async () => {
                await onSave(draft);
                onClose();
              }}
            >
              Kaydet
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
