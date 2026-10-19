import Link from "next/link";
import type { ClipSummary } from "@/types/clip";
import { formatRelativeDate } from "@/lib/format";

type Props = {
  clip: ClipSummary;
  selected?: boolean;
};

export default function ClipCard({ clip, selected }: Props) {
  const excerpt = clip.excerpt?.trim();

  return (
    <Link
      href={`/read/${clip.id}`}
      className={`article-card ${!clip.isRead ? "unread" : ""} ${selected ? "selected" : ""}`}
    >
      <div className="article-cover">
        <span className="article-cover-domain">{clip.domain ?? "web"}</span>
      </div>
      <div className="article-body">
        <h2 className="article-title">{clip.title}</h2>
        <p className={`article-excerpt ${!excerpt ? "muted" : ""}`}>
          {excerpt || "Özet yok"}
        </p>
        <div className="article-footer">
          <span className="article-date">{formatRelativeDate(clip.createdAt)}</span>
          {clip.tags.length > 0 && (
            <div className="article-tags">
              {clip.tags.slice(0, 2).map((t) => (
                <span key={t.id} className="article-tag">
                  {t.name}
                </span>
              ))}
            </div>
          )}
        </div>
      </div>
    </Link>
  );
}
