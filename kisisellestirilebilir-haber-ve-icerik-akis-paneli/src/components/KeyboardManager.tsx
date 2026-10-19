"use client";

import { useEffect, useRef } from "react";
import { useFeedStore } from "@/lib/store";
import { toggleArticleRead, toggleArticleStarred } from "@/app/actions";
import { persistKbdHidden } from "@/lib/layout-hooks";
import { matchesSearch } from "@/lib/feed-items";

interface KeyboardManagerProps {
  onRefresh: () => void;
}

export default function KeyboardManager({ onRefresh }: KeyboardManagerProps) {
  const searchRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    searchRef.current = document.querySelector<HTMLInputElement>(".search-input");
  });

  useEffect(() => {
    const handleKeyDown = async (e: KeyboardEvent) => {
      const {
        articles,
        selectedArticle,
        setSelectedArticle,
        toggleReadLocal,
        toggleStarLocal,
        feedModalOpen,
        setFeedModalOpen,
        layout,
        setMobilePanel,
        kbdHidden,
        setKbdHidden,
        searchTerm,
        setSearchTerm,
      } = useFeedStore.getState();

      // Ctrl/Alt/Meta kombinasyonları tarayıcıya kalsın (Ctrl+R yenile, Ctrl+S vb.)
      if (e.ctrlKey || e.metaKey || e.altKey) return;

      if (feedModalOpen) {
        if (e.key === "Escape") setFeedModalOpen(false);
        return;
      }

      const el = document.activeElement;
      if (el && (el.tagName === "INPUT" || el.tagName === "TEXTAREA" || el.tagName === "SELECT")) {
        if (e.key === "Escape" && el.classList.contains("search-input")) {
          setSearchTerm("");
        }
        return;
      }

      const filtered = articles.filter((a) => matchesSearch(a, searchTerm));

      if (e.key === "?") {
        e.preventDefault();
        if (layout !== "mobile") {
          const next = !kbdHidden;
          setKbdHidden(next);
          persistKbdHidden(next);
        }
        return;
      }

      const idx = selectedArticle ? filtered.findIndex((a) => a.id === selectedArticle.id) : -1;

      switch (e.key.toLowerCase()) {
        case "j":
          e.preventDefault();
          if (idx < filtered.length - 1) setSelectedArticle(filtered[idx + 1]);
          break;
        case "k":
          e.preventDefault();
          if (idx > 0) setSelectedArticle(filtered[idx - 1]);
          break;
        case "m":
          if (selectedArticle) {
            e.preventDefault();
            toggleReadLocal(selectedArticle.id);
            await toggleArticleRead(selectedArticle.id, !selectedArticle.isRead);
          }
          break;
        case "s":
          if (selectedArticle) {
            e.preventDefault();
            toggleStarLocal(selectedArticle.id);
            await toggleArticleStarred(selectedArticle.id, !selectedArticle.isStarred);
          }
          break;
        case "o":
          if (selectedArticle?.link) {
            e.preventDefault();
            window.open(selectedArticle.link, "_blank", "noopener,noreferrer");
          }
          break;
        case "r":
          e.preventDefault();
          onRefresh();
          break;
        case "/":
          e.preventDefault();
          searchRef.current?.focus();
          break;
        case "escape":
          if (layout === "mobile") setMobilePanel("list");
          break;
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onRefresh]);

  return null;
}
