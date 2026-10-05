"use client";

import dynamic from "next/dynamic";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useCallback, useEffect, useRef, useState } from "react";
import { AppMark, IconCheck, IconClose, IconExport, IconMenu } from "@/components/AppMark";
import { SaveBanner, StatusToast } from "@/components/StatusToast";
import type { BoardApi } from "@/components/TldrawBoard";
import { isBoardEmpty } from "@/lib/board-utils";
import { formatBoardDateShort } from "@/lib/format-date";

const TldrawBoard = dynamic(() => import("@/components/TldrawBoard"), {
  ssr: false,
  loading: () => (
    <div className="absolute inset-0 grid place-items-center text-[var(--text-muted)] text-sm">Tuval yükleniyor…</div>
  ),
});

type BoardItem = { id: string; name: string; updatedAt: string; isEmpty: boolean };

type Props = {
  boardId: string;
  boardName: string;
  initialData: string;
};

type ExportPhase = "idle" | "loading" | "success";

export default function BoardWorkspace({ boardId, boardName, initialData }: Props) {
  const router = useRouter();
  const apiRef = useRef<BoardApi | null>(null);
  const [boards, setBoards] = useState<BoardItem[]>([]);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [saveState, setSaveState] = useState<"idle" | "saving" | "saved" | "error">("idle");
  const [isEmpty, setIsEmpty] = useState(() => isBoardEmpty(initialData));
  const [exportPhase, setExportPhase] = useState<ExportPhase>("idle");
  const [loadError, setLoadError] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const onLoadError = useCallback(() => setLoadError(true), []);

  const loadBoards = useCallback(async () => {
    try {
      const res = await fetch("/api/boards");
      if (res.ok) setBoards((await res.json()).boards ?? []);
    } catch {
      /* kenar çubuğu listesi bir sonraki açılışta yenilenir */
    }
  }, []);

  const createBoard = useCallback(async () => {
    try {
      // Sunucu boş adı "Yeni pano" yapar
      const res = await fetch("/api/boards", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      if (!res.ok) throw new Error();
      router.push(`/board/${(await res.json()).board.id}`);
    } catch {
      setStatus("Pano oluşturulamadı");
    }
  }, [router]);

  useEffect(() => {
    void loadBoards();
  }, [loadBoards]);

  // Kayıttan sonra kenar çubuğundaki tarih / "boş" etiketi güncellenir
  useEffect(() => {
    if (saveState === "saved") void loadBoards();
  }, [saveState, loadBoards]);

  const runExport = useCallback(async () => {
    if (exportPhase === "loading" || !apiRef.current) return;
    setExportPhase("loading");
    try {
      await apiRef.current.exportPng();
      setExportPhase("success");
      setTimeout(() => setExportPhase("idle"), 1200);
    } catch {
      setExportPhase("idle");
      setStatus("PNG oluşturulamadı");
    }
  }, [exportPhase]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "s") {
        e.preventDefault();
        void apiRef.current?.save();
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "e") {
        e.preventDefault();
        void runExport();
      }
      if (e.key === "Escape") setSidebarOpen(false);
    }
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [runExport]);

  const saveMessage =
    saveState === "saving"
      ? "Kaydediliyor…"
      : saveState === "saved"
        ? "Kaydedildi"
        : saveState === "error"
          ? "Kayıt hatası"
          : "";

  return (
    <div className="h-dvh grid grid-rows-[var(--toolbar-height)_1fr] max-md:grid-rows-[1fr_var(--toolbar-height)] bg-[var(--bg-ui)] overflow-hidden">
      <header
        className="flex items-center gap-0.5 px-2 pl-3 border-b border-[var(--border)] bg-[var(--bg-ui)] shadow-[var(--shadow-ui)] z-20 animate-reveal-in max-md:order-2 max-md:border-b-0 max-md:border-t max-md:justify-center max-md:flex-wrap max-md:min-h-[var(--toolbar-height)]"
        role="toolbar"
        aria-label="Pano araç çubuğu"
      >
        <Link
          href="/"
          className="flex items-center gap-2 mr-1 p-1 pl-1 rounded-[var(--radius-md)] transition-colors duration-[var(--dur-fast)] hover:bg-[var(--bg-hover)] active:scale-[0.98]"
          aria-label="Tüm panolara dön"
        >
          <AppMark size="sm" />
        </Link>
        <button
          type="button"
          className="hidden max-lg:grid w-9 h-9 place-items-center rounded-[var(--radius-md)] text-[var(--text-secondary)] hover:bg-[var(--bg-hover)] max-md:hidden"
          aria-label="Pano listesini aç"
          aria-expanded={sidebarOpen}
          onClick={() => setSidebarOpen((v) => !v)}
        >
          <IconMenu />
        </button>
        <div className="w-px h-6 bg-[var(--border)] mx-2 max-md:hidden" aria-hidden />
        <span className="text-sm font-semibold tracking-tight truncate max-w-[200px] max-lg:max-w-[140px] max-md:hidden">
          {boardName}
        </span>
        <div className="ml-auto flex items-center gap-2 max-md:ml-0">
          <button
            type="button"
            onClick={() => apiRef.current?.exportJson()}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 text-[13px] font-medium border border-[var(--border)] text-[var(--text-secondary)] rounded-[var(--radius-sm)] tracking-wide transition-[background,transform] duration-[var(--dur-fast)] hover:bg-[var(--bg-hover)] active:scale-[0.98]"
            aria-label="JSON yedeği indir"
            title="Panoyu JSON olarak yedekle (ana sayfadan içe aktarılabilir)"
          >
            <IconExport />
            <span className="max-md:hidden">JSON</span>
          </button>
          <button
            type="button"
            onClick={() => void runExport()}
            disabled={exportPhase === "loading" || isEmpty}
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-[13px] font-medium border rounded-[var(--radius-sm)] tracking-wide transition-[background,transform,border-color,color] duration-[var(--dur-fast)] active:scale-[0.98] disabled:opacity-50 ${
              exportPhase === "success"
                ? "border-[#16a34a] text-[#16a34a]"
                : "border-[var(--accent)] text-[var(--accent)] hover:bg-[var(--accent-soft)]"
            }`}
            aria-label="PNG dışa aktar"
          >
            {exportPhase === "loading" ? (
              <span className="spinner" />
            ) : exportPhase === "success" ? (
              <IconCheck />
            ) : (
              <IconExport />
            )}
            <span className="max-md:hidden">
              {exportPhase === "loading"
                ? "Dışa aktarılıyor…"
                : exportPhase === "success"
                  ? "İndirildi"
                  : "PNG İndir"}
            </span>
          </button>
        </div>
      </header>

      <SaveBanner state={saveState} message={saveMessage} />
      <StatusToast message={status} />
      {loadError && (
        <div
          role="alert"
          className="fixed top-[calc(var(--toolbar-height)+8px)] left-1/2 -translate-x-1/2 z-30 max-w-[90vw] px-4 py-2 text-xs font-medium rounded-[var(--radius-md)] shadow-[var(--shadow-ui)] bg-[var(--bg-error)] text-[#991b1b]"
        >
          Pano verisi okunamadı; tuval salt okunur açıldı ve kayıt üzerine yazılmayacak. JSON ile yedek alabilirsiniz.
        </div>
      )}

      <div className="grid grid-cols-[var(--sidebar-width)_1fr] overflow-hidden relative max-lg:grid-cols-1 max-md:order-1">
        <div
          className={`fixed inset-0 top-[var(--toolbar-height)] bg-[rgba(15,23,42,0.3)] z-[15] transition-[opacity,visibility] duration-[var(--dur-modal)] max-md:top-0 lg:hidden ${
            sidebarOpen ? "opacity-100 visible" : "opacity-0 invisible"
          }`}
          aria-hidden
          onClick={() => setSidebarOpen(false)}
        />
        <aside
          className={`border-r border-[var(--border)] bg-[var(--bg-ui)] flex flex-col overflow-hidden z-[16] max-lg:fixed max-lg:top-[var(--toolbar-height)] max-lg:left-0 max-lg:bottom-0 max-lg:w-[min(var(--sidebar-width),85vw)] max-lg:shadow-[4px_0_24px_rgba(0,0,0,0.1)] max-lg:transition-transform max-lg:duration-[var(--dur-modal)] max-md:top-0 ${
            sidebarOpen ? "max-lg:translate-x-0" : "max-lg:-translate-x-full"
          }`}
          aria-label="Pano listesi"
        >
          <div className="px-3 pt-3 pb-2 flex items-center justify-between">
            <h2 className="text-[11px] font-medium uppercase tracking-[0.08em] text-[var(--text-muted)]">Panolar</h2>
            <button
              type="button"
              className="hidden max-lg:grid w-7 h-7 place-items-center rounded-[var(--radius-sm)] text-[var(--text-muted)] hover:bg-[var(--bg-hover)]"
              aria-label="Listeyi kapat"
              onClick={() => setSidebarOpen(false)}
            >
              <IconClose />
            </button>
          </div>
          <nav className="flex-1 overflow-y-auto px-2" role="list">
            {boards.map((b, i) => (
              <Link
                key={b.id}
                href={`/board/${b.id}`}
                role="listitem"
                className={`block w-full text-left px-2.5 py-2 mb-0.5 text-[13px] rounded-[var(--radius-sm)] border-l-[3px] transition-[background,border-color] duration-[var(--dur-fast)] animate-reveal-in ${
                  b.id === boardId
                    ? "bg-[var(--bg-selected)] text-[var(--text-primary)] font-semibold border-l-[var(--accent)]"
                    : "text-[var(--text-secondary)] border-l-transparent hover:bg-[var(--bg-hover)]"
                }`}
                style={{ animationDelay: `${80 + i * 40}ms` }}
                onClick={() => setSidebarOpen(false)}
              >
                {b.name}
                <span className="block text-[11px] font-normal text-[var(--text-muted)] mt-0.5 tracking-wide">
                  {formatBoardDateShort(b.updatedAt)}
                  {b.isEmpty ? " · boş" : ""}
                </span>
              </Link>
            ))}
          </nav>
          <div className="p-3 border-t border-[var(--border)]">
            <button
              type="button"
              className="w-full py-2 text-[13px] font-medium text-[var(--text-secondary)] border border-dashed border-[var(--border)] rounded-[var(--radius-sm)] tracking-wide hover:bg-[var(--bg-hover)] hover:border-[var(--text-muted)] active:scale-[0.98] transition-[background,border-color,transform] duration-[var(--dur-fast)]"
              onClick={() => void createBoard()}
            >
              + Yeni pano
            </button>
            <Link href="/" className="block mt-2 text-xs text-center text-[var(--text-muted)] hover:text-[var(--text-secondary)]">
              ← Tüm panolar
            </Link>
          </div>
        </aside>

        <main className="relative overflow-hidden canvas-dots" aria-label="Tuval">
          <TldrawBoard
            boardId={boardId}
            initialData={initialData}
            boardName={boardName}
            onSaveState={setSaveState}
            onEmptyChange={setIsEmpty}
            onLoadError={onLoadError}
            apiRef={apiRef}
          />
          {isEmpty && (
            <div
              className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-center pointer-events-none max-w-[300px] px-4 animate-reveal-in"
              style={{ animationDelay: "300ms" }}
            >
              <svg
                className="w-14 h-14 mx-auto mb-4 text-[var(--text-muted)]"
                viewBox="0 0 56 56"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                aria-hidden
              >
                <rect x="10" y="14" width="36" height="28" rx="3" strokeDasharray="5 4" />
                <path d="M20 28h16M28 22v12" />
              </svg>
              <h2 className="text-sm font-normal text-[var(--text-secondary)] leading-relaxed">
                Başlamak için tuvalde çift tıklayın
              </h2>
              <p className="mt-2 text-xs text-[var(--text-muted)] tracking-wide">
                veya tldraw araç çubuğundan şekil, ok veya metin ekleyin
              </p>
            </div>
          )}
          <p className="absolute bottom-4 left-4 text-[11px] text-[var(--text-muted)] tracking-wide bg-[var(--bg-ui)] border border-[var(--border)] rounded-[var(--radius-sm)] px-2.5 py-1.5 shadow-[var(--shadow-ui)] max-md:hidden animate-reveal-in" style={{ animationDelay: "600ms" }}>
            <kbd className="font-mono text-[10px] px-1 border border-[var(--border)] rounded bg-[var(--bg-hover)]">Ctrl+S</kbd> kaydet ·{" "}
            <kbd className="font-mono text-[10px] px-1 border border-[var(--border)] rounded bg-[var(--bg-hover)]">Ctrl+E</kbd> PNG
          </p>
        </main>
      </div>
    </div>
  );
}
