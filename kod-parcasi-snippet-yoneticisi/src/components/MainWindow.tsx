import { useEffect, useMemo, useRef, useState } from "react";
import type { Snippet } from "../types";
import {
  codePreview,
  collectFolders,
  collectTags,
  formatRelativeDate,
  matchesQuery,
  parseTags,
  tagsToInput,
} from "../lib/format";
import { useToast } from "../hooks/useToast";
import { IconFolder, IconSearch } from "./Icons";
import { LangBadge } from "./LangBadge";
import { Toast } from "./Toast";

type Props = {
  refreshToken?: number;
  onOpenImportExport: () => void;
};

export function MainWindow({ refreshToken = 0, onOpenImportExport }: Props) {
  const [snippets, setSnippets] = useState<Snippet[]>([]);
  // Paletten "düzenle" ile yeni açılan pencere, seçilecek snippet'i ?select= sorgusuyla alır.
  const [selectedId, setSelectedId] = useState<string | null>(() =>
    new URLSearchParams(window.location.search).get("select")
  );
  const [activeFolder, setActiveFolder] = useState<string>("all");
  const [activeTag, setActiveTag] = useState<string>("all");
  const [query, setQuery] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [language, setLanguage] = useState("javascript");
  const [folder, setFolder] = useState("");
  const [tagsInput, setTagsInput] = useState("");
  const [code, setCode] = useState("");
  const [dirty, setDirty] = useState(false);
  // Paletten gelen IPC dinleyicisi tek sefer kurulur; güncel dirty değerini ref'ten okur.
  const dirtyRef = useRef(false);
  dirtyRef.current = dirty;
  const toast = useToast();
  const searchRef = useRef<HTMLInputElement>(null);
  const [hotkeyOk, setHotkeyOk] = useState(true);

  const selected = snippets.find((s) => s.id === selectedId) ?? null;
  const folders = useMemo(() => collectFolders(snippets), [snippets]);
  const allTags = useMemo(() => collectTags(snippets), [snippets]);

  const filtered = useMemo(() => {
    return snippets.filter((s) => {
      if (activeFolder !== "all" && s.folder !== activeFolder) return false;
      if (activeTag !== "all" && !s.tags.includes(activeTag)) return false;
      return matchesQuery(s, query);
    });
  }, [snippets, activeFolder, activeTag, query]);

  /** Kaydedilmemiş değişiklik varsa kullanıcıya sorar; true ise devam edilebilir. */
  function confirmDiscard() {
    return !dirtyRef.current || window.confirm("Kaydedilmemiş değişiklikler kaybolacak. Devam edilsin mi?");
  }

  function select(id: string) {
    if (id === selectedId || !confirmDiscard()) return;
    setSelectedId(id);
    setDirty(false);
  }

  async function refresh() {
    setSnippets(await window.electronAPI.getSnippets());
  }

  useEffect(() => {
    void refresh();
  }, [refreshToken]);

  useEffect(() => {
    void window.electronAPI.hotkeyOk().then(setHotkeyOk);
    return window.electronAPI.onSelectSnippet((id) => {
      if (!confirmDiscard()) return;
      // Paletten yeni oluşturulan snippet listede henüz yok: önce listeyi tazele.
      void refresh().then(() => {
        setSelectedId(id);
        setDirty(false);
      });
    });
  }, []);

  useEffect(() => {
    if (!selected) return;
    setTitle(selected.title);
    setDescription(selected.description ?? "");
    setLanguage(selected.language);
    setFolder(selected.folder ?? "");
    setTagsInput(tagsToInput(selected.tags));
    setCode(selected.code);
    setDirty(false);
  }, [selected?.id]);

  function markDirty() {
    setDirty(true);
  }

  async function createNew() {
    if (!confirmDiscard()) return;
    const created = await window.electronAPI.createSnippet({
      title: "Yeni snippet",
      description: "",
      language: "javascript",
      folder: "",
      code: "// kodunuz...\n",
      tags: [],
    });
    await refresh();
    setSelectedId(created.id);
    setDirty(true);
  }

  async function saveCurrent() {
    if (!selectedId) return;
    await window.electronAPI.updateSnippet(selectedId, {
      title,
      description,
      language,
      folder: folder.trim(),
      code,
      tags: parseTags(tagsInput),
    });
    setDirty(false);
    toast.show("Kaydedildi");
    await refresh();
  }

  /** Formdaki (kaydedilmemiş olabilir) hâliyle yeni bir kopya oluşturur; asıl snippet değişmez. */
  async function duplicateCurrent() {
    if (!selectedId) return;
    const created = await window.electronAPI.createSnippet({
      title: `${title.trim() || "Başlıksız"} (kopya)`,
      description,
      language,
      folder: folder.trim(),
      code,
      tags: parseTags(tagsInput),
    });
    await refresh();
    setSelectedId(created.id);
    setDirty(false);
    toast.show("Kopya oluşturuldu");
  }

  async function removeCurrent() {
    if (!selectedId) return;
    if (!window.confirm(`"${title || "Başlıksız"}" kalıcı olarak silinsin mi?`)) return;
    await window.electronAPI.deleteSnippet(selectedId);
    setSelectedId(null);
    await refresh();
    toast.show("Silindi");
  }

  async function copyCurrent() {
    if (!selectedId) return;
    await window.electronAPI.copySnippet(selectedId);
    toast.show("Panoya kopyalandı");
  }

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.ctrlKey && e.key.toLowerCase() === "s") {
        e.preventDefault();
        if (dirty && selectedId) void saveCurrent();
      }
      if (e.ctrlKey && e.key.toLowerCase() === "e") {
        e.preventDefault();
        onOpenImportExport();
      }
      if (e.ctrlKey && e.key.toLowerCase() === "n") {
        e.preventDefault();
        void createNew();
      }
      if (e.ctrlKey && e.key.toLowerCase() === "f") {
        e.preventDefault();
        searchRef.current?.focus();
        searchRef.current?.select();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  /** Liste klavyeyle gezilir: Yukarı/Aşağı/Home/End seçimi değiştirir. */
  function onListKey(e: React.KeyboardEvent) {
    if (!filtered.length || !["ArrowDown", "ArrowUp", "Home", "End"].includes(e.key)) return;
    e.preventDefault();
    const cur = filtered.findIndex((s) => s.id === selectedId);
    const next =
      e.key === "Home" ? 0
      : e.key === "End" ? filtered.length - 1
      : e.key === "ArrowDown" ? Math.min(cur + 1, filtered.length - 1)
      : Math.max(cur - 1, 0);
    select(filtered[next].id);
    (e.currentTarget.querySelectorAll("[role=option]")[next] as HTMLElement | undefined)?.focus();
  }

  const showEmpty = snippets.length === 0;

  return (
    <div className="app-shell">
      <header className="window-chrome">
        <div className="titlebar">
          <img className="titlebar-icon" src="./icon.png" alt="" width={16} height={16} />
          <span className="titlebar-title">Kod Snippet Yöneticisi</span>
        </div>
        <div className="toolbar">
          <label className="toolbar-search" title="Uygulama dışından arama paleti: Alt+Shift+S">
            <IconSearch />
            <input
              ref={searchRef}
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Snippet ara…"
              aria-label="Snippet ara"
            />
            <kbd
              className={hotkeyOk ? undefined : "kbd-warn"}
              title={hotkeyOk ? "Global arama paleti" : "Alt+Shift+S başka bir uygulama tarafından kullanılıyor; paleti düğmeyle açın"}
            >
              Alt+Shift+S{hotkeyOk ? "" : " ⚠"}
            </kbd>
          </label>
          <button type="button" className="btn-ghost" onClick={() => void window.electronAPI.showPalette()}>
            Palet
          </button>
          <button type="button" className="btn-primary" onClick={() => void createNew()}>
            Yeni snippet
          </button>
          <button type="button" className="btn-ghost toolbar-extra" onClick={onOpenImportExport}>
            Import / Export
          </button>
        </div>
      </header>

      {showEmpty ? (
        <div className="empty-state show">
          <p className="empty-state__title">İlk snippet&apos;inizi oluşturun</p>
          <p className="empty-state__desc">Boş snippet ile başlayın veya JSON dosyasından içe aktarın.</p>
          <button type="button" className="btn-primary" onClick={() => void createNew()}>
            Boş snippet
          </button>
        </div>
      ) : (
        <div className="split">
          <aside className="sidebar">
            {folders.length > 0 && (
              <div className="sidebar-section">
                <p className="sidebar-label">Klasörler</p>
                <button
                  type="button"
                  className={`folder-item${activeFolder === "all" ? " active" : ""}`}
                  onClick={() => setActiveFolder("all")}
                >
                  <IconFolder />
                  Tümü
                </button>
                {folders.map((f) => (
                  <button
                    key={f}
                    type="button"
                    className={`folder-item${activeFolder === f ? " active" : ""}`}
                    onClick={() => setActiveFolder(f)}
                  >
                    <IconFolder />
                    {f}
                  </button>
                ))}
              </div>
            )}
            {allTags.length > 0 && (
              <>
                <p className="sidebar-label sidebar-label--tags">Etiketler</p>
                <div className="tag-cloud" role="group" aria-label="Etiket filtresi">
                  <button
                    type="button"
                    className={`tag-chip${activeTag === "all" ? " active" : ""}`}
                    onClick={() => setActiveTag("all")}
                  >
                    Tümü
                  </button>
                  {allTags.map((tag) => (
                    <button
                      key={tag}
                      type="button"
                      className={`tag-chip${activeTag === tag ? " active" : ""}`}
                      onClick={() => setActiveTag(tag)}
                    >
                      #{tag}
                    </button>
                  ))}
                </div>
              </>
            )}
          </aside>

          <div className="snippet-list" role="listbox" aria-label="Snippet listesi" tabIndex={0} onKeyDown={onListKey}>
            {filtered.length === 0 && <p className="list-empty">Eşleşen snippet yok</p>}
            {filtered.map((s) => (
              <button
                key={s.id}
                type="button"
                role="option"
                aria-selected={selectedId === s.id}
                className={`snippet-row${selectedId === s.id ? " selected" : ""}`}
                onClick={() => select(s.id)}
              >
                <div className="snippet-row-top">
                  <span className="snippet-title">{s.title}</span>
                  <LangBadge language={s.language} />
                </div>
                <span className="snippet-preview">{codePreview(s.code)}</span>
              </button>
            ))}
          </div>

          <section className="editor-panel" aria-label="Snippet editörü">
            {!selected ? (
              <div className="editor-empty">Bir snippet seçin</div>
            ) : (
              <>
                <div className="editor-header">
                  <div className="editor-title-row">
                    {!dirty ? null : (
                      <span className="dirty-dot" title="Kaydedilmemiş değişiklik" aria-label="Kaydedilmemiş değişiklik" />
                    )}
                    <input
                      className="editor-title"
                      type="text"
                      value={title}
                      onChange={(e) => {
                        setTitle(e.target.value);
                        markDirty();
                      }}
                      aria-label="Snippet başlığı"
                    />
                  </div>
                  <input
                    className="editor-meta-input"
                    type="text"
                    value={tagsInput}
                    onChange={(e) => {
                      setTagsInput(e.target.value);
                      markDirty();
                    }}
                    placeholder="#etiket1, #etiket2"
                    aria-label="Etiketler"
                  />
                  <div className="editor-meta-row">
                    <input
                      className="editor-lang-input"
                      type="text"
                      value={language}
                      onChange={(e) => {
                        setLanguage(e.target.value);
                        markDirty();
                      }}
                      placeholder="Dil"
                      aria-label="Programlama dili"
                    />
                    <input
                      className="editor-folder-input"
                      type="text"
                      value={folder}
                      onChange={(e) => {
                        setFolder(e.target.value);
                        markDirty();
                      }}
                      placeholder="Klasör (isteğe bağlı)"
                      aria-label="Klasör"
                    />
                  </div>
                  <p className="editor-meta">
                    {language.toUpperCase()} · Son düzenleme: {formatRelativeDate(selected.updatedAt)}
                  </p>
                  {description !== undefined && (
                    <input
                      className="editor-desc-input"
                      type="text"
                      value={description}
                      onChange={(e) => {
                        setDescription(e.target.value);
                        markDirty();
                      }}
                      placeholder="Açıklama (isteğe bağlı)"
                      aria-label="Açıklama"
                    />
                  )}
                </div>
                <div className="code-area">
                  <textarea
                    value={code}
                    onChange={(e) => {
                      setCode(e.target.value);
                      markDirty();
                    }}
                    spellCheck={false}
                    placeholder="// kodunuz..."
                    aria-label="Kod alanı"
                  />
                </div>
                <div className="editor-actions">
                  <button type="button" className="btn-primary" onClick={() => void copyCurrent()}>
                    Kopyala
                  </button>
                  <button type="button" className="btn-ghost" disabled={!dirty} onClick={() => void saveCurrent()}>
                    Kaydet
                  </button>
                  <button type="button" className="btn-ghost" onClick={() => void duplicateCurrent()}>
                    Çoğalt
                  </button>
                  <button type="button" className="btn-danger-ghost" onClick={() => void removeCurrent()}>
                    Sil
                  </button>
                </div>
              </>
            )}
          </section>
        </div>
      )}
      <Toast message={toast.message} visible={toast.visible} />
    </div>
  );
}
