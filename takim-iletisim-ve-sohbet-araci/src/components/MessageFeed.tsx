"use client";

import { useEffect, useRef } from "react";
import { MessageBubble } from "@/components/MessageBubble";
import { useChatStore } from "@/lib/store";
import type { MessageItem } from "@/types";

const NO_TYPING: string[] = [];

type Props = {
  messages: MessageItem[];
  userId: string;
  channelId: string;
  onLoadMore?: () => void;
  hasMore?: boolean;
  onReply?: (message: MessageItem) => void;
  onDelete?: (messageId: string) => void;
  onEdit?: (messageId: string, content: string) => Promise<boolean>;
  switching?: boolean;
  loaded?: boolean;
};

export function MessageFeed({
  messages,
  userId,
  channelId,
  onLoadMore,
  hasMore,
  onReply,
  onDelete,
  onEdit,
  switching,
  loaded = true,
}: Props) {
  const bottomRef = useRef<HTMLDivElement>(null);
  // Sabit boş dizi: seçici her çağrıda yeni [] dönerse zustand sonsuz render döngüsüne girer
  const typingUsers = useChatStore((s) => s.typingUsers[channelId] ?? NO_TYPING);

  // Yalnızca sona mesaj eklenince aşağı kayar; eski mesajlar yüklenince (başa ekleme) konum korunur
  const lastId = messages[messages.length - 1]?.id;
  useEffect(() => {
    if (!switching) bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [lastId, channelId, switching]);

  return (
    <>
      <div
        role="feed"
        aria-live="polite"
        aria-label="Mesaj akışı"
        className={`flex-1 overflow-y-auto px-5 py-4 scrollbar-thin ${switching ? "opacity-0 translate-y-1" : ""}`}
        style={{ transition: "opacity 150ms var(--ease-out), transform 150ms var(--ease-out)" }}
      >
        {hasMore && (
          <button
            type="button"
            onClick={onLoadMore}
            className="text-sm w-full py-2 mb-4"
            style={{ color: "var(--mention)" }}
          >
            Daha eski mesajları yükle
          </button>
        )}
        {messages.length === 0 && loaded && !switching && (
          <p className="text-center text-sm py-10" style={{ color: "var(--text-muted)" }}>
            Bu kanalda henüz mesaj yok. İlk mesajı sen yaz.
          </p>
        )}
        {messages.map((m, i) => {
          const prev = messages[i - 1];
          const grouped =
            i > 0 &&
            prev &&
            prev.author.id === m.author.id &&
            new Date(m.createdAt).getTime() - new Date(prev.createdAt).getTime() < 5 * 60 * 1000;
          return (
            <MessageBubble
              key={m.id}
              message={m}
              isOwn={m.author.id === userId}
              grouped={grouped}
              onReply={onReply}
              onDelete={m.author.id === userId && onDelete ? () => onDelete(m.id) : undefined}
              onEdit={m.author.id === userId && onEdit ? (c) => onEdit(m.id, c) : undefined}
            />
          );
        })}
        <div ref={bottomRef} />
      </div>
      {typingUsers.length > 0 && (
        <div className="px-5 pb-2 text-[13px] flex items-center gap-1.5" style={{ color: "var(--text-muted)" }}>
          <span>{typingUsers.join(", ")} yazıyor</span>
          <span className="typing-dots" aria-hidden="true">
            <span />
            <span />
            <span />
          </span>
        </div>
      )}
    </>
  );
}
