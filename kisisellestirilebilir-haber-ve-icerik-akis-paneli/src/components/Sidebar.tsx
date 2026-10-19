"use client";

import { useRef } from "react";
import { useFeedStore } from "@/lib/store";
import { importOpml, exportOpml } from "@/app/actions";
import { feedColor, feedInitial, importMessage } from "@/lib/format";
import { useWelcomeDismissed } from "@/lib/layout-hooks";

interface SidebarProps {
  onRefresh: () => void;
}

export default function Sidebar({ onRefresh }: SidebarProps) {
  const {
    feeds,
    activeFilter,
    setActiveFilter,
    setFeedModalOpen,
    folderOpen,
    toggleFolder,
  } = useFeedStore();

  const { dismissed, dismiss } = useWelcomeDismissed();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const folders = feeds.reduce<Record<string, typeof feeds>>((acc, feed) => {
    const name = feed.folder || "Genel";
    (acc[name] ??= []).push(feed);
    return acc;
  }, {});

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    const res = await importOpml(text);
    if (res.success) {
      useFeedStore.getState().showToast(importMessage(res.count, res.failed));
      onRefresh();
    } else {
      useFeedStore.getState().showToast(res.error ?? "OPML yüklenemedi");
    }
    e.target.value = "";
  };

  const handleExport = async () => {
    const opml = await exportOpml();
    if (!opml) return;
    const blob = new Blob([opml], { type: "text/xml" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "feeds-export.opml";
    link.click();
    URL.revokeObjectURL(url);
    useFeedStore.getState().showToast("OPML dışa aktarıldı");
  };

  return (
    <aside className="sidebar" aria-label="Feed listesi">
      <div className="sidebar-header">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
          <path d="M4 11a9 9 0 0 1 9 9" />
          <path d="M4 4a16 16 0 0 1 16 16" />
          <circle cx="5" cy="19" r="1" />
        </svg>
        <p className="app-title">Haber Akışı</p>
      </div>

      <div className="sidebar-scroll">
        {!dismissed && (
          <div className="welcome-banner">
            OPML dosyanızı içe aktararak feed listesini taşıyın. <strong>J/K</strong> ile gezin,{" "}
            <strong>M</strong> ile okundu işaretleyin.
            <button type="button" className="welcome-dismiss" onClick={dismiss} aria-label="Banner'ı kapat">
              ×
            </button>
          </div>
        )}

        <div className="filter-row">
          {(
            [
              { status: "unread" as const, label: "Okunmamış" },
              { status: "starred" as const, label: "Yıldızlı" },
              { status: "all" as const, label: "Tümü" },
            ] as const
          ).map(({ status, label }) => (
            <button
              key={status}
              type="button"
              className={`filter-chip${activeFilter.status === status && !activeFilter.feedId && !activeFilter.folder ? " active" : ""}`}
              onClick={() => setActiveFilter({ status })}
            >
              {label}
            </button>
          ))}
        </div>

        {Object.keys(folders).length === 0 ? (
          <p className="list-empty">Henüz feed yok. Alttan ekleyin veya OPML içe aktarın.</p>
        ) : (
          Object.entries(folders).map(([folderName, folderFeeds]) => {
            const open = folderOpen[folderName] !== false;
            return (
              <div key={folderName} className="folder-group" data-open={open ? "true" : "false"}>
                <button
                  type="button"
                  className="folder-toggle"
                  aria-expanded={open}
                  onClick={() => toggleFolder(folderName)}
                >
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="m6 9 6 6 6-6" />
                  </svg>
                  <span className="folder-label">{folderName}</span>
                </button>
                <div className="folder-feeds">
                  {folderFeeds.map((feed) => {
                    const active = activeFilter.feedId === feed.id;
                    const unread = feed._count?.articles ?? 0;
                    return (
                      <button
                        key={feed.id}
                        type="button"
                        className={`feed-row${active ? " active" : ""}`}
                        aria-current={active ? "page" : undefined}
                        onClick={() => {
                          setActiveFilter({ feedId: feed.id, status: "unread" });
                          if (useFeedStore.getState().layout === "mobile") {
                            useFeedStore.getState().setMobilePanel("list");
                          }
                        }}
                      >
                        <div className="favicon-wrap" style={{ background: feedColor(feed.title) }}>
                          {feedInitial(feed.title)}
                        </div>
                        <span className="feed-name">{feed.title}</span>
                        {feed.lastError && (
                          <span className="feed-error" title={feed.lastError} aria-label={`Güncellenemedi: ${feed.lastError}`}>
                            !
                          </span>
                        )}
                        {unread > 0 && <span className="unread-badge">{unread}</span>}
                      </button>
                    );
                  })}
                </div>
              </div>
            );
          })
        )}
      </div>

      <div className="sidebar-footer">
        <button type="button" className="add-feed-btn" onClick={() => setFeedModalOpen(true)}>
          + RSS ekle
        </button>
        <div className="sidebar-actions">
          <input ref={fileInputRef} type="file" accept=".opml,.xml" hidden onChange={handleImport} />
          <button type="button" className="sidebar-link" onClick={() => fileInputRef.current?.click()}>
            OPML içe aktar
          </button>
          <button type="button" className="sidebar-link" onClick={handleExport}>
            OPML dışa aktar
          </button>
        </div>
      </div>
    </aside>
  );
}
