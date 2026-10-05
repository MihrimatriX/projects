"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import {
  FETCH_INTERVAL_OPTIONS,
  getFetchIntervalMinutes,
  setFetchIntervalMinutes,
  type FetchIntervalMinutes,
} from "@/lib/fetch-interval";
import { importOpml, exportOpml, refreshFeeds, getFeeds, addFeed, deleteFeed } from "@/app/actions";
import type { FeedItem } from "@/lib/store";
import { importMessage, syncMessage } from "@/lib/format";

const NEW_FOLDER = "__new__";

export default function SettingsPage() {
  const [interval, setInterval] = useState<FetchIntervalMinutes>(15);
  const [lastSync, setLastSync] = useState("—");
  const [unreadTotal, setUnreadTotal] = useState(0);
  const [feeds, setFeeds] = useState<FeedItem[]>([]);
  const [feedUrl, setFeedUrl] = useState("");
  const [feedFolder, setFeedFolder] = useState("Genel");
  const [customFolder, setCustomFolder] = useState("");
  const [addingFeed, setAddingFeed] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 2500);
  };

  const loadMeta = async () => {
    const feedList = await getFeeds();
    setFeeds(feedList);
    const unread = feedList.reduce((n, f) => n + (f._count?.articles ?? 0), 0);
    setUnreadTotal(unread);
    const latest = feedList.reduce<Date | null>((max, f) => {
      const d = new Date(f.lastFetchedAt);
      return !max || d > max ? d : max;
    }, null);
    setLastSync(latest ? formatAgo(latest) : "—");
  };

  useEffect(() => {
    setInterval(getFetchIntervalMinutes());
    loadMeta();
  }, []);

  const handleInterval = (m: FetchIntervalMinutes) => {
    setInterval(m);
    setFetchIntervalMinutes(m);
    window.dispatchEvent(new Event("rss-fetch-interval-changed"));
    showToast(`Eşitleme aralığı: ${m} dakika`);
  };

  const handleSync = async () => {
    setSyncing(true);
    const res = await refreshFeeds();
    await loadMeta();
    setSyncing(false);
    showToast(syncMessage(res));
  };

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const res = await importOpml(await file.text());
    if (res.success) {
      showToast(importMessage(res.count, res.failed));
      loadMeta();
    } else {
      showToast(res.error ?? "OPML hatası");
    }
    e.target.value = "";
  };

  const handleExport = async () => {
    const opml = await exportOpml();
    if (!opml) return;
    const blob = new Blob([opml], { type: "text/xml" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "feeds-export.opml";
    a.click();
    URL.revokeObjectURL(url);
    showToast("feeds-export.opml indirildi");
  };

  const folderOptions = [...new Set(feeds.map((f) => f.folder || "Genel"))];
  if (folderOptions.length === 0) folderOptions.push("Genel");

  const resolvedFolder =
    feedFolder === NEW_FOLDER ? customFolder.trim() || "Genel" : feedFolder;

  const handleAddFeed = async () => {
    const clean = feedUrl.trim();
    if (!clean) {
      showToast("Feed URL gerekli");
      return;
    }
    if (feedFolder === NEW_FOLDER && !customFolder.trim()) {
      showToast("Klasör adı gerekli");
      return;
    }
    setAddingFeed(true);
    const res = await addFeed(clean, resolvedFolder);
    setAddingFeed(false);
    if (res.success) {
      setFeedUrl("");
      setCustomFolder("");
      showToast(`"${res.feed?.title ?? "Feed"}" eklendi`);
      await loadMeta();
    } else {
      showToast(res.error ?? "Feed eklenemedi");
    }
  };

  const handleDeleteFeed = async (id: string, title: string) => {
    if (!confirm(`"${title}" akışını silmek istediğinize emin misiniz?`)) return;
    const res = await deleteFeed(id);
    if (res.success) {
      showToast("Feed silindi");
      await loadMeta();
    } else {
      showToast("Feed silinemedi");
    }
  };

  return (
    <>
      <header className="settings-topbar">
        <Link href="/" className="settings-back">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M19 12H5M12 19l-7-7 7-7" />
          </svg>
          Panele dön
        </Link>
        <h1>Ayarlar</h1>
      </header>

      <div className="settings-layout">
        <section>
          <h2>Eşitleme</h2>
          <div className="settings-row">
            <div className="settings-row-label">
              <strong>Otomatik yenileme aralığı</strong>
              <span>Arka planda feed çekme sıklığı</span>
            </div>
            <select value={interval} onChange={(e) => handleInterval(Number(e.target.value) as FetchIntervalMinutes)}>
              {FETCH_INTERVAL_OPTIONS.map((m) => (
                <option key={m} value={m}>
                  {m} dakika
                </option>
              ))}
            </select>
          </div>
          <div className="settings-row">
            <div className="settings-row-label">
              <strong>Son senkron</strong>
              <span>
                {lastSync} — {unreadTotal} okunmamış makale
              </span>
            </div>
            <button type="button" className="settings-btn settings-btn-primary" disabled={syncing} onClick={handleSync}>
              {syncing ? "Senkronize ediliyor…" : "Şimdi senkronize et"}
            </button>
          </div>
        </section>

        <section>
          <h2>RSS akışları</h2>
          <div className="settings-row settings-row-stack">
            <div className="settings-row-label">
              <strong>Yeni feed ekle</strong>
              <span>Kendi RSS/Atom URL&apos;nizi ekleyin</span>
            </div>
            <input
              type="url"
              className="settings-input"
              placeholder="https://example.com/feed.xml"
              value={feedUrl}
              onChange={(e) => setFeedUrl(e.target.value)}
            />
            <div className="settings-feed-folder-row">
              <select value={feedFolder} onChange={(e) => setFeedFolder(e.target.value)}>
                {folderOptions.map((f) => (
                  <option key={f} value={f}>
                    {f}
                  </option>
                ))}
                <option value={NEW_FOLDER}>+ Yeni klasör…</option>
              </select>
              {feedFolder === NEW_FOLDER && (
                <input
                  type="text"
                  className="settings-input"
                  placeholder="Klasör adı"
                  value={customFolder}
                  onChange={(e) => setCustomFolder(e.target.value)}
                />
              )}
              <button
                type="button"
                className="settings-btn settings-btn-primary"
                disabled={addingFeed}
                onClick={handleAddFeed}
              >
                {addingFeed ? "Ekleniyor…" : "Ekle"}
              </button>
            </div>
          </div>
          {feeds.length === 0 ? (
            <p className="settings-empty">Henüz feed yok.</p>
          ) : (
            <ul className="settings-feed-list">
              {feeds.map((feed) => (
                <li key={feed.id} className="settings-feed-item">
                  <div className="settings-feed-info">
                    <strong>{feed.title}</strong>
                    <span>
                      {feed.folder} · {feed.url}
                    </span>
                    <span>{feed._count?.articles ?? 0} okunmamış</span>
                    {feed.lastError && <span className="settings-feed-error">Son hata: {feed.lastError}</span>}
                  </div>
                  <button
                    type="button"
                    className="settings-btn settings-btn-danger"
                    onClick={() => handleDeleteFeed(feed.id, feed.title)}
                  >
                    Sil
                  </button>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section>
          <h2>OPML</h2>
          <div className="settings-row">
            <div className="settings-row-label">
              <strong>OPML içe aktar</strong>
              <span>Mevcut feed listesine idempotent ekleme</span>
            </div>
            <button type="button" className="settings-btn" onClick={() => fileRef.current?.click()}>
              Dosya seç
            </button>
            <input ref={fileRef} type="file" accept=".opml,.xml" hidden onChange={handleImport} />
          </div>
          <div className="settings-row">
            <div className="settings-row-label">
              <strong>OPML dışa aktar</strong>
              <span>Tüm feed ve klasör yapısını yedekle</span>
            </div>
            <button type="button" className="settings-btn" onClick={handleExport}>
              Dışa aktar
            </button>
          </div>
        </section>

        <section>
          <h2>Self-host</h2>
          <div className="settings-row settings-row-stack">
            <div className="settings-row-label">
              <strong>SQLite veritabanı yolu</strong>
              <span>Yerel dosya — Prisma ile yönetilir</span>
            </div>
            <div className="settings-path">./prisma/dev.db</div>
          </div>
        </section>

        <section>
          <h2>Görünüm</h2>
          <div className="settings-row">
            <div className="settings-row-label">
              <strong>Tema</strong>
              <span>Koyu tema Faz 2&apos;de</span>
            </div>
            <select disabled defaultValue="light">
              <option value="light">Açık (varsayılan)</option>
              <option value="dark">Koyu — yakında</option>
            </select>
          </div>
        </section>
      </div>

      <div className={`toast${toast ? " show" : ""}`}>{toast}</div>
    </>
  );
}

function formatAgo(date: Date): string {
  const mins = Math.floor((Date.now() - date.getTime()) / 60000);
  if (mins < 1) return "Az önce";
  if (mins < 60) return `${mins} dakika önce`;
  const h = Math.floor(mins / 60);
  if (h < 24) return `${h} saat önce`;
  return date.toLocaleString("tr-TR");
}
