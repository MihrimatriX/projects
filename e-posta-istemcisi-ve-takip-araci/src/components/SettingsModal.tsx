import { useEffect, useState } from "react";
import type { Account, AppSettings, ProviderPreset } from "../types";
import { Modal } from "./Modal";

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved: (message: string) => void;
  onTemplates?: () => void;
  onHelp?: () => void;
  onAbout?: () => void;
  onMarkAllRead?: () => void;
  onEmptyTrash?: () => void;
};

const EMPTY_ACCOUNT = (): Account => ({
  id: "",
  server: "",
  email: "",
  displayName: "",
  password: "",
  smtpServer: "",
  provider: "custom",
});

export function SettingsModal({
  open,
  onClose,
  onSaved,
  onTemplates,
  onHelp,
  onAbout,
  onMarkAllRead,
  onEmptyTrash,
}: Props) {
  const [accounts, setAccounts] = useState<Account[]>([EMPTY_ACCOUNT()]);
  const [activeId, setActiveId] = useState("");
  const [settings, setSettings] = useState<AppSettings>({
    cacheDays: 30,
    syncIntervalMinutes: 15,
    backgroundSync: true,
    notifyNewMail: true,
    notifyTrackingDue: true,
    useIdle: true,
    minimizeToTray: true,
    onboardingDone: false,
    theme: "system",
  });
  const [testMsg, setTestMsg] = useState("");
  const [confirmEmpty, setConfirmEmpty] = useState(false);

  useEffect(() => {
    if (!open) return;
    setTestMsg("");
    setConfirmEmpty(false);
    Promise.all([
      window.electronAPI.listAccounts(),
      window.electronAPI.getSettings(),
      window.electronAPI.getActiveAccountId(),
    ]).then(([accs, s, active]) => {
      setAccounts(accs.length ? accs : [EMPTY_ACCOUNT()]);
      // Önceden her açılışta ilk hesap seçiliyordu; kaydedince varsayılan hesap sıfırlanıyordu.
      setActiveId(active ?? accs[0]?.id ?? "");
      setSettings(s);
    });
  }, [open]);

  if (!open) return null;

  async function applyPreset(index: number, provider: ProviderPreset) {
    const preset = await window.electronAPI.getProviderPreset(provider);
    setAccounts((prev) =>
      prev.map((a, i) => (i === index ? { ...a, ...preset, provider } : a))
    );
  }

  async function addAccount() {
    const id = await window.electronAPI.createAccountId();
    setAccounts((prev) => [...prev, { ...EMPTY_ACCOUNT(), id }]);
  }

  function updateAccount(index: number, patch: Partial<Account>) {
    setAccounts((prev) => prev.map((a, i) => (i === index ? { ...a, ...patch } : a)));
  }

  function removeAccount(index: number) {
    setAccounts((prev) => prev.filter((_, i) => i !== index));
  }

  function errorText(e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return msg.replace(/^Error invoking remote method '[^']+': (Error: )?/, "");
  }

  async function save() {
    // Boş bırakılan hesap kartı kaydedilmez (önceden e-postasız "hayalet" hesap oluşuyordu).
    const normalized = accounts.filter((a) => a.email.trim()).map((a) => ({
      ...a,
      id: a.id || `acc-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    }));
    try {
      await window.electronAPI.saveAccounts(normalized, activeId || normalized[0]?.id);
      await window.electronAPI.saveSettings(settings);
    } catch (e) {
      setTestMsg(`Kaydedilemedi: ${errorText(e)}`);
      return;
    }
    onSaved("Ayarlar kaydedildi");
    onClose();
  }

  async function exportData() {
    try {
      const ok = await window.electronAPI.exportData();
      if (ok) setTestMsg("Yedek dışa aktarıldı");
    } catch (e) {
      setTestMsg(`Dışa aktarılamadı: ${errorText(e)}`);
    }
  }

  async function importData() {
    try {
      const count = await window.electronAPI.importData();
      if (count > 0) {
        setTestMsg(`${count} mesaj içe aktarıldı (mevcut verilerle birleştirildi)`);
        onSaved(`${count} mesaj içe aktarıldı`);
      }
    } catch (e) {
      setTestMsg(`İçe aktarılamadı: ${errorText(e)}`);
    }
  }

  return (
    <Modal title="Ayarlar" onClose={onClose} wide closeOnBackdrop={false}>

        <h3 className="section-title">Hesaplar</h3>
        {accounts.map((account, index) => (
          <div key={account.id || index} className="account-card">
            <div className="account-card-header">
              <strong>Hesap {index + 1}</strong>
              <select
                aria-label={`Hesap ${index + 1} sağlayıcı`}
                value={account.provider ?? "custom"}
                onChange={(e) => applyPreset(index, e.target.value as ProviderPreset)}
              >
                <option value="custom">Özel</option>
                <option value="gmail">Gmail</option>
                <option value="outlook">Outlook</option>
              </select>
              {accounts.length > 1 && (
                <button type="button" className="btn-sm danger" aria-label={`Hesap ${index + 1} kaldır`} onClick={() => removeAccount(index)}>
                  Kaldır
                </button>
              )}
            </div>
            <label>Görünen ad</label>
            <input aria-label="Görünen ad" value={account.displayName} onChange={(e) => updateAccount(index, { displayName: e.target.value })} />
            <label>E-posta</label>
            <input aria-label="E-posta" value={account.email} onChange={(e) => updateAccount(index, { email: e.target.value })} />
            <label>IMAP sunucu ve port</label>
            <div className="attachment-row">
              <input aria-label="IMAP sunucu" value={account.server} onChange={(e) => updateAccount(index, { server: e.target.value })} />
              <input
                aria-label="IMAP port"
                type="number"
                min={1}
                max={65535}
                style={{ width: 90 }}
                value={account.imapPort ?? 993}
                onChange={(e) => updateAccount(index, { imapPort: Number(e.target.value) || undefined })}
              />
            </div>
            <label>SMTP sunucu ve port</label>
            <div className="attachment-row">
              <input aria-label="SMTP sunucu" value={account.smtpServer ?? ""} onChange={(e) => updateAccount(index, { smtpServer: e.target.value })} />
              <input
                aria-label="SMTP port"
                type="number"
                min={1}
                max={65535}
                style={{ width: 90 }}
                value={account.smtpPort ?? 587}
                onChange={(e) => updateAccount(index, { smtpPort: Number(e.target.value) || undefined })}
              />
            </div>
            <label>Şifre / uygulama şifresi</label>
            <input
              aria-label="Şifre"
              type="password"
              value={account.password ?? ""}
              placeholder={account.hasPassword ? "Kayıtlı — değiştirmek için yazın" : ""}
              onChange={(e) => updateAccount(index, { password: e.target.value, authMode: "password" })}
            />
            <label>Google OAuth Client ID (Gmail)</label>
            <input
              aria-label="Google OAuth Client ID"
              value={account.googleClientId ?? ""}
              onChange={(e) => updateAccount(index, { googleClientId: e.target.value })}
              placeholder="xxxx.apps.googleusercontent.com"
            />
            <div className="attachment-row">
              <button
                type="button"
                className="btn-sm"
                onClick={async () => {
                  const id = account.id || `acc-${index}`;
                  if (!account.id) updateAccount(index, { id });
                  try {
                    await window.electronAPI.connectGoogleOAuth(id, account.googleClientId ?? "", account.email);
                    setTestMsg("Google OAuth bağlandı");
                  } catch (e) {
                    setTestMsg(`Google OAuth: ${errorText(e)}`);
                  }
                }}
              >
                Google ile bağlan
              </button>
              <button
                type="button"
                className="btn-sm"
                onClick={async () => {
                  setTestMsg("Bağlantı test ediliyor…");
                  try {
                    const res = await window.electronAPI.testConnection(account);
                    setTestMsg(res.message);
                  } catch (e) {
                    setTestMsg(errorText(e));
                  }
                }}
              >
                Bağlantıyı test et
              </button>
            </div>
            <label className="checkbox-inline">
              <input
                type="radio"
                name="activeAccount"
                checked={(activeId || accounts[0]?.id) === account.id}
                onChange={() => setActiveId(account.id)}
              />
              Gönderimde varsayılan hesap
            </label>
          </div>
        ))}
        <button type="button" className="btn-sm" onClick={addAccount}>
          + Hesap ekle (birleşik gelen kutusu)
        </button>

        <h3 className="section-title">Araçlar</h3>
        <div className="attachment-row">
          {onMarkAllRead && (
            <button type="button" className="btn-sm" onClick={onMarkAllRead}>
              Tümünü okundu işaretle
            </button>
          )}
          {onEmptyTrash && (
            // Kalıcı silme: ilk tık onay ister, ikinci tık boşaltır.
            <button
              type="button"
              className="btn-sm danger"
              onClick={() => {
                if (!confirmEmpty) return setConfirmEmpty(true);
                setConfirmEmpty(false);
                onEmptyTrash();
              }}
              onBlur={() => setConfirmEmpty(false)}
            >
              {confirmEmpty ? "Emin misiniz? Kalıcı sil" : "Çöpü boşalt"}
            </button>
          )}
          {onTemplates && (
            <button type="button" className="btn-sm" onClick={onTemplates}>
              Şablonlar
            </button>
          )}
          {onHelp && (
            <button type="button" className="btn-sm" onClick={onHelp}>
              Yardım (F1)
            </button>
          )}
          {onAbout && (
            <button type="button" className="btn-sm" onClick={onAbout}>
              Hakkında
            </button>
          )}
        </div>

        <h3 className="section-title">Görünüm</h3>
        <label htmlFor="set-theme">Tema</label>
        <select
          id="set-theme"
          value={settings.theme}
          onChange={(e) => setSettings({ ...settings, theme: e.target.value as AppSettings["theme"] })}
        >
          <option value="system">Sistem</option>
          <option value="light">Açık</option>
          <option value="dark">Koyu</option>
        </select>

        <h3 className="section-title">Senkron ve önbellek</h3>
        <label htmlFor="set-cache">Önbellek süresi (gün)</label>
        <input
          id="set-cache"
          type="number"
          min={7}
          max={365}
          value={settings.cacheDays}
          onChange={(e) => setSettings({ ...settings, cacheDays: Number(e.target.value) })}
        />
        <label htmlFor="set-interval">Arka plan senkron aralığı (dakika)</label>
        <input
          id="set-interval"
          type="number"
          min={0}
          max={1440}
          value={settings.syncIntervalMinutes}
          onChange={(e) => setSettings({ ...settings, syncIntervalMinutes: Number(e.target.value) })}
        />
        <label className="checkbox-inline">
          <input
            type="checkbox"
            checked={settings.backgroundSync}
            onChange={(e) => setSettings({ ...settings, backgroundSync: e.target.checked })}
          />
          Arka plan IMAP senkronu
        </label>
        <label className="checkbox-inline">
          <input
            type="checkbox"
            checked={settings.notifyNewMail}
            onChange={(e) => setSettings({ ...settings, notifyNewMail: e.target.checked })}
          />
          Yeni mail bildirimi
        </label>
        <label className="checkbox-inline">
          <input
            type="checkbox"
            checked={settings.notifyTrackingDue}
            onChange={(e) => setSettings({ ...settings, notifyTrackingDue: e.target.checked })}
          />
          Takip süresi dolunca bildir
        </label>
        <label className="checkbox-inline">
          <input
            type="checkbox"
            checked={settings.useIdle}
            onChange={(e) => setSettings({ ...settings, useIdle: e.target.checked })}
          />
          IMAP IDLE (pencere açıkken anlık güncelleme)
        </label>
        <label className="checkbox-inline">
          <input
            type="checkbox"
            checked={settings.minimizeToTray}
            onChange={(e) => setSettings({ ...settings, minimizeToTray: e.target.checked })}
          />
          Kapatınca tepsiye küçült
        </label>

        {testMsg && <p className="hint" role="status">{testMsg}</p>}

        <h3 className="section-title">Yedekleme</h3>
        <div className="modal-actions" style={{ justifyContent: "flex-start" }}>
          <button type="button" className="btn-sm" onClick={exportData}>
            Dışa aktar (JSON)
          </button>
          <button type="button" className="btn-sm" onClick={importData}>
            İçe aktar
          </button>
        </div>

        <p className="hint">Şifreler OS güvenli depolamasında tutulur; düz metin dosyaya yazılmaz.</p>

        <div className="modal-actions">
          <button type="button" className="btn-ghost" onClick={onClose}>
            Kapat
          </button>
          <button type="button" className="btn-primary" onClick={save}>
            Kaydet
          </button>
        </div>
    </Modal>
  );
}
