type Props = {
  open: boolean;
  onClose: () => void;
};

export function HelpDialog({ open, onClose }: Props) {
  if (!open) return null;

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="help-title"
    >
      <div className="modal">
        <h2 id="help-title">Yardım</h2>
        <table className="help-table">
          <tbody>
            <tr><td>F5 / Enter (yol kutusunda)</td><td>Karşılaştır</td></tr>
            <tr><td>Alt+↓ / Alt+↑</td><td>Sonraki / önceki fark</td></tr>
            <tr><td>Esc</td><td>Açık pencereyi kapat</td></tr>
            <tr><td>F1</td><td>Bu yardım</td></tr>
            <tr><td>Ctrl+,</td><td>Ayarlar (ignore, gitignore, önbellek)</td></tr>
            <tr><td>Git Diff</td><td>Toolbar — yapıştırılmış diff</td></tr>
            <tr><td>Base</td><td>3-yönlü birleştirme için ortak ata yolu</td></tr>
            <tr><td>Monaco</td><td>Ctrl+F arama</td></tr>
          </tbody>
        </table>
        <p className="modal-hint">
          İki dosya veya klasör seçin. Klasör modunda farklı dosyaya tıklayın. Base yolu ile 3-yönlü
          birleştirme açılır. Patch dışa aktar ve git diff içe aktar araç çubuğunda.
        </p>
        <div className="modal-actions">
          <button type="button" className="btn btn-primary" onClick={onClose} autoFocus>
            Tamam
          </button>
        </div>
      </div>
    </div>
  );
}
