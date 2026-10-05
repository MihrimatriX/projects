"use client";

import { useEffect, useRef, useState } from "react";
import CodeMirrorEditor from "@/components/CodeMirrorEditor";
import VirtualJsonTree from "@/components/VirtualJsonTree";
import HelpModal from "@/components/HelpModal";
import LargeFileModal from "@/components/LargeFileModal";
import TauriIntegration from "@/components/TauriIntegration";
import BrandIcon from "@/components/shell/BrandIcon";
import ErrorPanel from "@/components/shell/ErrorPanel";
import StatusBar from "@/components/shell/StatusBar";
import ToolbarNav from "@/components/shell/ToolbarNav";
import ValidBadge from "@/components/shell/ValidBadge";
import WorkerBanner from "@/components/shell/WorkerBanner";
import { useKeyboardShortcuts } from "@/hooks/useKeyboardShortcuts";
import { loadFile, openJsonFile, saveJson } from "@/lib/file-io";
import { useSplitResize } from "@/hooks/useSplitResize";
import { useJsonStore } from "@/lib/store";
import { buildShareUrl } from "@/lib/share-url";
import { jsonToTypeScript } from "@/lib/ts-interface";

type MobileTab = "editor" | "tree";

export default function LabPage() {
  const {
    formatJson,
    minifyJson,
    sortKeys,
    clearAll,
    isParsing,
    isValid,
    rawJson,
    watchedFilePath,
    fileName,
    parsedJson,
    inputMode,
  } = useJsonStore();
  const [notice, setNotice] = useState("");
  const [canShare, setCanShare] = useState(false);
  const [mobileTab, setMobileTab] = useState<MobileTab>("editor");
  const [helpOpen, setHelpOpen] = useState(false);
  const [dragging, setDragging] = useState(false);

  const leftRef = useRef<HTMLElement>(null);
  const rightRef = useRef<HTMLElement>(null);
  const handleRef = useRef<HTMLDivElement>(null);
  useSplitResize(handleRef, leftRef, rightRef);
  useKeyboardShortcuts();

  // Paylasim baglantisi yalnizca web'de anlamli (Electron'da adres app://).
  useEffect(() => setCanShare(window.location.protocol.startsWith("http")), []);
  useEffect(() => {
    if (!notice) return;
    const t = setTimeout(() => setNotice(""), 3000);
    return () => clearTimeout(t);
  }, [notice]);

  const copy = async (text: string, ok: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setNotice(ok);
    } catch {
      setNotice("Panoya erişilemedi");
    }
  };
  const share = async () => {
    const url = buildShareUrl(rawJson, inputMode);
    if (!url) {
      setNotice("Paylaşım bağlantısı için içerik çok büyük (200 KB üstü)");
      return;
    }
    await copy(url, "Paylaşım bağlantısı panoya kopyalandı");
  };

  useEffect(() => {
    const onHelp = () => setHelpOpen(true);
    window.addEventListener("json-open-help", onHelp);
    return () => window.removeEventListener("json-open-help", onHelp);
  }, []);

  useEffect(() => {
    const onDragOver = (e: DragEvent) => {
      e.preventDefault();
      setDragging(true);
    };
    const onDragLeave = () => setDragging(false);
    const onDrop = (e: DragEvent) => {
      e.preventDefault();
      setDragging(false);
      const file = e.dataTransfer?.files?.[0];
      if (file) loadFile(file);
    };
    window.addEventListener("dragover", onDragOver);
    window.addEventListener("dragleave", onDragLeave);
    window.addEventListener("drop", onDrop);
    return () => {
      window.removeEventListener("dragover", onDragOver);
      window.removeEventListener("dragleave", onDragLeave);
      window.removeEventListener("drop", onDrop);
    };
  }, []);

  const fileLabel = (watchedFilePath ?? fileName)?.split(/[/\\]/).pop() ?? (rawJson.trim() ? "düzenleniyor" : "boş");

  return (
    <div className="app-shell">
      <header className="toolbar">
        <div className="toolbar-brand">
          <BrandIcon />
          JSON Formatlayıcı
        </div>
        <div className="toolbar-actions">
          <button type="button" className="btn-ghost" data-testid="btn-format" onClick={formatJson} disabled={!rawJson || !isValid} title="Ctrl+Shift+F">
            Format
          </button>
          <button type="button" className="btn-ghost" onClick={minifyJson} disabled={!rawJson || !isValid} title="Ctrl+Shift+M">
            Minify
          </button>
          <button type="button" className="btn-ghost" onClick={sortKeys} disabled={!rawJson || !isValid || inputMode === "ndjson"} title="Anahtarları sırala (Ctrl+Shift+K)">
            Sırala
          </button>
          <button type="button" className="btn-ghost" data-testid="btn-demo" onClick={() => useJsonStore.getState().loadDemo()}>
            Demo
          </button>
          <button type="button" className="btn-ghost" data-testid="btn-open" onClick={openJsonFile} title="Ctrl+O">
            Aç
          </button>
          <button type="button" className="btn-ghost" data-testid="btn-save" onClick={() => void saveJson()} disabled={!rawJson} title="Ctrl+S">
            Kaydet
          </button>
          <button type="button" className="btn-ghost" data-testid="btn-clear" onClick={clearAll} disabled={!rawJson} title="Editörü temizle">
            Temizle
          </button>
          <span className="toolbar-divider" aria-hidden />
          <button type="button" className="btn-ghost" data-testid="btn-copy" onClick={() => void copy(rawJson, "Editör içeriği panoya kopyalandı")} disabled={!rawJson} title="Editör içeriğini panoya kopyala">
            Kopyala
          </button>
          <button
            type="button"
            className="btn-ghost"
            data-testid="btn-ts"
            onClick={() => void copy(jsonToTypeScript("Root", parsedJson), "TypeScript tipi panoya kopyalandı")}
            disabled={!rawJson || !isValid || parsedJson === null}
            title="JSON'dan TypeScript tipi üret ve panoya kopyala"
          >
            TS tipi
          </button>
          {canShare && (
            <button type="button" className="btn-ghost" data-testid="btn-share" onClick={() => void share()} disabled={!rawJson} title="İçeriği taşıyan paylaşım bağlantısını kopyala">
              Paylaş
            </button>
          )}
          <button type="button" className="btn-ghost" data-testid="btn-help" onClick={() => setHelpOpen(true)} aria-label="Yardım ve kısayollar (F1)" title="Yardım (F1)">
            ?
          </button>
        </div>
        <span className="toolbar-notice" role="status" aria-live="polite" data-testid="notice">
          {notice}
        </span>
        <div className="toolbar-spacer" />
        <ValidBadge />
        <div className={`worker-spinner-inline${isParsing ? " is-visible" : ""}`} aria-hidden={!isParsing}>
          <div className="spinner" />
        </div>
        <div className="toolbar-divider" aria-hidden />
        <ToolbarNav active="/lab" />
      </header>

      <WorkerBanner />

      <div className="workspace mobile-tabs" id="workspace">
        <section ref={leftRef} className={`panel-editor${mobileTab === "editor" ? " active" : ""}`}>
          <div className="panel-header">
            <span>Editör</span>
            <span className="panel-meta">{fileLabel}</span>
          </div>
          <CodeMirrorEditor />
        </section>

        <div ref={handleRef} className="split-handle" role="separator" aria-orientation="vertical" aria-label="Panel genişliğini ayarla" tabIndex={0} />

        <section ref={rightRef} className={`panel-tree${mobileTab === "tree" ? " active" : ""}`}>
          <div className="panel-header">
            <span>Ağaç</span>
          </div>
          <VirtualJsonTree />
        </section>
      </div>

      <ErrorPanel />

      <div className="mobile-tabbar">
        <button type="button" className={mobileTab === "editor" ? "active" : ""} onClick={() => setMobileTab("editor")}>
          Editör
        </button>
        <button type="button" className={mobileTab === "tree" ? "active" : ""} onClick={() => setMobileTab("tree")}>
          Ağaç
        </button>
      </div>

      <StatusBar />

      <HelpModal open={helpOpen} onClose={() => setHelpOpen(false)} />
      <LargeFileModal />
      <TauriIntegration />

      {dragging && (
        <div className="modal-overlay open" aria-hidden>
          <div className="modal" style={{ maxWidth: 360 }}>
            <div className="modal-body">
              <strong>JSON dosyasını buraya bırakın</strong>
              <p className="query-hint">5 MB üzeri dosyalar için onay istenir.</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
