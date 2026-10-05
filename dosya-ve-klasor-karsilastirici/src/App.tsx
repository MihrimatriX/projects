import { useCallback, useEffect, useState, type DragEvent } from "react";
import { DiffPane } from "./components/DiffPane";
import { FolderTree } from "./components/FolderTree";
import { GitDiffDialog } from "./components/GitDiffDialog";
import { HelpDialog } from "./components/HelpDialog";
import { SettingsDialog } from "./components/SettingsDialog";
import { ThreeWayPane } from "./components/ThreeWayPane";
import { Toast } from "./components/Toast";
import { Toolbar } from "./components/Toolbar";
import { ViewTabs } from "./components/ViewTabs";
import { WelcomePane } from "./components/WelcomePane";
import { useKeyboard } from "./hooks/useKeyboard";
import type {
  AppSettings,
  CompareProgress,
  CompareResult,
  ConflictResolution,
  FilePairContent,
  FolderCompareResult,
  GitDiffSession,
  MergeDirection,
  ParsedGitDiff,
  ThreeWayContent,
  ViewMode,
} from "./types";
import { basename } from "./utils/language";

/** IPC hataları "Error invoking remote method ...: Error: " önekiyle gelir; kullanıcıya yalnızca asıl mesaj gösterilir. */
function errorText(e: unknown): string {
  const msg = e instanceof Error ? e.message : String(e);
  return msg.replace(/^Error invoking remote method '[^']+': (?:\w*Error: )?/, "");
}

export default function App() {
  const [left, setLeft] = useState("");
  const [right, setRight] = useState("");
  const [base, setBase] = useState("");
  const [compareResult, setCompareResult] = useState<CompareResult | null>(null);
  const [gitSession, setGitSession] = useState<GitDiffSession | null>(null);
  const [selectedFile, setSelectedFile] = useState<string | null>(null);
  const [fileContent, setFileContent] = useState<FilePairContent | null>(null);
  const [threeWay, setThreeWay] = useState<ThreeWayContent | null>(null);
  const [viewMode, setViewMode] = useState<ViewMode>("side-by-side");
  const [error, setError] = useState("");
  const [toast, setToast] = useState("");
  const [loading, setLoading] = useState(false);
  const [loadingFile, setLoadingFile] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [gitOpen, setGitOpen] = useState(false);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const [recentPairs, setRecentPairs] = useState<AppSettings["recentPairs"]>([]);
  const [compareProgress, setCompareProgress] = useState<CompareProgress | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [narrow, setNarrow] = useState(window.innerWidth <= 900);
  const [theme, setTheme] = useState<AppSettings["theme"]>("dark");

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  const folderMode = compareResult?.mode === "folder" && !gitSession;
  const folderResult = folderMode ? (compareResult as FolderCompareResult) : null;
  const threeWayAvailable = !!base.trim();
  const hexAvailable = !!fileContent?.binary;
  const showDiff = compareResult !== null || gitSession !== null;

  const applyGitFile = useCallback((file: ParsedGitDiff) => {
    setFileContent({
      left: file.left,
      right: file.right,
      binary: false,
      truncated: false,
      stats: file.stats,
      leftPath: file.fileName,
      rightPath: file.fileName,
      missingSide: null,
      leftHex: null,
      rightHex: null,
      leftSize: file.left.length,
      rightSize: file.right.length,
      language: "plaintext",
    });
    setSelectedFile(file.fileName);
  }, []);

  useEffect(() => {
    window.electronAPI.getSettings().then((s) => {
      if (s.lastLeftPath) setLeft(s.lastLeftPath);
      if (s.lastRightPath) setRight(s.lastRightPath);
      if (s.lastBasePath) setBase(s.lastBasePath);
      setViewMode(s.defaultViewMode);
      setRecentPairs(s.recentPairs ?? []);
      setTheme(s.theme ?? "dark");
    });
  }, []);

  useEffect(() => window.electronAPI.onCompareProgress(setCompareProgress), []);

  useEffect(() => {
    const onResize = () => setNarrow(window.innerWidth <= 900);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  // l/r parametreleri: setLeft/setRight henüz uygulanmadan çağrılırsa (son çiftler) eski yollar kullanılmasın.
  const loadFilePair = useCallback(
    async (relativePath?: string, l = left, r = right) => {
      if (!l || !r) return;
      setLoadingFile(true);
      setError("");
      try {
        const data = await window.electronAPI.readFilePair(l, r, relativePath);
        setFileContent(data);
        // Binary dosyada hex'e geç; metin dosyasına dönünce boş hex panelinde kalma.
        if (data.binary) setViewMode("hex");
        else setViewMode((m) => (m === "hex" ? "side-by-side" : m));
      } catch (e) {
        setError(errorText(e));
        setFileContent(null);
      } finally {
        setLoadingFile(false);
      }
    },
    [left, right]
  );

  const loadThreeWay = useCallback(
    async (relativePath?: string) => {
      if (!base || !left || !right) return;
      setLoadingFile(true);
      setError("");
      try {
        setThreeWay(await window.electronAPI.readFileTriple(base, left, right, relativePath));
      } catch (e) {
        setError(errorText(e));
        setThreeWay(null);
      } finally {
        setLoadingFile(false);
      }
    },
    [base, left, right]
  );

  useEffect(() => {
    if (viewMode !== "three-way" || !threeWayAvailable) {
      setThreeWay(null);
      return;
    }
    const rel = folderMode ? selectedFile ?? undefined : undefined;
    if (folderMode && !rel) return;
    loadThreeWay(rel);
  }, [viewMode, threeWayAvailable, selectedFile, folderMode, loadThreeWay]);

  async function pickPath(side: "left" | "right") {
    const path = await window.electronAPI.pickPath();
    if (!path) return;
    if (side === "left") setLeft(path);
    else setRight(path);
  }

  async function runCompare(l = left, r = right) {
    // Yapıştırılan yollar: boşluk ve Explorer'ın "Yol olarak kopyala" tırnakları temizlenir.
    const clean = (p: string) => p.trim().replace(/^"(.*)"$/, "$1");
    l = clean(l);
    r = clean(r);
    setLeft(l);
    setRight(r);
    if (!l || !r) {
      setError("Karşılaştırma için sol ve sağ yol zorunlu.");
      return;
    }
    setLoading(true);
    setError("");
    setGitSession(null);
    setCompareResult(null);
    setFileContent(null);
    setThreeWay(null);
    setSelectedFile(null);
    setCompareProgress(null);
    try {
      const data = await window.electronAPI.comparePaths(l, r);
      setCompareResult(data);
      const s = await window.electronAPI.getSettings();
      setRecentPairs(s.recentPairs ?? []);
      if (data.mode === "file") {
        await loadFilePair(undefined, l, r);
      } else {
        const first =
          data.entries.find((e) => e.status === "different") ??
          data.entries.find((e) => e.status !== "identical");
        if (first) {
          setSelectedFile(first.relativePath);
          await loadFilePair(first.relativePath, l, r);
        }
      }
      setToast("Karşılaştırma yenilendi (F5)");
    } catch (e) {
      setError(errorText(e));
    } finally {
      setLoading(false);
      setCompareProgress(null);
    }
  }

  async function handleSelectFile(relativePath: string) {
    setSelectedFile(relativePath);
    if (viewMode === "three-way" && base) await loadThreeWay(relativePath);
    else await loadFilePair(relativePath);
  }

  async function handleMerge(direction: MergeDirection) {
    setError("");
    try {
      const rel = folderMode ? selectedFile ?? undefined : undefined;
      const result = await window.electronAPI.mergeFile({ left, right, relativePath: rel, direction });
      setToast(
        result.backupPath ? `Birleştirildi. Yedek: ${result.backupPath}` : "Birleştirildi."
      );
      await loadFilePair(rel);
      if (folderMode) setCompareResult(await window.electronAPI.comparePaths(left, right));
    } catch (e) {
      setError(errorText(e));
    }
  }

  async function handleExportPatch() {
    if (!fileContent || fileContent.binary) return;
    const name = selectedFile ?? basename(fileContent.rightPath) ?? "diff.patch";
    const savePath = await window.electronAPI.savePatch(name.replace(/[^\w.-]/g, "_") + ".patch");
    if (!savePath) return;
    try {
      await window.electronAPI.exportPatch({
        fileName: name,
        left: fileContent.left,
        right: fileContent.right,
        savePath,
      });
      setToast(`Patch kaydedildi: ${savePath}`);
    } catch (e) {
      setError(errorText(e));
    }
  }

  async function handleGitImport(text: string) {
    try {
      const files = await window.electronAPI.parseGitDiff(text);
      if (files.length === 0) throw new Error("Geçerli diff bulunamadı");
      setError("");
      setGitSession({ source: "git", files, activeIndex: 0 });
      setCompareResult(null);
      applyGitFile(files[0]);
    } catch (e) {
      setError(errorText(e));
    }
  }

  async function handleThreeWaySave(merged: string, resolutions: Record<number, ConflictResolution>) {
    if (!threeWay) return;
    const out = await window.electronAPI.saveMerged(basename(threeWay.rightPath) || "merged.txt");
    if (!out) return;
    try {
      const result =
        threeWay.merge.conflicts.length === 0
          ? await window.electronAPI.writeTextFile(out, merged)
          : await window.electronAPI.mergeThreeWay({
              outputPath: out,
              base: threeWay.base,
              left: threeWay.left,
              right: threeWay.right,
              resolutions,
            });
      setToast(
        `Kaydedildi: ${result.outputPath}` + (result.backupPath ? ` (yedek: ${result.backupPath})` : "")
      );
    } catch (e) {
      setError(errorText(e));
    }
  }

  const handleDrop = async (e: DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const files = e.dataTransfer?.files;
    if (!files?.length) return;
    try {
      const paths: string[] = [];
      for (let i = 0; i < Math.min(files.length, 2); i++) {
        paths.push(await window.electronAPI.getPathForFile(files[i]));
      }
      if (paths[0]) setLeft(paths[0]);
      if (paths[1]) setRight(paths[1]);
    } catch (err) {
      setError(errorText(err));
    }
  };

  // Birleştirme = kaynağı hedefe kopyalama; binary ve tek tarafta olan dosyalar da kopyalanabilir.
  // Tek taraftaysa yalnızca var olan taraftan diğerine yön sunulur.
  const canMerge =
    !!fileContent && !gitSession && (compareResult?.mode === "file" || !!selectedFile);
  const mergeDirections: MergeDirection[] = !canMerge
    ? []
    : fileContent.missingSide === "right"
      ? ["left-to-right"]
      : fileContent.missingSide === "left"
        ? ["right-to-left"]
        : ["left-to-right", "right-to-left"];

  const canPatch = !!fileContent && !fileContent.binary && !fileContent.missingSide;

  const paneTitle =
    selectedFile ?? (compareResult?.mode === "file" ? basename(left) : fileContent?.leftPath);

  const diffViewMode =
    viewMode === "hex" ? "hex" : viewMode === "inline" ? "inline" : "side-by-side";

  useKeyboard({
    onCompare: () => runCompare(),
    onHelp: () => setHelpOpen(true),
    onSettings: () => setSettingsOpen(true),
    // Esc odak nerede olursa olsun açık diyaloğu kapatır.
    onEscape: () => {
      setHelpOpen(false);
      setSettingsOpen(false);
      setGitOpen(false);
    },
  });

  return (
    <div className="app">
      <Toolbar
        left={left}
        right={right}
        onLeftChange={setLeft}
        onRightChange={setRight}
        onPickLeft={() => pickPath("left")}
        onPickRight={() => pickPath("right")}
        onSwap={() => {
          setLeft(right);
          setRight(left);
          setToast("Yollar değiştirildi");
        }}
        onCompare={() => runCompare()}
        onMerge={handleMerge}
        onExportPatch={handleExportPatch}
        onGitImport={() => setGitOpen(true)}
        onToggleSidebar={() => setSidebarOpen((v) => !v)}
        sidebarOpen={sidebarOpen}
        showSidebarToggle={narrow && !!folderResult}
        loading={loading}
        stats={fileContent?.stats ?? null}
        mergeDirections={mergeDirections}
        canPatch={canPatch}
      />
      {error && (
        <div className="error-banner show" role="alert">
          <strong>Hata:</strong> {error}
          <button type="button" className="error-close" aria-label="Hatayı kapat" onClick={() => setError("")}>
            ✕
          </button>
        </div>
      )}
      {compareProgress && compareProgress.total > 0 && (
        <div className="progress-banner" role="progressbar">
          Hash hesaplanıyor: {compareProgress.current} / {compareProgress.total}
          <div
            className="progress-fill"
            style={{ width: `${(100 * compareProgress.current) / compareProgress.total}%` }}
          />
        </div>
      )}
      <div className="main">
        {folderResult && (
          <FolderTree
            entries={folderResult.entries}
            selected={selectedFile}
            open={sidebarOpen}
            onSelect={handleSelectFile}
            onReveal={(rel, side) => {
              const root = side === "left" ? left : right;
              const full = `${root.replace(/\\/g, "/")}/${rel}`.replace(/\/+/g, "/");
              window.electronAPI.showItemInFolder(full);
            }}
          />
        )}
        <section className="diff-area">
          {!showDiff ? (
            <WelcomePane
              dragOver={dragOver}
              recentPairs={recentPairs}
              onDragOver={(e) => {
                e.preventDefault();
                setDragOver(true);
              }}
              onDragLeave={() => setDragOver(false)}
              onDrop={handleDrop}
              onSelectRecent={(l, r) => {
                setLeft(l);
                setRight(r);
                runCompare(l, r);
              }}
            />
          ) : (
            <>
              <ViewTabs
                mode={viewMode}
                threeWayAvailable={threeWayAvailable}
                hexAvailable={hexAvailable}
                onChange={setViewMode}
              />
              {viewMode === "three-way" && threeWay ? (
                // key: başka dosya seçilince çözüm/önizleme state'i sıfırlansın (yoksa eski dosyanın içeriği kaydedilir).
                <ThreeWayPane key={threeWay.basePath} data={threeWay} onSave={handleThreeWaySave} />
              ) : (
                <DiffPane
                  content={fileContent}
                  loading={loadingFile}
                  viewMode={diffViewMode}
                  paneTitle={paneTitle}
                  theme={theme}
                />
              )}
            </>
          )}
        </section>
      </div>
      {showDiff && (
        <footer className="status-bar">
          <span className="status-item">
            {selectedFile ?? (compareResult?.mode === "file" ? basename(left) : "Hazır")}
          </span>
          {folderResult && (
            <span className="status-item">
              Sol: {folderResult.leftCount} · Sağ: {folderResult.rightCount}
            </span>
          )}
          {folderResult?.truncated && (
            <span className="status-item" role="alert">
              Dosya sınırına (8000) ulaşıldı: liste eksik, alt klasör seçerek daraltın
            </span>
          )}
          {fileContent?.truncated && <span className="status-item">Metin 4 MB ile sınırlandı</span>}
          {gitSession && gitSession.files.length > 1 && (
            <span className="status-item git-nav">
              Git {gitSession.activeIndex + 1}/{gitSession.files.length}
              <button
                type="button"
                className="status-btn"
                aria-label="Önceki git dosyası"
                disabled={gitSession.activeIndex === 0}
                onClick={() => {
                  const idx = gitSession.activeIndex - 1;
                  setGitSession({ ...gitSession, activeIndex: idx });
                  applyGitFile(gitSession.files[idx]);
                }}
              >
                ←
              </button>
              <button
                type="button"
                className="status-btn"
                aria-label="Sonraki git dosyası"
                disabled={gitSession.activeIndex >= gitSession.files.length - 1}
                onClick={() => {
                  const idx = gitSession.activeIndex + 1;
                  setGitSession({ ...gitSession, activeIndex: idx });
                  applyGitFile(gitSession.files[idx]);
                }}
              >
                →
              </button>
            </span>
          )}
          <div className="status-right">
            <span className="status-kbd">F5 yenile</span>
            <span className="status-kbd">Ctrl+, ayarlar</span>
          </div>
        </footer>
      )}
      {toast && <Toast message={toast} onDone={() => setToast("")} />}
      <GitDiffDialog open={gitOpen} onClose={() => setGitOpen(false)} onImport={handleGitImport} />
      <SettingsDialog
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        onSaved={(s) => {
          setViewMode(s.defaultViewMode);
          setRecentPairs(s.recentPairs ?? []);
          setBase(s.lastBasePath);
          setTheme(s.theme);
        }}
        onSelectRecent={(l, r) => {
          setLeft(l);
          setRight(r);
          runCompare(l, r);
        }}
      />
      <HelpDialog open={helpOpen} onClose={() => setHelpOpen(false)} />
    </div>
  );
}
