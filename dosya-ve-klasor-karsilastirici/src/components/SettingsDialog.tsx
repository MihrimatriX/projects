import { useEffect, useState } from "react";
import type { AppSettings, RecentPair } from "../types";

type Section = "general" | "diff" | "recent" | "gitignore";

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved: (settings: AppSettings) => void;
  onSelectRecent?: (left: string, right: string) => void;
};

function Toggle({
  on,
  onChange,
  label,
}: {
  on: boolean;
  onChange: (v: boolean) => void;
  label: string;
}) {
  return (
    <button
      type="button"
      className={`toggle${on ? " on" : ""}`}
      role="switch"
      aria-checked={on}
      aria-label={label}
      onClick={() => onChange(!on)}
    />
  );
}

export function SettingsDialog({ open, onClose, onSaved, onSelectRecent }: Props) {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [ignoreText, setIgnoreText] = useState("");
  const [section, setSection] = useState<Section>("general");
  const [version, setVersion] = useState("");
  const [toast, setToast] = useState("");

  useEffect(() => {
    if (!open) return;
    window.electronAPI.getSettings().then((s) => {
      setSettings(s);
      setIgnoreText(s.extraIgnoreDirs.join("\n"));
    });
    window.electronAPI.getVersion().then(setVersion);
  }, [open]);

  if (!open || !settings) return null;

  function notify(message = "Ayarlar kaydedildi") {
    setToast(message);
    setTimeout(() => setToast(""), 1800);
  }

  async function saveGitignore() {
    const extraIgnoreDirs = ignoreText
      .split("\n")
      .map((l) => l.trim())
      .filter(Boolean);
    const next = await window.electronAPI.saveSettings({ extraIgnoreDirs });
    setSettings(next);
    onSaved(next);
    notify();
  }

  // Değişen alan doğrudan gönderilir: setSettings henüz uygulanmadığından state'ten okumak eski değeri kaydederdi.
  async function save(patch: Partial<AppSettings>) {
    setSettings({ ...settings!, ...patch });
    const next = await window.electronAPI.saveSettings(patch);
    setSettings(next);
    onSaved(next);
    notify();
  }

  async function clearRecent() {
    const next = await window.electronAPI.saveSettings({ recentPairs: [] });
    setSettings(next);
    onSaved(next);
    notify();
  }

  async function clearCache() {
    await window.electronAPI.clearHashCache();
    notify("Hash önbelleği temizlendi");
  }

  const sections: { id: Section; label: string }[] = [
    { id: "general", label: "Genel" },
    { id: "diff", label: "Diff" },
    { id: "recent", label: "Son Çiftler" },
    { id: "gitignore", label: "Gitignore" },
  ];

  return (
    <div
      className="settings-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="settings-title"
    >
      <div className="settings-window">
        <header className="settings-titlebar">
          <span id="settings-title">Ayarlar</span>
          <button type="button" className="titlebar-btn" onClick={onClose} aria-label="Kapat">
            ✕
          </button>
        </header>
        <div className="settings-app">
          <nav className="settings-nav" aria-label="Ayar kategorileri">
            {sections.map((s) => (
              <button
                key={s.id}
                type="button"
                className={`nav-item${section === s.id ? " active" : ""}`}
                aria-current={section === s.id ? "page" : undefined}
                onClick={() => setSection(s.id)}
              >
                {s.label}
              </button>
            ))}
          </nav>
          <main className="settings-content">
            {section === "general" && (
              <>
                <h1 className="section-title">Genel</h1>
                <p className="section-desc">Tema, yedekleme ve başlangıç davranışı · sürüm {version}</p>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>Tema</strong>
                    <span>Arayüz ve diff editörü renkleri</span>
                  </div>
                  <select
                    className="input-field"
                    aria-label="Tema"
                    autoFocus
                    value={settings.theme}
                    onChange={(e) => save({ theme: e.target.value as AppSettings["theme"] })}
                  >
                    <option value="dark">Koyu</option>
                    <option value="light">Açık</option>
                  </select>
                </div>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>.bak yedekleme</strong>
                    <span>Merge sonrası otomatik yedek oluştur</span>
                  </div>
                  <Toggle
                    on={settings.createBackupOnMerge}
                    label=".bak yedekleme"
                    onChange={(v) => save({ createBackupOnMerge: v })}
                  />
                </div>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>Hash önbellek</strong>
                    <span>mtime+size değişmeyen dosyalar yeniden okunmaz (her zaman açık)</span>
                  </div>
                </div>
                <button type="button" className="btn" onClick={clearCache}>
                  Önbelleği temizle
                </button>
              </>
            )}
            {section === "diff" && (
              <>
                <h1 className="section-title">Diff</h1>
                <p className="section-desc">Editör ve karşılaştırma limitleri</p>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>Metin dosya limiti</strong>
                    <span>4 MB üzeri uyarı göster</span>
                  </div>
                  <input className="input-field" type="text" value="4 MB" readOnly aria-label="Metin dosya limiti" />
                </div>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>Hex görünüm limiti</strong>
                    <span>256 KB üzeri hex devre dışı</span>
                  </div>
                  <input className="input-field" type="text" value="256 KB" readOnly aria-label="Hex görünüm limiti" />
                </div>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>Varsayılan görünüm</strong>
                    <span>Karşılaştırma açılış modu</span>
                  </div>
                  <select
                    className="input-field"
                    aria-label="Varsayılan görünüm"
                    value={settings.defaultViewMode}
                    onChange={(e) =>
                      save({ defaultViewMode: e.target.value as AppSettings["defaultViewMode"] })
                    }
                  >
                    <option value="side-by-side">Yan yana</option>
                    <option value="inline">Satır içi</option>
                  </select>
                </div>
                <div className="setting-row" style={{ flexDirection: "column", alignItems: "stretch" }}>
                  <div className="setting-label">
                    <strong>Base yolu (3-yönlü)</strong>
                    <span>Ortak ata dosya veya klasör</span>
                  </div>
                  <input
                    className="input-field"
                    style={{ marginTop: 8, fontFamily: "JetBrains Mono, monospace" }}
                    aria-label="Base yolu"
                    value={settings.lastBasePath}
                    onChange={(e) => setSettings({ ...settings, lastBasePath: e.target.value })}
                    onBlur={(e) => save({ lastBasePath: e.target.value.trim() })}
                    placeholder="Opsiyonel base yolu"
                  />
                </div>
              </>
            )}
            {section === "recent" && (
              <>
                <h1 className="section-title">Son Çiftler</h1>
                <p className="section-desc">settings.json — son karşılaştırma çiftleri</p>
                <div className="recent-list">
                  {settings.recentPairs.length === 0 ? (
                    <p className="tree-empty">Henüz kayıt yok.</p>
                  ) : (
                    settings.recentPairs.map((p: RecentPair) => (
                      <button
                        key={`${p.left}|${p.right}`}
                        type="button"
                        className="recent-item"
                        onClick={() => {
                          onSelectRecent?.(p.left, p.right);
                          onClose();
                        }}
                      >
                        <span className="arrow">→</span>
                        {p.left} ↔ {p.right}
                      </button>
                    ))
                  )}
                </div>
                <button type="button" className="btn" onClick={clearRecent}>
                  Listeyi Temizle
                </button>
              </>
            )}
            {section === "gitignore" && (
              <>
                <h1 className="section-title">Gitignore</h1>
                <p className="section-desc">Klasör karşılaştırmada filtrelenen desenler</p>
                <div className="setting-row" style={{ flexDirection: "column", alignItems: "stretch" }}>
                  <div className="setting-label">
                    <strong>Filtre desenleri</strong>
                    <span>Her satır bir glob deseni</span>
                  </div>
                  <textarea
                    className="input-field settings-textarea"
                    rows={6}
                    aria-label="Filtre desenleri"
                    value={ignoreText}
                    onChange={(e) => setIgnoreText(e.target.value)}
                    placeholder={"node_modules/\ndist/"}
                  />
                </div>
                <div className="setting-row">
                  <div className="setting-label">
                    <strong>.gitignore dosyası</strong>
                    <span>Proje kökündeki kuralları uygula</span>
                  </div>
                  <Toggle
                    on={settings.useGitignore}
                    label=".gitignore"
                    onChange={(v) => save({ useGitignore: v })}
                  />
                </div>
                <button type="button" className="btn btn-primary" onClick={saveGitignore}>
                  Kaydet
                </button>
              </>
            )}
          </main>
        </div>
        <footer className="status-bar">
          <button type="button" className="back-link" onClick={onClose}>
            ← Karşılaştırmaya dön
          </button>
          <span className="status-path">%LocalAppData%\DosyaKarsilastirici\settings.json</span>
        </footer>
      </div>
      <div className={`saved-toast${toast ? " show" : ""}`} role="status">
        {toast}
      </div>
    </div>
  );
}
