"use client";

import { getAssetUrls } from "@tldraw/assets/selfHosted";
import {
  Tldraw,
  exportToBlob,
  getSnapshot,
  loadSnapshot,
  type Editor,
  type TLEditorSnapshot,
} from "tldraw";
import "tldraw/tldraw.css";
import { useCallback, useEffect, useRef } from "react";
import { buildExport, exportFileName } from "@/lib/board-utils";

type SaveState = "idle" | "saving" | "saved" | "error";

export type BoardApi = {
  save: () => Promise<void>;
  exportPng: () => Promise<void>;
  exportJson: () => void;
};

type Props = {
  boardId: string;
  initialData: string;
  boardName: string;
  onSaveState?: (state: SaveState) => void;
  onEmptyChange?: (empty: boolean) => void;
  onLoadError?: () => void;
  apiRef?: React.MutableRefObject<BoardApi | null>;
};

// İkon, yazı tipi ve çeviriler CDN yerine public/tldraw-assets'ten (npm run dev/build öncesi kopyalanır):
// masaüstü sürümü çevrimdışı da tam çalışır.
const assetUrls = getAssetUrls({ baseUrl: "/tldraw-assets" });

function download(blob: Blob, fileName: string) {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

declare global {
  interface Window {
    /** Masaüstü kabuğu pencere kapanmadan önce bekleyen kaydı yazdırır (desktop/main.cjs). */
    __flushBoardSave?: () => Promise<void>;
  }
}

export default function TldrawBoard({
  boardId,
  initialData,
  boardName,
  onSaveState,
  onEmptyChange,
  onLoadError,
  apiRef,
}: Props) {
  const editorRef = useRef<Editor | null>(null);
  const saveTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const savedBannerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  // Kaydedilmemiş değişiklik var mı (bekleyen debounce ya da başarısız kayıt)
  const dirtyRef = useRef(false);
  // Kayıtlar sırayla yazılır: geç biten eski bir istek yeni kaydı ezemez.
  const chainRef = useRef<Promise<void>>(Promise.resolve());
  // Kayıtlı veri okunamadıysa asla üzerine yazılmaz (boş tuval mevcut panoyu silmesin).
  const blockedRef = useRef(false);

  const persistSnapshot = useCallback(
    (editor: Editor): Promise<void> => {
      if (saveTimerRef.current) {
        clearTimeout(saveTimerRef.current);
        saveTimerRef.current = null;
      }
      if (blockedRef.current) return chainRef.current;
      const run = async () => {
        if (!dirtyRef.current) return;
        dirtyRef.current = false;
        onSaveState?.("saving");
        try {
          const res = await fetch(`/api/boards/${boardId}`, {
            method: "PATCH",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ data: JSON.stringify(getSnapshot(editor.store)) }),
          });
          // fetch HTTP 4xx/5xx'te hata fırlatmaz; aksi halde başarısız kayıt "Kaydedildi" görünürdü.
          if (!res.ok) throw new Error(`HTTP ${res.status}`);
          onSaveState?.("saved");
          if (savedBannerRef.current) clearTimeout(savedBannerRef.current);
          savedBannerRef.current = setTimeout(() => onSaveState?.("idle"), 2000);
        } catch {
          dirtyRef.current = true;
          onSaveState?.("error");
        }
      };
      chainRef.current = chainRef.current.then(run);
      return chainRef.current;
    },
    [boardId, onSaveState]
  );

  const flush = useCallback(() => {
    const editor = editorRef.current;
    return editor && dirtyRef.current ? persistSnapshot(editor) : chainRef.current;
  }, [persistSnapshot]);

  // Otomatik kayıt: kullanıcı kaynaklı her belge değişikliğinde 2 sn debounce, sonra tüm store
  // snapshot'ı JSON olarak PATCH /api/boards/:id ile SQLite'a yazılır.
  const scheduleSave = useCallback(
    (editor: Editor) => {
      dirtyRef.current = true;
      if (saveTimerRef.current) clearTimeout(saveTimerRef.current);
      saveTimerRef.current = setTimeout(() => void persistSnapshot(editor), 2000);
    },
    [persistSnapshot]
  );

  const updateEmpty = useCallback(
    (editor: Editor) => onEmptyChange?.(editor.getCurrentPageShapeIds().size === 0),
    [onEmptyChange]
  );

  const exportPng = useCallback(async () => {
    const editor = editorRef.current;
    if (!editor) return;
    const ids = [...editor.getCurrentPageShapeIds()];
    if (!ids.length) throw new Error("Tuval boş");
    const blob = await exportToBlob({ editor, ids, format: "png", opts: { background: true, scale: 2 } });
    download(blob, exportFileName(boardName, "png"));
  }, [boardName]);

  const exportJson = useCallback(() => {
    const editor = editorRef.current;
    // Veri okunamadıysa tuvaldeki boş hali değil, kayıtlı ham veriyi yedekle
    const data =
      editor && !blockedRef.current ? JSON.stringify(getSnapshot(editor.store)) : initialData;
    download(
      new Blob([buildExport(boardName, data)], { type: "application/json" }),
      exportFileName(boardName, "json")
    );
  }, [boardName, initialData]);

  useEffect(() => {
    if (apiRef) apiRef.current = { save: flush, exportPng, exportJson };
    window.__flushBoardSave = flush;
    return () => {
      if (apiRef) apiRef.current = null;
      if (window.__flushBoardSave === flush) delete window.__flushBoardSave;
    };
  }, [apiRef, flush, exportPng, exportJson]);

  // Sekme/pencere kapanırken bekleyen kayıt varsa hemen yaz ve tarayıcının uyarısını göster.
  useEffect(() => {
    function onBeforeUnload(e: BeforeUnloadEvent) {
      if (!dirtyRef.current || blockedRef.current) return;
      void flush();
      e.preventDefault();
    }
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [flush]);

  const handleMount = useCallback(
    (editor: Editor) => {
      editorRef.current = editor;
      blockedRef.current = false;
      if (initialData && initialData !== "{}") {
        try {
          loadSnapshot(editor.store, JSON.parse(initialData) as TLEditorSnapshot);
        } catch (err) {
          console.error("Pano verisi yüklenemedi", err);
          blockedRef.current = true;
          editor.updateInstanceState({ isReadonly: true });
          onLoadError?.();
        }
      }
      updateEmpty(editor);
      const unlisten = editor.store.listen(
        () => {
          scheduleSave(editor);
          updateEmpty(editor);
        },
        { source: "user", scope: "document" }
      );
      return () => unlisten();
    },
    [initialData, scheduleSave, updateEmpty, onLoadError]
  );

  useEffect(
    () => () => {
      // Bekleyen debounce kaydı varsa iptal etmek yerine hemen yaz: 2 sn içinde başka panoya/sayfaya
      // geçilince son değişiklikler kayboluyordu.
      void flush();
      if (savedBannerRef.current) clearTimeout(savedBannerRef.current);
    },
    [flush]
  );

  return (
    <div className="absolute inset-0">
      <Tldraw onMount={handleMount} assetUrls={assetUrls} />
    </div>
  );
}
