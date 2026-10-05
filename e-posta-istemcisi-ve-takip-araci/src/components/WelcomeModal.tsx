import { Modal } from "./Modal";

type Props = {
  open: boolean;
  onClose: () => void;
  onOpenSettings: () => void;
};

export function WelcomeModal({ open, onClose, onOpenSettings }: Props) {
  if (!open) return null;

  async function finish() {
    await window.electronAPI.saveSettings({ onboardingDone: true });
    onClose();
  }

  return (
    <Modal title="E-posta istemcisine hoş geldiniz" onClose={finish} wide closeOnBackdrop={false}>
        <p className="hint">
          Posta yerel SQLite önbelleğinde tutulur; IMAP IDLE, Gmail OAuth, yanıt takibi ve erteleme cihazda çalışır.
        </p>
        <ol className="help-list">
          <li>Ayarlar → Gmail veya Outlook profili seçin</li>
          <li>Uygulama şifresi girin veya Google OAuth Client ID ile bağlanın</li>
          <li>«Bağlantıyı test et» ile doğrulayın</li>
          <li>IMAP senkronize et ile posta kutunuzu çekin</li>
        </ol>
        <div className="modal-actions">
          <button
            type="button"
            className="btn-sm"
            onClick={async () => {
              await window.electronAPI.saveSettings({ onboardingDone: true });
              onOpenSettings();
            }}
          >
            Hesap ayarları
          </button>
          <button type="button" className="compose-btn" onClick={finish}>
            Başla
          </button>
        </div>
    </Modal>
  );
}
