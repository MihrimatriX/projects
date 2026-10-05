"use client";

import { useEffect, useState } from "react";
import TauriIntegration from "@/components/TauriIntegration";
import BrandIcon from "@/components/shell/BrandIcon";
import StatusBar from "@/components/shell/StatusBar";
import ToolbarNav from "@/components/shell/ToolbarNav";
import { formatFileSize } from "@/lib/json-utils";
import { useKeyboardShortcuts } from "@/hooks/useKeyboardShortcuts";
import { openJsonFile, saveJson } from "@/lib/file-io";
import { useJsonStore } from "@/lib/store";

export default function FilePage() {
  const {
    rawJson,
    watchedFilePath,
    recentFiles,
    fileChangedExternally,
    watchEnabled,
    setWatchEnabled,
    setFileChangedExternally,
    loadJsonContent,
    isTauriApp,
    fileSize,
    fileName,
  } = useJsonStore();
  useKeyboardShortcuts();

  const [mobileTab, setMobileTab] = useState<"files" | "preview">("files");
  const [loading, setLoading] = useState(false);
  const activePath = watchedFilePath ?? recentFiles[0]?.path ?? null;
  const activeName = (activePath ?? fileName)?.split(/[/\\]/).pop() ?? "Dosya seçilmedi";
  const lineCount = rawJson ? rawJson.split("\n").length : 0;

  useEffect(() => {
    if (fileChangedExternally) {
      const t = setTimeout(() => setFileChangedExternally(false), 4000);
      return () => clearTimeout(t);
    }
  }, [fileChangedExternally, setFileChangedExternally]);

  const saveFile = async () => {
    if (!rawJson) return;
    setLoading(true);
    await saveJson();
    setLoading(false);
    setFileChangedExternally(false);
  };

  const selectRecent = async (path: string) => {
    setLoading(true);
    const { tauriReadFile } = await import("@/lib/tauri-bridge");
    const content = await tauriReadFile(path);
    setLoading(false);
    if (content === null) return;
    loadJsonContent(content, { bypassWarning: true });
    useJsonStore.getState().setWatchedFilePath(path);
  };

  return (
    <div className="app-shell">
      <header className="toolbar">
        <div className="toolbar-brand">
          <BrandIcon />
          Dosya Entegrasyonu
        </div>
        <div className="toolbar-actions">
          <button type="button" className="btn-ghost" data-testid="btn-tauri-open" onClick={openJsonFile} title="Ctrl+O">
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M3 2h7l3 3v9H3V2z" /></svg>
            Aç
          </button>
          <button type="button" className="btn-ghost" onClick={saveFile} disabled={!rawJson} title={isTauriApp ? "Ctrl+S" : "Ctrl+S (indir)"}>
            <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M3 12V4l10-2v10H3z" /><path d="M6 14h4" /></svg>
            Kaydet
          </button>
          {isTauriApp && (
            <button
              type="button"
              className={`btn-ghost${watchEnabled ? " active" : ""}`}
              aria-pressed={watchEnabled}
              onClick={() => setWatchEnabled(!watchEnabled)}
              title="Dış değişiklikleri izle"
            >
              İzle
            </button>
          )}
        </div>
        <div className="toolbar-spacer" />
        <span className={`file-badge${fileChangedExternally ? " is-visible" : ""}`} role="status" aria-live="polite">
          <span className="dot" aria-hidden />
          dış değişiklik
        </span>
        <ToolbarNav active="/file" />
      </header>

      <main className="secondary-main" id="file-main">
        <div className={`split-2 file-split${mobileTab ? " file-mobile-tabs" : ""}`}>
          <section className={`split-col-primary file-panel${mobileTab === "files" ? " active" : ""}`}>
            <div className="panel-header">
              <span>Aktif dosya</span>
            </div>
            <div className="active-file-block">
              <div className="active-file-row">
                <svg width="14" height="14" viewBox="0 0 16 16" fill="none" stroke="var(--text-secondary)" strokeWidth="1.5"><path d="M3 2h7l3 3v9H3V2z" /></svg>
                <span className="active-file-name">{activeName}</span>
              </div>
              <p className="active-file-path">{activePath ?? "Henüz dosya açılmadı"}</p>
              <p className="active-file-note">
                {isTauriApp
                  ? "Tauri dosya izleme. Dış değişiklikler otomatik yüklenir."
                  : "Web/masaüstü modunda dosya seçici ile açılır, Kaydet indirir. Dış değişiklik izleme yalnızca Tauri build'de."}
              </p>
            </div>
            <div className="panel-header">
              <span>Son dosyalar</span>
            </div>
            <div className="file-list-scroll">
              {recentFiles.length === 0 ? (
                <p className="file-empty">Açılan dosyalar burada listelenir.</p>
              ) : (
                <ul className="file-list" role="listbox" aria-label="Son dosyalar">
                  {recentFiles.map((f) => (
                    <li
                      key={f.path}
                      className={`file-item${f.path === activePath ? " selected" : ""}`}
                      role="option"
                      tabIndex={0}
                      aria-selected={f.path === activePath}
                      onClick={() => selectRecent(f.path)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" || e.key === " ") {
                          e.preventDefault();
                          selectRecent(f.path);
                        }
                      }}
                    >
                      <svg viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M3 2h7l3 3v9H3V2z" /></svg>
                      <div className="file-meta">
                        <div className="file-name">{f.name}</div>
                        <div className="file-path">{f.path}</div>
                      </div>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </section>

          <section className={`split-col-secondary preview-panel${mobileTab === "preview" ? " active" : ""}`}>
            <div className="panel-header">
              <span>Önizleme</span>
              <span className="panel-meta">{lineCount ? `${lineCount} satır` : "- satır"}</span>
            </div>
            <div className="editor-wrap">
              <div className={`preview-loading${loading ? " is-visible" : ""}`}>
                <div className="spinner" />
                <span>Yükleniyor…</span>
              </div>
              {!rawJson && <p className="file-empty preview-empty">JSON önizlemesi için dosya açın veya Laboratuvar ekranına veri girin.</p>}
              <div className="line-gutter" aria-hidden hidden={!rawJson}>
                {rawJson.split("\n").map((_, i) => (
                  <div key={i} className="line-num">
                    {i + 1}
                  </div>
                ))}
              </div>
              <div className="editor-area">
                <pre className="editor-highlight" aria-label="JSON önizleme" tabIndex={0} hidden={!rawJson}>
                  {rawJson}
                </pre>
              </div>
            </div>
          </section>
        </div>
      </main>

      <div className="mobile-tabbar">
        <button type="button" className={mobileTab === "files" ? "active" : ""} onClick={() => setMobileTab("files")}>
          Dosyalar
        </button>
        <button type="button" className={mobileTab === "preview" ? "active" : ""} onClick={() => setMobileTab("preview")}>
          Önizleme
        </button>
      </div>

      <StatusBar
        left={<span className="statusbar-item mono">{formatFileSize(fileSize)}</span>}
        right={<span className="statusbar-item">File</span>}
      />

      <TauriIntegration />
    </div>
  );
}
