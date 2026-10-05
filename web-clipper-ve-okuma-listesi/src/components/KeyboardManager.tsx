"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useClipStore } from "@/lib/store";

type Props = {
  onToast?: (msg: string) => void;
};

export default function KeyboardManager({ onToast }: Props) {
  const router = useRouter();
  const { clips, selectedClipId, setSelectedClipId, updateClipLocal } = useClipStore();

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
      // Ctrl/Meta/Alt kısayolları tarayıcıya kalsın (Ctrl+S, Ctrl+K vb.)
      if (e.ctrlKey || e.metaKey || e.altKey) return;

      const idx = selectedClipId ? clips.findIndex((c) => c.id === selectedClipId) : -1;

      if (e.key === "j" || e.key === "k") {
        e.preventDefault();
        if (!clips.length) return;
        const next =
          e.key === "j"
            ? Math.min(idx + 1, clips.length - 1)
            : Math.max(idx <= 0 ? 0 : idx - 1, 0);
        const target = clips[next === idx && e.key === "k" ? 0 : next];
        if (target) {
          setSelectedClipId(target.id);
          onToast?.(`Makale ${next + 1}/${clips.length}`);
        }
      }

      if (e.key === "o" && selectedClipId) {
        e.preventDefault();
        router.push(`/read/${selectedClipId}`);
      }

      if (e.key === "s" && selectedClipId) {
        e.preventDefault();
        const clip = clips.find((c) => c.id === selectedClipId);
        if (!clip) return;
        const next = !clip.isStarred;
        updateClipLocal(selectedClipId, { isStarred: next });
        fetch(`/api/clips/${selectedClipId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ isStarred: next }),
        });
      }

      if (e.key === "m" && selectedClipId) {
        e.preventDefault();
        const clip = clips.find((c) => c.id === selectedClipId);
        if (!clip) return;
        const next = !clip.isRead;
        updateClipLocal(selectedClipId, { isRead: next });
        fetch(`/api/clips/${selectedClipId}`, {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ isRead: next }),
        });
      }
    }

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [clips, selectedClipId, router, setSelectedClipId, updateClipLocal, onToast]);

  return null;
}
