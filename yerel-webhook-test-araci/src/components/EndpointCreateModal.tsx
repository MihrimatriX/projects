import { useEffect, useState } from "react";
import { IconClose } from "./Icons";

type Props = {
  open: boolean;
  port: number;
  serverError: string | null;
  onClose: () => void;
  onCreate: () => Promise<void>;
};

export function EndpointCreateModal({ open, port, serverError, onClose, onCreate }: Props) {
  const [busy, setBusy] = useState(false);
  const preview = `http://127.0.0.1:${port}/hook/wh_<otomatik>`;

  useEffect(() => {
    if (!open) setBusy(false);
  }, [open]);

  if (!open) return null;

  async function submit() {
    setBusy(true);
    await onCreate();
    setBusy(false);
    onClose();
  }

  return (
    <div className="modal-overlay" role="dialog" aria-labelledby="create-title" aria-modal="true" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2 id="create-title">Yeni endpoint</h2>
          <button type="button" className="icon-btn" aria-label="Kapat" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="modal-body">
          <div className="localhost-badge">localhost-only · 127.0.0.1</div>
          {serverError && <div className="alert-error">{serverError}</div>}

          <div className="field">
            <label>Aktif port</label>
            <div className="preview-url">:{port}</div>
            <p className="field-hint">Endpoint&apos;ler paylaşımlı sunucu portunu kullanır. Ayarlardan varsayılan portu değiştirin.</p>
          </div>

          <div className="field">
            <label>Önizleme URL</label>
            <div className="preview-url">{preview}</div>
          </div>

          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              İptal
            </button>
            <button type="button" className="btn btn-primary" style={{ flex: 1 }} disabled={busy} onClick={() => void submit()}>
              Endpoint oluştur
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
