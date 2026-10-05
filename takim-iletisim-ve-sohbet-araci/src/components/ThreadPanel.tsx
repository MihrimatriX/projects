"use client";

import { useEffect, useState } from "react";
import { MessageBubble } from "@/components/MessageBubble";
import { MessageComposer } from "@/components/MessageComposer";
import { IconClose } from "@/components/icons";
import type { MessageItem } from "@/types";

type Props = {
  messageId: string;
  channelId: string;
  userId: string;
  version?: number;
  onEdit?: (messageId: string, content: string) => Promise<boolean>;
  onDelete?: (messageId: string) => void;
  onClose: () => void;
};

export function ThreadPanel({
  messageId,
  channelId,
  userId,
  version = 0,
  onEdit,
  onDelete,
  onClose,
}: Props) {
  const [parent, setParent] = useState<MessageItem | null>(null);
  const [replies, setReplies] = useState<MessageItem[]>([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    const res = await fetch(`/api/messages/${messageId}/replies`);
    const data = await res.json();
    setParent(data.parent ?? null);
    setReplies(data.replies ?? []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, [messageId, version]);

  return (
    <aside
      className="thread-panel flex flex-col h-full border-l overflow-hidden"
      style={{ background: "var(--bg-thread)", borderColor: "var(--border)" }}
      aria-label="Thread"
    >
      <div
        className="flex items-center justify-between px-4 py-3 border-b shrink-0"
        style={{ borderColor: "var(--border)" }}
      >
        <h2 className="text-lg font-bold tracking-tight">Thread</h2>
        <button type="button" onClick={onClose} className="icon-btn" aria-label="Thread kapat">
          <IconClose />
        </button>
      </div>

      {parent && (
        <div
          className="px-4 py-4 border-b shrink-0"
          style={{ background: "var(--bg-hover)", borderColor: "var(--border)" }}
        >
          <MessageBubble message={parent} isOwn={parent.author.id === userId} />
        </div>
      )}

      <div className="flex-1 overflow-y-auto px-4 py-4 scrollbar-thin">
        {loading && (
          <p className="text-sm" style={{ color: "var(--text-muted)" }}>
            Yükleniyor…
          </p>
        )}
        {!loading && replies.length === 0 && (
          <p className="text-center text-sm py-8" style={{ color: "var(--text-muted)" }}>
            İlk yanıtı sen yaz
          </p>
        )}
        {replies.map((r, i) => {
          const prev = replies[i - 1];
          const grouped =
            i > 0 &&
            prev &&
            prev.author.id === r.author.id;
          return (
            <MessageBubble
              key={r.id}
              message={r}
              isOwn={r.author.id === userId}
              grouped={grouped}
              onEdit={
                r.author.id === userId && onEdit
                  ? (c) => onEdit(r.id, c) // thread, message:update soket olayıyla yenilenir
                  : undefined
              }
              onDelete={r.author.id === userId && onDelete ? () => onDelete(r.id) : undefined}
            />
          );
        })}
      </div>

      <MessageComposer
        channelId={channelId}
        parentId={messageId}
        placeholder="Yanıt yaz…"
        onSent={load}
      />
    </aside>
  );
}
