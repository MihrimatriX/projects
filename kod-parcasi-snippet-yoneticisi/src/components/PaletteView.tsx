import { useCallback, useEffect, useRef, useState } from "react";
import type { Snippet } from "../types";
import { codePreview } from "../lib/format";
import { useToast } from "../hooks/useToast";
import { IconLru, IconSearch } from "./Icons";
import { LangBadge } from "./LangBadge";
import { Toast } from "./Toast";

export function PaletteView() {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<Snippet[]>([]);
  const [recentIds, setRecentIds] = useState<Set<string>>(new Set());
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [loading, setLoading] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const toast = useToast();
  // Ekrandaki sonuçların hangi sorguya ait olduğu: hızlı yazıp Enter'a basınca eski sonuç kopyalanmasın.
  const queryRef = useRef("");
  const itemsQueryRef = useRef<string | null>(null);
  queryRef.current = query;

  const refresh = useCallback(async (q: string): Promise<Snippet[]> => {
    setLoading(true);
    try {
      const [list, recent] = await Promise.all([
        q.trim() ? window.electronAPI.searchSnippets(q) : window.electronAPI.getRecentSnippets(20),
        window.electronAPI.getRecentSnippets(20),
      ]);
      if (q === queryRef.current) {
        itemsQueryRef.current = q;
        setItems(list);
        setRecentIds(new Set(recent.map((s) => s.id)));
        setSelectedIndex(0);
      }
      return list;
    } finally {
      setLoading(false);
    }
  }, []);

  /** Bekleyen (debounce) arama varsa önce onu tamamlar; güncel sorgunun seçili sonucunu döner. */
  async function currentItem(index = selectedIndex): Promise<Snippet | undefined> {
    if (itemsQueryRef.current !== query) {
      clearTimeout(debounceRef.current);
      return (await refresh(query))[0];
    }
    return items[index];
  }

  useEffect(() => {
    clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => refresh(query), query.trim() ? 180 : 0);
    return () => clearTimeout(debounceRef.current);
  }, [query, refresh]);

  useEffect(() => {
    inputRef.current?.focus();
    return window.electronAPI.onPaletteFocus(() => {
      inputRef.current?.focus();
      inputRef.current?.select();
    });
  }, []);

  async function copySelected(index?: number) {
    const item = await currentItem(index);
    if (!item) return;
    await window.electronAPI.copySnippet(item.id);
    toast.show("Panoya kopyalandı");
    setTimeout(() => window.electronAPI.hidePalette(), 400);
  }

  async function editSelected() {
    const item = await currentItem();
    if (!item) return;
    await window.electronAPI.editSnippet(item.id);
    await window.electronAPI.hidePalette();
  }

  /** Sonuç yoksa: aranan metin başlıkla yeni snippet açılır ve ana pencerede düzenlenir. */
  async function createFromQuery() {
    const created = await window.electronAPI.createSnippet({
      title: query.trim(),
      language: "text",
      code: "",
      tags: [],
    });
    await window.electronAPI.editSnippet(created.id);
    await window.electronAPI.hidePalette();
    setQuery("");
  }

  function onKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Escape") {
      e.preventDefault();
      window.electronAPI.hidePalette();
    } else if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelectedIndex((i) => Math.min(i + 1, items.length - 1));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelectedIndex((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (e.ctrlKey) void editSelected();
      else void copySelected();
    }
  }

  const isEmpty = items.length === 0 && query.trim().length > 0;

  return (
    <div className="palette-shell" onKeyDown={onKeyDown}>
      <div className="palette-drag" aria-hidden="true" />
      <div className="palette" role="dialog" aria-modal="true" aria-label="Global arama paleti">
        <div className="palette-input-wrap">
          <IconSearch size={20} />
          <input
            ref={inputRef}
            className="palette-input"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Snippet ara…"
            aria-label="Palet araması"
            aria-controls="palette-results palette-empty"
          />
          <span className={`palette-spinner${loading ? " visible" : ""}`} aria-hidden="true" />
        </div>
        <p className="sr-only">Yukarı ve aşağı oklarla gezinin. Enter kopyalar, Ctrl+Enter düzenler, Escape kapatır.</p>

        {!isEmpty && (
          <div className="palette-results" id="palette-results" role="listbox" aria-label="Arama sonuçları">
            {items.map((s, i) => (
              <button
                key={s.id}
                type="button"
                role="option"
                aria-selected={i === selectedIndex}
                className={`palette-row${i === selectedIndex ? " selected" : ""}`}
                onMouseEnter={() => setSelectedIndex(i)}
                onClick={() => {
                  setSelectedIndex(i);
                  void copySelected(i);
                }}
              >
                <div className="palette-row-top">
                  {recentIds.has(s.id) ? <IconLru /> : <span className="lru-spacer" aria-hidden="true" />}
                  <span className="snippet-title">{s.title}</span>
                  <LangBadge language={s.language} />
                </div>
                <span className="palette-code">{codePreview(s.code)}</span>
              </button>
            ))}
          </div>
        )}

        {isEmpty && (
          <div className="empty show" id="palette-empty">
            <p>Sonuç yok</p>
            <button type="button" onClick={() => void createFromQuery()}>
              “{query.trim()}” adıyla yeni snippet oluştur
            </button>
          </div>
        )}

        <div className="palette-footer">
          <span>
            <kbd>↵</kbd> Kopyala
          </span>
          <span>
            <kbd>Ctrl</kbd>+<kbd>↵</kbd> Düzenle
          </span>
          <span>
            <kbd>Esc</kbd> Kapat
          </span>
        </div>
      </div>
      <Toast message={toast.message} visible={toast.visible} />
    </div>
  );
}