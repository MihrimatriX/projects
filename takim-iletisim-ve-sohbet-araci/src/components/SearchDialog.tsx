"use client";

import { useEffect, useState } from "react";
import { IconHash } from "@/components/icons";

type SearchResult = {
  id: string;
  content: string;
  author: { name: string };
  channel: { id: string; name: string; type: string };
};

type Props = {
  open: boolean;
  onClose: () => void;
  onSelectChannel: (channelId: string) => void;
};

export function SearchDialog({ open, onClose, onSelectChannel }: Props) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [active, setActive] = useState(0);

  function choose(r: SearchResult) {
    onSelectChannel(r.channel.id);
    onClose();
  }

  function onInputKey(e: React.KeyboardEvent) {
    if (e.key === "ArrowDown" || e.key === "ArrowUp") {
      e.preventDefault();
      if (results.length === 0) return;
      const step = e.key === "ArrowDown" ? 1 : -1;
      setActive((i) => (i + step + results.length) % results.length);
    }
    if (e.key === "Enter" && results[active]) {
      e.preventDefault();
      choose(results[active]);
    }
  }

  useEffect(() => {
    if (!open) {
      setQuery("");
      setResults([]);
    }
  }, [open]);

  useEffect(() => {
    if (!open) return;
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  useEffect(() => {
    if (query.length < 2) {
      setResults([]);
      return;
    }
    const timer = setTimeout(async () => {
      setLoading(true);
      const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
      const data = await res.json();
      setResults(data.results ?? []);
      setActive(0);
      setLoading(false);
    }, 300);
    return () => clearTimeout(timer);
  }, [query]);

  if (!open) return null;

  return (
    <div
      className="modal-overlay"
      role="dialog"
      aria-modal="true"
      aria-label="Hızlı arama"
      onClick={onClose}
    >
      <div className="quick-search" onClick={(e) => e.stopPropagation()}>
        <input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={onInputKey}
          placeholder="Mesajlarda ara… (Ctrl+K)"
          autoComplete="off"
          role="combobox"
          aria-expanded={results.length > 0}
          aria-controls="search-results"
          aria-activedescendant={results[active] ? `search-${results[active].id}` : undefined}
        />
        <ul id="search-results" role="listbox" className="max-h-80 overflow-y-auto scrollbar-thin m-0 p-0">
          {loading && (
            <li style={{ color: "var(--text-muted)", cursor: "default" }}>
              Aranıyor…
            </li>
          )}
          {!loading && query.length >= 2 && results.length === 0 && (
            <li style={{ color: "var(--text-muted)", cursor: "default" }}>
              Sonuç bulunamadı
            </li>
          )}
          {results.map((r, i) => (
            <li
              key={r.id}
              id={`search-${r.id}`}
              role="option"
              aria-selected={i === active}
              onMouseEnter={() => setActive(i)}
              onClick={() => choose(r)}
            >
              <IconHash size={16} />
              <div className="min-w-0">
                <div className="text-xs" style={{ color: "var(--text-muted)" }}>
                  {r.channel.type === "DM" ? "DM" : `#${r.channel.name}`} · {r.author.name}
                </div>
                <div className="text-sm truncate">{r.content}</div>
              </div>
            </li>
          ))}
        </ul>
        <div
          className="px-5 py-2.5 text-xs border-t"
          style={{ color: "var(--text-muted)", borderColor: "var(--border)" }}
        >
          ↑↓ seç · Enter git · Esc kapat
        </div>
      </div>
    </div>
  );
}
