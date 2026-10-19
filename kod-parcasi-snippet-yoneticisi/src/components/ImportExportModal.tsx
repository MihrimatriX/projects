import { useEffect, useRef, useState } from "react";
import type { Snippet } from "../types";
import { collectFolders, collectTags, ipcErrorMessage, summarizeImport } from "../lib/format";
import { useToast } from "../hooks/useToast";
import { Toast } from "./Toast";

type Tab = "import" | "export";

type Props = {
  open: boolean;
  onClose: () => void;
  onImported: () => void;
};

export function ImportExportModal({ open, onClose, onImported }: Props) {
  const [tab, setTab] = useState<Tab>("import");
  const [snippets, setSnippets] = useState<Snippet[]>([]);
  const [importReady, setImportReady] = useState(false);
  const [importError, setImportError] = useState("");
  const [pendingText, setPendingText] = useState("");
  const [pendingCount, setPendingCount] = useState({ snippets: 0, tags: 0, folders: 0 });
  const fileRef = useRef<HTMLInputElement>(null);
  const toast = useToast();

  useEffect(() => {
    if (!open) return;
    void window.electronAPI.getSnippets().then(setSnippets);
    setImportReady(false);
    setImportError("");
    setPendingText("");
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  const tagCount = collectTags(snippets).length;
  const folderCount = collectFolders(snippets).length;

  async function handleImportClick() {
    setImportError("");
    try {
      const result = pendingText
        ? await window.electronAPI.importSnippetsFromText(pendingText)
        : await window.electronAPI.importSnippets();

      setImportReady(false);
      setPendingText("");
      if (result.imported > 0) {
        toast.show(`${result.imported} snippet import edildi`);
        onImported();
        setSnippets(await window.electronAPI.getSnippets());
      } else {
        toast.show("Yeni snippet eklenmedi");
      }
    } catch (err) {
      setImportError(ipcErrorMessage(err));
    }
  }

  async function handleExportClick() {
    try {
      const ok = await window.electronAPI.exportSnippets();
      toast.show(ok ? "JSON dosyası kaydedildi" : "Dışa aktarma iptal edildi");
    } catch (err) {
      toast.show(`Dışa aktarılamadı: ${ipcErrorMessage(err)}`);
    }
  }

  function handleFile(file: File | null) {
    setImportError("");
    setImportReady(false);
    setPendingText("");
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      try {
        setPendingCount(summarizeImport(String(reader.result)));
        setPendingText(String(reader.result));
        setImportReady(true);
      } catch (err) {
        setImportError(err instanceof Error ? err.message : "Geçersiz JSON");
      }
    };
    reader.readAsText(file);
  }

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div
        className="modal-sheet"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-label="Import / Export"
      >
        <div className="modal-content">
          <div className="modal-head">
            <h1>JSON Import / Export</h1>
            <button type="button" className="modal-close" onClick={onClose} aria-label="Kapat">
              ✕
            </button>
          </div>
          <p className="modal-sub">
            Snippet kütüphanenizi taşıyın. Tamamen yerel — %AppData% altında snippets.json
          </p>

          <div className="tabs" role="tablist">
            <button
              type="button"
              role="tab"
              className={`tab${tab === "import" ? " active" : ""}`}
              aria-selected={tab === "import"}
              onClick={() => setTab("import")}
            >
              Import
            </button>
            <button
              type="button"
              role="tab"
              className={`tab${tab === "export" ? " active" : ""}`}
              aria-selected={tab === "export"}
              onClick={() => setTab("export")}
            >
              Export
            </button>
          </div>

          {tab === "import" ? (
            <div className="panel active">
              <div
                className="drop-zone"
                role="button"
                tabIndex={0}
                onClick={() => fileRef.current?.click()}
                onKeyDown={(e) => e.key === "Enter" && fileRef.current?.click()}
                onDragOver={(e) => {
                  e.preventDefault();
                  e.currentTarget.classList.add("dragover");
                }}
                onDragLeave={(e) => e.currentTarget.classList.remove("dragover")}
                onDrop={(e) => {
                  e.preventDefault();
                  e.currentTarget.classList.remove("dragover");
                  handleFile(e.dataTransfer.files[0] ?? null);
                }}
              >
                <p>JSON dosyasını sürükleyin veya seçin</p>
                <span>snippets.json · yerel yedek formatı</span>
              </div>
              <input
                ref={fileRef}
                type="file"
                accept=".json,application/json"
                aria-label="JSON dosyası seç"
                hidden
                onChange={(e) => handleFile(e.target.files?.[0] ?? null)}
              />
              {importError && (
                <div className="error-box show" role="alert">
                  <strong>Import hatası</strong>
                  <br />
                  {importError}
                </div>
              )}
              {importReady && (
                <div className="summary show">
                  <h2>Doğrulama özeti</h2>
                  <div className="summary-grid">
                    <div className="stat">
                      <div className="stat-num">{pendingCount.snippets}</div>
                      <div className="stat-label">Snippet</div>
                    </div>
                    <div className="stat">
                      <div className="stat-num">{pendingCount.tags}</div>
                      <div className="stat-label">Etiket</div>
                    </div>
                    <div className="stat">
                      <div className="stat-num">{pendingCount.folders}</div>
                      <div className="stat-label">Klasör</div>
                    </div>
                  </div>
                </div>
              )}
              <div className="modal-actions">
                <button type="button" className="btn-ghost" onClick={onClose}>
                  İptal
                </button>
                <button type="button" className="btn-primary" onClick={() => void handleImportClick()}>
                  Import et
                </button>
              </div>
            </div>
          ) : (
            <div className="panel active">
              <p className="panel-desc">
                Mevcut kütüphaneyi JSON olarak dışa aktarın. Ctrl+E kısayolu ana pencereden de çalışır.
              </p>
              <div className="summary show">
                <h2>Dışa aktarılacak içerik</h2>
                <div className="summary-grid">
                  <div className="stat">
                    <div className="stat-num">{snippets.length}</div>
                    <div className="stat-label">Snippet</div>
                  </div>
                  <div className="stat">
                    <div className="stat-num">{tagCount}</div>
                    <div className="stat-label">Etiket</div>
                  </div>
                  <div className="stat">
                    <div className="stat-num">{folderCount}</div>
                    <div className="stat-label">Klasör</div>
                  </div>
                </div>
              </div>
              <div className="modal-actions">
                <button type="button" className="btn-ghost" onClick={onClose}>
                  İptal
                </button>
                <button type="button" className="btn-primary" onClick={() => void handleExportClick()}>
                  Dışa aktar
                </button>
              </div>
            </div>
          )}
        </div>
        <Toast message={toast.message} visible={toast.visible} />
      </div>
    </div>
  );
}
