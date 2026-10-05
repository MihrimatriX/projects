"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import AppShell, { filterTitle } from "@/components/AppShell";
import ClipGrid from "@/components/ClipGrid";
import KeyboardManager from "@/components/KeyboardManager";
import KbdToast from "@/components/KbdToast";
import { IconMenu, IconSearch, IconUpload } from "@/components/icons";
import { useClipStore } from "@/lib/store";

export default function Home() {
  const {
    clips,
    tags,
    activeFilter,
    activeTag,
    searchQuery,
    selectedClipId,
    isLoading,
    setClips,
    setTags,
    setActiveFilter,
    setActiveTag,
    setSearchQuery,
    setSelectedClipId,
    setIsLoading,
  } = useClipStore();

  const [counts, setCounts] = useState({ all: 0, unread: 0, starred: 0 });
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    setIsLoading(true);
    const params = new URLSearchParams();
    if (activeFilter !== "all") params.set("filter", activeFilter);
    if (activeTag) params.set("tag", activeTag);
    if (searchQuery.trim()) params.set("q", searchQuery.trim());
    params.set("limit", "500");

    try {
      const responses = await Promise.all([
        fetch(`/api/clips?${params}`),
        fetch("/api/tags"),
        fetch("/api/stats"),
      ]);
      if (responses.some((r) => !r.ok)) throw new Error();
      const [clipsData, tagsData, statsData] = await Promise.all(responses.map((r) => r.json()));
      const list = clipsData.clips ?? [];
      setClips(list);
      setTags(tagsData.tags ?? []);
      setCounts(statsData);
      const current = useClipStore.getState().selectedClipId;
      if (!current && list[0]?.id) setSelectedClipId(list[0].id);
    } catch {
      setToast("Okuma listesi yüklenemedi");
    } finally {
      setIsLoading(false);
    }
  }, [activeFilter, activeTag, searchQuery, setClips, setTags, setIsLoading, setSelectedClipId]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) {
        if (e.key === "Escape") (e.target as HTMLInputElement).blur();
        return;
      }
      if (e.key === "/") {
        e.preventDefault();
        searchRef.current?.focus();
      }
      if (e.key === "?") {
        setToast("<kbd>J</kbd>/<kbd>K</kbd> gezin · <kbd>O</kbd> oku · <kbd>/</kbd> ara");
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  return (
    <AppShell
      activeFilter={activeFilter}
      activeTag={activeTag}
      tags={tags}
      counts={counts}
      onFilter={setActiveFilter}
      onTag={setActiveTag}
      sidebarOpen={sidebarOpen}
      onSidebarOpen={setSidebarOpen}
    >
      <KeyboardManager onToast={setToast} />

      <header className="topbar">
        <button
          type="button"
          className="menu-btn"
          aria-label="Menüyü aç"
          onClick={() => setSidebarOpen(true)}
        >
          <IconMenu />
        </button>

        <div className="search-wrap">
          <IconSearch size={18} />
          <input
            ref={searchRef}
            type="search"
            className="search-input"
            placeholder="Makale ara… (/)"
            aria-label="Makale ara"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
          />
        </div>

        <div className="topbar-actions">
          <Link href="/import" className="btn-icon" aria-label="İçe aktar">
            <IconUpload />
          </Link>
        </div>
      </header>

      <div className="content">
        <div className="content-header">
          <h1 className="content-title">{filterTitle(activeFilter, activeTag)}</h1>
          <span className="content-meta">{clips.length} makale</span>
        </div>

        {tags.length > 0 && (
          <div className="mobile-tags">
            {tags.map((t) => (
              <button
                key={t.id}
                type="button"
                className={`tag-chip ${activeTag === t.name ? "active" : ""}`}
                onClick={() => setActiveTag(activeTag === t.name ? null : t.name)}
              >
                {t.name}
              </button>
            ))}
          </div>
        )}

        {isLoading ? (
          <p className="text-[var(--text-muted)] text-sm">Yükleniyor…</p>
        ) : clips.length === 0 ? (
          <p className="text-center py-16 text-[var(--text-muted)]">
            Sonuç yok — Chrome eklentisi ile kaydedin veya{" "}
            <Link href="/import" className="text-[var(--accent)]">
              içe aktarın
            </Link>
            .
          </p>
        ) : (
          <ClipGrid clips={clips} selectedId={selectedClipId} />
        )}
      </div>

      <KbdToast message={toast} />
    </AppShell>
  );
}
