"use client";

import Link from "next/link";
import { useFeedStore } from "@/lib/store";
import { filterLabel, formatSyncTime } from "@/lib/format";
import RelativeTime from "@/components/RelativeTime";
import { matchesSearch } from "@/lib/feed-items";
import { markAllAsRead } from "@/app/actions";

interface ArticleListProps {
  onRefresh: () => void;
  /** Yerel veriyi (ag istegi olmadan) yeniden yukler */
  onReload: () => void;
}

export default function ArticleList({ onRefresh, onReload }: ArticleListProps) {
  const {
    articles,
    selectedArticle,
    setSelectedArticle,
    activeFilter,
    feeds,
    isLoading,
    isRefreshing,
    searchTerm,
    setSearchTerm,
  } = useFeedStore();

  const filtered = articles.filter((a) => matchesSearch(a, searchTerm));

  const handleMarkAllRead = async () => {
    const res = await markAllAsRead(activeFilter);
    useFeedStore
      .getState()
      .showToast(res.success ? `${res.count} makale okundu işaretlendi` : "İşaretlenemedi");
    onReload();
  };

  const unread = articles.filter((a) => !a.isRead).length;
  const activeFeed = activeFilter.feedId
    ? feeds.find((f) => f.id === activeFilter.feedId)
    : null;
  const syncLabel = activeFeed ? formatSyncTime(activeFeed.lastFetchedAt) : null;
  const showAllRead =
    !searchTerm &&
    articles.length > 0 &&
    unread === 0 &&
    activeFilter.status !== "starred";

  const metaParts: string[] = [];
  if (searchTerm) metaParts.push(`${filtered.length} sonuç`);
  else {
    metaParts.push(`${articles.length} makale`, `${unread} okunmamış`);
    if (syncLabel) metaParts.push(`senkron ${syncLabel}`);
  }

  return (
    <section className="article-list" aria-label="Makale listesi">
      <div className="list-header">
        <div className="list-header-top">
          <span className="list-feed-name">{filterLabel(activeFilter, feeds)}</span>
          <span className="list-feed-meta">{metaParts.join(", ")}</span>
        </div>
        {showAllRead && (
          <div className="all-read-banner">
            Bu feed&apos;deki tüm makaleler okundu. Yeni içerik için <strong>R</strong> ile yenileyin.
          </div>
        )}
      </div>

      <div className="list-toolbar">
        <input
          type="search"
          className="search-input"
          placeholder="Makale ara… ( / )"
          aria-label="Makale ara"
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
        />
        <button
          type="button"
          className="icon-btn"
          aria-label="Feed yenile (R)"
          title="Yenile (R)"
          disabled={isRefreshing}
          onClick={onRefresh}
        >
          {isRefreshing ? (
            <span className="spinner" aria-hidden="true" />
          ) : (
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
              <path d="M21 12a9 9 0 1 1-3-6.7" />
              <path d="M21 3v6h-6" />
            </svg>
          )}
        </button>
        <button
          type="button"
          className="icon-btn"
          aria-label="Tümünü okundu işaretle"
          title="Tümünü okundu işaretle"
          disabled={unread === 0}
          onClick={handleMarkAllRead}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
            <path d="M2 12.5 6.5 17 15 8.5" />
            <path d="m10 15.5 1.5 1.5L22 6.5" />
          </svg>
        </button>
        <Link href="/settings" className="icon-btn" aria-label="Ayarlar">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6">
            <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
            <circle cx="12" cy="12" r="3" />
          </svg>
        </Link>
      </div>

      <div className="list-scroll" role="listbox" aria-label="Makaleler">
        {isLoading ? (
          <div className="list-empty">
            <span className="spinner" style={{ margin: "0 auto 12px" }} />
            <p>Yükleniyor…</p>
          </div>
        ) : filtered.length === 0 ? (
          <div className="list-empty">
            <p>
              {searchTerm
                ? "Aramanızla eşleşen makale yok."
                : "Henüz makale yok. Feed yenilendiğinde burada görünecek."}
            </p>
            <button type="button" className="btn-ghost" onClick={() => (searchTerm ? setSearchTerm("") : onRefresh())}>
              {searchTerm ? "Aramayı temizle" : "Yenile"}
            </button>
          </div>
        ) : (
          filtered.map((article) => {
            const selected = selectedArticle?.id === article.id;
            return (
              <button
                key={article.id}
                type="button"
                role="option"
                aria-selected={selected}
                className={`article-row${selected ? " selected" : ""}${article.isRead ? " read" : ""}`}
                onClick={() => {
                  setSelectedArticle(article);
                  if (useFeedStore.getState().layout === "mobile") {
                    useFeedStore.getState().setMobilePanel("reader");
                  }
                }}
              >
                <span className="unread-dot" aria-hidden="true" />
                <div className="article-body">
                  <div className="article-title">{article.title}</div>
                  {article.snippet && <div className="article-excerpt">{article.snippet}</div>}
                  <div className="article-meta">
                    <span>{article.feed?.title ?? "Akış"}</span>
                    <RelativeTime date={article.publishedAt} />
                  </div>
                </div>
                {article.isStarred && (
                  <svg className="star-icon" width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                  </svg>
                )}
              </button>
            );
          })
        )}
      </div>
    </section>
  );
}
