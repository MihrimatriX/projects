"use client";

import { useEffect, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import ReaderView from "@/components/ReaderView";
import type { ClipItem, HighlightItem } from "@/types/clip";

export default function ReadPage() {
  const params = useParams();
  const id = params.id as string;
  const router = useRouter();
  const [clip, setClip] = useState<ClipItem | null>(null);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    const res = await fetch(`/api/clips/${id}`).catch(() => null);
    if (res?.status === 404) {
      setError("Kayıt bulunamadı");
      return;
    }
    if (!res?.ok) {
      // Geçici sunucu/ağ hatası: kayıt yok denmez, tekrar denenebilir
      setError("Kayıt yüklenemedi");
      return;
    }
    const data = await res.json();
    setError("");
    setClip(data.clip);
  }, [id]);

  useEffect(() => {
    load();
    const interval = setInterval(() => {
      if (clip?.parseStatus === "pending") load();
    }, 3000);
    return () => clearInterval(interval);
  }, [load, clip?.parseStatus]);

  async function patch(field: "isRead" | "isStarred", value: boolean) {
    if (!clip) return;
    setClip({ ...clip, [field]: value });
    const res = await fetch(`/api/clips/${clip.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ [field]: value }),
    }).catch(() => null);
    // Kaydedilemediyse ekrandaki durum geri alınır
    if (!res?.ok) setClip((c) => (c ? { ...c, [field]: !value } : c));
  }

  async function remove() {
    if (!clip || !confirm(`"${clip.title}" okuma listesinden silinsin mi?`)) return;
    const res = await fetch(`/api/clips/${clip.id}`, { method: "DELETE" }).catch(() => null);
    if (res?.ok || res?.status === 404) router.push("/");
    else setError("Kayıt silinemedi");
  }

  async function reparse() {
    if (!clip) return;
    await fetch(`/api/clips/${clip.id}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action: "reparse" }),
    });
    setClip({ ...clip, parseStatus: "pending", content: null });
    setTimeout(load, 2000);
  }

  async function addHighlight(text: string) {
    if (!clip) return;
    const res = await fetch(`/api/clips/${clip.id}/highlights`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text }),
    });
    const data = await res.json();
    if (data.highlight) {
      setClip({ ...clip, highlights: [...clip.highlights, data.highlight as HighlightItem] });
    }
  }

  async function deleteHighlight(highlightId: string) {
    if (!clip) return;
    await fetch(`/api/highlights/${highlightId}`, { method: "DELETE" });
    setClip({ ...clip, highlights: clip.highlights.filter((h) => h.id !== highlightId) });
  }

  async function updateHighlightNote(highlightId: string, note: string) {
    if (!clip) return;
    await fetch(`/api/highlights/${highlightId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ note }),
    });
    setClip({
      ...clip,
      highlights: clip.highlights.map((h) => (h.id === highlightId ? { ...h, note } : h)),
    });
  }

  if (error) {
    return (
      <main className="standalone-page text-center">
        <p className="text-[var(--text-muted)]">{error}</p>
        {error === "Kayıt yüklenemedi" && (
          <button type="button" className="btn-primary mt-4" onClick={() => void load()}>
            Tekrar dene
          </button>
        )}
      </main>
    );
  }

  if (!clip) {
    return <main className="standalone-page text-center"><p className="text-[var(--text-muted)]">Yükleniyor…</p></main>;
  }

  return (
    <ReaderView
      clip={clip}
      onToggleStar={() => patch("isStarred", !clip.isStarred)}
      onToggleRead={() => patch("isRead", !clip.isRead)}
      onReparse={reparse}
      onDelete={remove}
      onAddHighlight={addHighlight}
      onDeleteHighlight={deleteHighlight}
      onUpdateHighlightNote={updateHighlightNote}
    />
  );
}
