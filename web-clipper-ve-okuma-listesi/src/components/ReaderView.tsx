"use client";

import { useEffect, useState, useCallback } from "react";
import Link from "next/link";
import DOMPurify from "dompurify";
import type { ClipItem } from "@/types/clip";
import { formatRelativeDate } from "@/lib/format";
import HighlightPanel from "@/components/HighlightPanel";
import { IconArchive, IconChevronLeft, IconExternal, IconShield, IconStar, IconTrash } from "@/components/icons";

type Props = {
  clip: ClipItem;
  onToggleStar: () => void;
  onToggleRead: () => void;
  onReparse: () => void;
  onDelete: () => void;
  onAddHighlight: (text: string) => Promise<void>;
  onDeleteHighlight: (id: string) => Promise<void>;
  onUpdateHighlightNote: (id: string, note: string) => Promise<void>;
};

export default function ReaderView({
  clip,
  onToggleStar,
  onToggleRead,
  onReparse,
  onDelete,
  onAddHighlight,
  onDeleteHighlight,
  onUpdateHighlightNote,
}: Props) {
  const [progress, setProgress] = useState(0);
  const [sanitized, setSanitized] = useState("");
  const [fontSize, setFontSize] = useState(18);

  useEffect(() => {
    setSanitized(clip.content ? DOMPurify.sanitize(clip.content) : "");
  }, [clip.content]);

  useEffect(() => {
    function onScroll() {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      setProgress(max > 0 ? Math.min(100, Math.round((window.scrollY / max) * 100)) : 0);
    }
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();
    return () => window.removeEventListener("scroll", onScroll);
  }, [sanitized]);

  const handleSelection = useCallback(async () => {
    const text = window.getSelection()?.toString().trim();
    if (!text || text.length < 3) return;
    await onAddHighlight(text);
    window.getSelection()?.removeAllRanges();
  }, [onAddHighlight]);

  const readMeta = [
    formatRelativeDate(clip.createdAt),
    clip.readingMinutes ? `${clip.readingMinutes} dk okuma` : null,
  ]
    .filter(Boolean)
    .join(" · ");

  return (
    <>
      <div className="progress-bar-top" role="progressbar" aria-valuenow={progress} aria-valuemin={0} aria-valuemax={100}>
        <div style={{ width: `${progress}%` }} />
      </div>

      <header className="reader-header">
        <Link href="/" className="back-btn">
          <IconChevronLeft size={16} />
          Liste
        </Link>
        <div className="reader-toolbar">
          <button type="button" className="font-btn" aria-label="Yazı boyutunu küçült" onClick={() => setFontSize((s) => Math.max(14, s - 2))}>
            A−
          </button>
          <span className="text-xs text-[var(--text-muted)] min-w-[36px] text-center hidden sm:inline">{fontSize}px</span>
          <button type="button" className="font-btn" aria-label="Yazı boyutunu büyüt" onClick={() => setFontSize((s) => Math.min(24, s + 2))}>
            A+
          </button>
          <div className="toolbar-divider" />
          <button type="button" className={`action-btn ${clip.isStarred ? "starred" : ""}`} aria-label="Yıldızla" onClick={onToggleStar}>
            <IconStar size={20} />
          </button>
          <button
            type="button"
            className={`action-btn ${clip.isRead ? "starred" : ""}`}
            aria-label={clip.isRead ? "Okunmadı işaretle" : "Okundu işaretle"}
            aria-pressed={clip.isRead}
            onClick={onToggleRead}
          >
            <IconArchive size={20} />
          </button>
          <button type="button" className="action-btn" aria-label="Kaydı sil" title="Kaydı sil" onClick={onDelete}>
            <IconTrash size={20} />
          </button>
        </div>
      </header>

      <article
        className="reader-article"
        onMouseUp={handleSelection}
        style={{ ["--read-font-size" as string]: `${fontSize}px` }}
      >
        {clip.parseStatus === "failed" && !sanitized ? (
          <div className="text-center py-20">
            <h1 className="text-xl font-semibold mb-2">İçerik ayrıştırılamadı</h1>
            <p className="text-[var(--text-muted)] mb-6">Readability bu sayfadan makale gövdesi çıkaramadı.</p>
            <div className="flex gap-3 justify-center flex-wrap">
              <button type="button" className="btn-primary" onClick={onReparse}>
                Tekrar dene
              </button>
              <a href={clip.url} target="_blank" rel="noopener noreferrer" className="btn-primary">
                Orijinali aç <IconExternal />
              </a>
            </div>
          </div>
        ) : (
          <>
            <div className="reader-domain">{clip.domain ?? "web"}</div>
            <h1 className="reader-title">{clip.title}</h1>
            <div className="reader-meta">{readMeta}</div>

            {clip.parseStatus === "pending" && (
              <p className="text-sm text-[var(--text-muted)] mb-4 font-[family-name:var(--font-ui)]">
                İçerik ayrıştırılıyor…{" "}
                <button type="button" className="text-[var(--accent)] underline cursor-pointer bg-transparent border-0" onClick={onReparse}>
                  Yeniden dene
                </button>
              </p>
            )}

            {sanitized ? (
              <div className="reader-content" dangerouslySetInnerHTML={{ __html: sanitized }} />
            ) : clip.excerpt ? (
              <p className="reader-content text-[var(--text-muted)]">{clip.excerpt}</p>
            ) : null}

            {/* RSS / Omnivore kayıtlarında yalnızca özet vardır: tam metin istenince indirilir */}
            {!sanitized && clip.parseStatus === "done" && (
              <button type="button" className="btn-primary mt-4" onClick={onReparse}>
                Tam metni getir
              </button>
            )}

            <HighlightPanel
              highlights={clip.highlights}
              onDelete={(id) => void onDeleteHighlight(id)}
              onUpdateNote={(id, note) => void onUpdateHighlightNote(id, note)}
            />

            <div className="sanitize-note">
              <IconShield />
              İçerik DOMPurify ile sanitize edildi. Ham HTML render edilmez.
            </div>

            <a href={clip.url} target="_blank" rel="noopener noreferrer" className="original-link">
              Orijinal makaleyi aç <IconExternal size={14} />
            </a>
          </>
        )}
      </article>
    </>
  );
}
