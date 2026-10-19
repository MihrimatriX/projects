import { Modal } from "./Modal";

type Props = {
  open: boolean;
  onClose: () => void;
};

export function HelpModal({ open, onClose }: Props) {
  if (!open) return null;

  return (
    <Modal title="Klavye Kısayolları" onClose={onClose}>
        <ul className="help-list">
          <li><span className="key"><kbd>j</kbd> / <kbd>k</kbd></span> Sonraki / önceki mail</li>
          <li><span className="key"><kbd>Enter</kbd></span> Mail aç</li>
          <li><span className="key"><kbd>c</kbd></span> Yeni mail</li>
          <li><span className="key"><kbd>r</kbd></span> Yanıtla</li>
          <li><span className="key"><kbd>f</kbd></span> İlet</li>
          <li><span className="key"><kbd>e</kbd></span> Arşivle</li>
          <li><span className="key"><kbd>u</kbd></span> Okunmadı işaretle</li>
          <li><span className="key"><kbd>#</kbd></span> Sil</li>
          <li><span className="key"><kbd>s</kbd></span> Yıldızla</li>
          <li><span className="key"><kbd>/</kbd></span> Arama odak</li>
          <li><span className="key"><kbd>Ctrl</kbd>+<kbd>Z</kbd></span> Son silme / arşivleme / ertelemeyi geri al</li>
          <li><span className="key"><kbd>Esc</kbd></span> Pencereyi kapat (yeni mail taslağa kaydedilir)</li>
          <li><span className="key"><kbd>F1</kbd></span> Bu yardım</li>
        </ul>
        <p className="hint">
          Gmail için IMAP ve uygulama şifresi gerekir. Yanıt takibi tamamen yerel çalışır; gizli pixel kullanılmaz.
        </p>
        <div className="modal-actions">
          <button type="button" className="btn-primary" onClick={onClose}>
            Tamam
          </button>
        </div>
    </Modal>
  );
}
