"use client";

import { useEffect, useRef, useState } from "react";
import PageBack from "@/components/PageBack";
import { IconUpload } from "@/components/icons";
import type { FeedItem } from "@/types/clip";

type Tab = "omnivore" | "rss" | "url";

export default function ImportPage() {
  const [tab, setTab] = useState<Tab>("omnivore");
  const [feedUrl, setFeedUrl] = useState("");
  const [feeds, setFeeds] = useState<FeedItem[]>([]);
  const [feedStatus, setFeedStatus] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const [omnivoreStatus, setOmnivoreStatus] = useState<{ type: "success" | "error"; msg: string } | null>(null);
  const [loading, setLoading] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const [manualUrl, setManualUrl] = useState("");
  const [manualStatus, setManualStatus] = useState<{ type: "success" | "error"; msg: string } | null>(null);

  async function loadFeeds() {
    const res = await fetch("/api/feeds").catch(() => null);
    if (res?.ok) setFeeds((await res.json()).feeds ?? []);
  }

  useEffect(() => {
    loadFeeds();
  }, []);

  async function importFeed(e: React.FormEvent) {
    e.preventDefault();
    if (!feedUrl.trim()) return;
    setLoading(true);
    setFeedStatus(null);
    try {
      const res = await fetch("/api/feeds", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url: feedUrl.trim() }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "RSS import başarısız");
      setFeedStatus({ type: "success", msg: `${data.imported} yeni kayıt eklendi` });
      setFeedUrl("");
      await loadFeeds();
    } catch (err) {
      setFeedStatus({ type: "error", msg: err instanceof Error ? err.message : "Hata" });
    } finally {
      setLoading(false);
    }
  }

  async function refreshFeed(id: string) {
    try {
      const res = await fetch(`/api/feeds/${id}`, { method: "POST" });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Feed yenilenemedi");
      setFeedStatus({ type: "success", msg: `${data.imported} yeni makale eklendi` });
    } catch (err) {
      setFeedStatus({ type: "error", msg: err instanceof Error ? err.message : "Feed yenilenemedi" });
    }
    await loadFeeds();
  }

  async function deleteFeed(id: string) {
    await fetch(`/api/feeds/${id}`, { method: "DELETE" });
    await loadFeeds();
  }

  async function importOmnivore(file: File) {
    setLoading(true);
    setOmnivoreStatus(null);
    try {
      const json = JSON.parse(await file.text());
      const res = await fetch("/api/import/omnivore", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ data: json }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Import başarısız");
      setOmnivoreStatus({
        type: "success",
        msg: `${data.imported} kayıt içe aktarıldı, ${data.skipped} atlandı`,
      });
    } catch (err) {
      setOmnivoreStatus({ type: "error", msg: err instanceof Error ? err.message : "Geçersiz JSON" });
    } finally {
      setLoading(false);
    }
  }

  function handleFile(file: File) {
    if (!/\.json$/i.test(file.name)) {
      setOmnivoreStatus({ type: "error", msg: "Yalnızca JSON dosyası kabul edilir." });
      return;
    }
    setSelectedFile(file);
    setOmnivoreStatus(null);
  }

  async function addUrl(e: React.FormEvent) {
    e.preventDefault();
    if (!manualUrl.trim()) return;
    setLoading(true);
    setManualStatus(null);
    try {
      const res = await fetch("/api/clips", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url: manualUrl.trim() }),
      });
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? "Kayıt başarısız");
      setManualStatus({ type: "success", msg: "Makale eklendi — içerik arka planda ayrıştırılıyor." });
      setManualUrl("");
    } catch (err) {
      setManualStatus({ type: "error", msg: err instanceof Error ? err.message : "Hata" });
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="standalone-page">
      <PageBack />
      <h1 className="standalone-title">İçe Aktar</h1>
      <p className="standalone-desc">Omnivore arşivinizi, RSS feed&apos;inizi veya tek bir URL&apos;yi okuma listenize aktarın.</p>

      <div className="import-tabs" role="tablist">
        {(
          [
            ["omnivore", "Omnivore JSON"],
            ["rss", "RSS Feed"],
            ["url", "URL Ekle"],
          ] as const
        ).map(([id, label]) => (
          <button
            key={id}
            type="button"
            role="tab"
            className={`import-tab ${tab === id ? "active" : ""}`}
            aria-selected={tab === id}
            onClick={() => setTab(id)}
          >
            {label}
          </button>
        ))}
      </div>

      {tab === "omnivore" && (
        <div className="card-section">
          <h2 className="section-title">Omnivore dışa aktarma</h2>
          <p className="section-desc">Omnivore → Ayarlar → Dışa aktar ile indirilen .json dosyasını yükleyin.</p>

          <button
            type="button"
            className={`drop-zone ${dragOver ? "dragover" : ""}`}
            onClick={() => fileInputRef.current?.click()}
            onDragOver={(e) => {
              e.preventDefault();
              setDragOver(true);
            }}
            onDragLeave={() => setDragOver(false)}
            onDrop={(e) => {
              e.preventDefault();
              setDragOver(false);
              const file = e.dataTransfer.files[0];
              if (file) handleFile(file);
            }}
          >
            <IconUpload size={32} />
            <span className="font-medium">JSON dosyasını sürükleyin</span>
            <span className="text-xs text-[var(--text-muted)]">veya tıklayarak seçin</span>
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept=".json,application/json"
            hidden
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handleFile(file);
            }}
          />
          {selectedFile && (
            <p className="text-sm font-mono mt-3 text-[var(--text-secondary)]">{selectedFile.name}</p>
          )}
          <button
            type="button"
            className="btn-primary mt-4"
            disabled={!selectedFile || loading}
            onClick={() => selectedFile && void importOmnivore(selectedFile)}
          >
            İçe aktar
          </button>
          {omnivoreStatus && (
            <p className={`import-result ${omnivoreStatus.type}`}>{omnivoreStatus.msg}</p>
          )}
        </div>
      )}

      {tab === "rss" && (
        <div className="card-section">
          <h2 className="section-title">RSS feed</h2>
          <p className="section-desc">Feed URL&apos;sini girin; yeni makaleler okuma listenize eklenir.</p>
          <form onSubmit={importFeed}>
            <label className="form-label" htmlFor="feed-url">
              Feed URL
            </label>
            <input
              id="feed-url"
              type="url"
              className="form-input"
              placeholder="https://example.com/feed.xml"
              value={feedUrl}
              onChange={(e) => setFeedUrl(e.target.value)}
              required
            />
            <button type="submit" className="btn-primary mt-4" disabled={loading}>
              Feed ekle
            </button>
          </form>
          {feedStatus && <p className={`import-result ${feedStatus.type}`}>{feedStatus.msg}</p>}

          {feeds.length > 0 && (
            <ul className="mt-4 space-y-2 text-sm">
              {feeds.map((f) => (
                <li key={f.id} className="flex justify-between gap-2 border-t border-[var(--border)] pt-2">
                  <span className="truncate">{f.title ?? f.url}</span>
                  <span className="shrink-0 flex gap-2">
                    <button type="button" className="text-[var(--accent)] bg-transparent border-0 cursor-pointer text-xs" onClick={() => refreshFeed(f.id)}>
                      Yenile
                    </button>
                    <button type="button" className="text-[var(--danger)] bg-transparent border-0 cursor-pointer text-xs" onClick={() => deleteFeed(f.id)}>
                      Sil
                    </button>
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {tab === "url" && (
        <div className="card-section">
          <h2 className="section-title">Manuel URL</h2>
          <p className="section-desc">Tek bir makale URL&apos;si ekleyin; Readability ile arka planda ayrıştırılır.</p>
          <form onSubmit={addUrl}>
            <label className="form-label" htmlFor="manual-url">
              Makale URL
            </label>
            <input
              id="manual-url"
              type="url"
              className="form-input"
              placeholder="https://..."
              value={manualUrl}
              onChange={(e) => setManualUrl(e.target.value)}
              required
            />
            <button type="submit" className="btn-primary mt-4" disabled={loading}>
              Kaydet
            </button>
          </form>
          {manualStatus && <p className={`import-result ${manualStatus.type}`}>{manualStatus.msg}</p>}
        </div>
      )}
    </main>
  );
}
