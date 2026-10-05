"use client";

import { useState } from "react";
import { useFeedStore } from "@/lib/store";
import { addFeed } from "@/app/actions";

interface FeedModalProps {
  onAdded: () => void;
}

const NEW_FOLDER = "__new__";

export default function FeedModal({ onAdded }: FeedModalProps) {
  const { feedModalOpen, setFeedModalOpen, feeds } = useFeedStore();
  const [url, setUrl] = useState("");
  const [folder, setFolder] = useState("Genel");
  const [customFolder, setCustomFolder] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const folders = [...new Set(feeds.map((f) => f.folder || "Genel"))];
  if (folders.length === 0) folders.push("Genel");

  const resolvedFolder =
    folder === NEW_FOLDER ? customFolder.trim() || "Genel" : folder;

  const close = () => {
    setFeedModalOpen(false);
    setError(null);
    setUrl("");
    setFolder("Genel");
    setCustomFolder("");
  };

  const handleSave = async () => {
    const clean = url.trim();
    if (!clean) {
      setError("URL gerekli.");
      return;
    }
    if (folder === NEW_FOLDER && !customFolder.trim()) {
      setError("Yeni klasör adı gerekli.");
      return;
    }
    setSaving(true);
    setError(null);
    const res = await addFeed(clean, resolvedFolder);
    setSaving(false);
    if (res.success) {
      close();
      useFeedStore.getState().showToast(`"${res.feed?.title ?? "Feed"}" eklendi.`);
      onAdded();
    } else {
      setError(res.error ?? "Geçersiz URL veya SSRF engeli.");
    }
  };

  if (!feedModalOpen) return null;

  return (
    <div
      className="modal-backdrop open"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      onClick={(e) => e.target === e.currentTarget && close()}
    >
      <div className="modal">
        <h3 id="modal-title">RSS / Atom feed ekle</h3>
        <p className="modal-hint">
          Kendi RSS adresinizi yapıştırın. Bazı siteler bot erişimini engeller (403) — o zaman farklı bir
          feed URL deneyin. Örnek: <code>https://www.haberturk.com/rss</code>
        </p>
        <div className="form-group">
          <label htmlFor="feed-url">Feed URL</label>
          <input
            id="feed-url"
            type="url"
            placeholder="https://example.com/rss.xml"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            autoFocus
            onKeyDown={(e) => e.key === "Enter" && handleSave()}
          />
          {error && <p className="form-error">{error}</p>}
        </div>
        <div className="form-group">
          <label htmlFor="feed-folder">Klasör</label>
          <select id="feed-folder" value={folder} onChange={(e) => setFolder(e.target.value)}>
            {folders.map((f) => (
              <option key={f} value={f}>
                {f}
              </option>
            ))}
            <option value={NEW_FOLDER}>+ Yeni klasör…</option>
          </select>
        </div>
        {folder === NEW_FOLDER && (
          <div className="form-group">
            <label htmlFor="feed-folder-new">Yeni klasör adı</label>
            <input
              id="feed-folder-new"
              type="text"
              placeholder="Örn. Haberler, Teknoloji"
              value={customFolder}
              onChange={(e) => setCustomFolder(e.target.value)}
            />
          </div>
        )}
        <div className="modal-actions">
          <button type="button" className="btn-ghost" onClick={close}>
            İptal
          </button>
          <button type="button" className="btn-primary" disabled={saving} onClick={handleSave}>
            {saving ? "Ekleniyor…" : "Ekle"}
          </button>
        </div>
      </div>
    </div>
  );
}
