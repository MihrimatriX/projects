"use client";

import { useEffect, useState } from "react";
import DOMPurify from "dompurify";
import { useFeedStore } from "@/lib/store";
import { toggleArticleRead, toggleArticleStarred } from "@/app/actions";
import { hostFromUrl, readingMinutes } from "@/lib/format";
import RelativeTime from "@/components/RelativeTime";

export default function ArticleReader() {
  const { selectedArticle, toggleReadLocal, toggleStarLocal, setMobilePanel } = useFeedStore();
  const [html, setHtml] = useState("");

  useEffect(() => {
    if (!selectedArticle) {
      setHtml("");
      return;
    }
    // Feed içeriği güvenilmez HTML'dir; DOMPurify ile temizlenmeden innerHTML'e verilmez
    const raw = selectedArticle.content || selectedArticle.snippet || "";
    setHtml(typeof window !== "undefined" ? DOMPurify.sanitize(raw) : raw);
  }, [selectedArticle]);

  const handleToggleRead = async () => {
    if (!selectedArticle) return;
    toggleReadLocal(selectedArticle.id);
    await toggleArticleRead(selectedArticle.id, !selectedArticle.isRead);
    useFeedStore.getState().showToast(selectedArticle.isRead ? "Okunmadı" : "Okundu");
  };

  const handleToggleStar = async () => {
    if (!selectedArticle) return;
    toggleStarLocal(selectedArticle.id);
    await toggleArticleStarred(selectedArticle.id, !selectedArticle.isStarred);
    useFeedStore.getState().showToast(selectedArticle.isStarred ? "Yıldız kaldırıldı" : "Yıldızlandı");
  };

  return (
    <main className="reader" aria-label="Okuyucu">
      <div className="reader-toolbar">
        <button
          type="button"
          className="btn-ghost mobile-back-btn"
          onClick={() => setMobilePanel("list")}
        >
          ← Liste
        </button>
        <div className="reader-actions">
          <button
            type="button"
            className={`icon-btn${selectedArticle?.isStarred ? " starred" : ""}`}
            aria-label="Yıldızla (S)"
            aria-pressed={selectedArticle?.isStarred ?? false}
            title="Yıldız (S)"
            disabled={!selectedArticle}
            onClick={handleToggleStar}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill={selectedArticle?.isStarred ? "currentColor" : "none"} stroke="currentColor" strokeWidth="1.6">
              <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
            </svg>
          </button>
          <button
            type="button"
            className={`icon-btn${selectedArticle?.isRead ? " read-toggle" : ""}`}
            aria-label="Okundu işaretle (M)"
            aria-pressed={selectedArticle?.isRead ?? false}
            title="Okundu (M)"
            disabled={!selectedArticle}
            onClick={handleToggleRead}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
              <path d="M20 6 9 17l-5-5" />
            </svg>
          </button>
          <button
            type="button"
            className="btn-primary"
            disabled={!selectedArticle?.link}
            onClick={() => selectedArticle?.link && window.open(selectedArticle.link, "_blank", "noopener,noreferrer")}
          >
            Orijinal (O)
          </button>
        </div>
      </div>

      <div className="reader-content" id="reader-content" tabIndex={-1}>
        {!selectedArticle ? (
          <div className="reader-empty reader-inner">
            <strong>Makale seçin</strong>
            <span>Listeden bir başlık seçin veya J/K ile gezinin.</span>
          </div>
        ) : (
          <div className="reader-inner">
            <h1>{selectedArticle.title}</h1>
            <div className="reader-meta">
              <a href={selectedArticle.link} target="_blank" rel="noopener noreferrer">
                {hostFromUrl(selectedArticle.link) || selectedArticle.feed?.title}
              </a>
              <RelativeTime date={selectedArticle.publishedAt} />
              <span>{readingMinutes(html)} dk okuma</span>
            </div>
            <div className="reader-prose" dangerouslySetInnerHTML={{ __html: html || "<p>Özet mevcut değil.</p>" }} />
          </div>
        )}
      </div>
    </main>
  );
}
