"use client";

import { useParams } from "next/navigation";
import { useEffect, useState } from "react";
import BoardWorkspace from "@/components/BoardWorkspace";

type Loaded = { id: string; name: string; data: string } | { id: string; error: string };

export default function BoardPage() {
  const { id } = useParams<{ id: string }>();
  const [board, setBoard] = useState<Loaded | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch(`/api/boards/${id}`)
      .then(async (res) => {
        if (res.status === 404) return { id, error: "Pano bulunamadı." };
        if (!res.ok) return { id, error: "Pano yüklenemedi. Sayfayı yenileyip tekrar deneyin." };
        const { board } = await res.json();
        return { id, name: board.name as string, data: (board.data as string) || "{}" };
      })
      .catch(() => ({ id, error: "Sunucuya ulaşılamadı." }))
      .then((loaded) => {
        if (!cancelled) setBoard(loaded);
      });
    return () => {
      cancelled = true;
    };
  }, [id]);

  // Başka panoya geçilince eski panonun verisi yeni id ile asla tuvale/kayda karışmaz.
  if (!board || board.id !== id) {
    return (
      <div className="h-dvh grid place-items-center page-dots text-[var(--text-muted)] text-sm">
        Yükleniyor…
      </div>
    );
  }

  if ("error" in board) {
    return (
      <div className="h-dvh grid place-content-center justify-items-center page-dots">
        <p className="text-[var(--text-secondary)]">{board.error}</p>
        <a href="/" className="mt-3 text-[var(--accent)] text-sm hover:underline">
          Panolara dön
        </a>
      </div>
    );
  }

  return <BoardWorkspace key={id} boardId={id} boardName={board.name} initialData={board.data} />;
}
