import { useEffect, useState } from "react";
import { Modal } from "./Modal";

type Props = {
  open: boolean;
  onClose: () => void;
};

export function AboutModal({ open, onClose }: Props) {
  const [version, setVersion] = useState("");

  useEffect(() => {
    if (open) window.electronAPI.getAppVersion().then(setVersion);
  }, [open]);

  if (!open) return null;

  return (
    <Modal title="E-posta İstemcisi" onClose={onClose}>
        <p>Sürüm {version}</p>
        <p className="hint">
          Yerel-first IMAP/SMTP istemci — takip paneli, snooze, birleşik gelen kutusu, ek dosya desteği.
        </p>
        <p className="hint">MIT Lisans · MihrimatriX</p>
        <div className="modal-actions">
          <button type="button" className="btn-sm" onClick={onClose}>
            Kapat
          </button>
        </div>
    </Modal>
  );
}
