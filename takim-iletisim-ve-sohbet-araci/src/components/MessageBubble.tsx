"use client";

import { useState } from "react";
import ReactMarkdown from "react-markdown";
import rehypeSanitize from "rehype-sanitize";
import remarkGfm from "remark-gfm";
import { IconReply } from "@/components/icons";
import { avatarColor, avatarInitials } from "@/lib/avatar";
import { highlightMentions } from "@/lib/mentions";
import { formatFileSize, formatTime } from "@/lib/format";
import type { MessageItem } from "@/types";

type Props = {
  message: MessageItem;
  isOwn: boolean;
  grouped?: boolean;
  onReply?: (message: MessageItem) => void;
  onDelete?: () => void;
  onEdit?: (content: string) => Promise<boolean>;
};

function MentionParagraph({ content }: { content: string }) {
  if (content.includes("@")) {
    return (
      <p dangerouslySetInnerHTML={{ __html: highlightMentions(content) }} />
    );
  }
  return <p>{content}</p>;
}

export function MessageBubble({
  message,
  isOwn,
  grouped = false,
  onReply,
  onDelete,
  onEdit,
}: Props) {
  const color = avatarColor(message.author.name);
  const initials = avatarInitials(message.author.name);
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");

  async function saveEdit() {
    const content = draft.trim();
    if (!content || content === message.content) return setEditing(false);
    if (await onEdit?.(content)) setEditing(false);
  }

  return (
    <article
      className={`msg relative ${grouped ? "grouped" : ""}`}
      aria-label={`${message.author.name} mesajı`}
      style={{
        display: "grid",
        gridTemplateColumns: "var(--avatar-size) 1fr",
        gap: "0 12px",
        marginBottom: grouped ? 4 : 16,
        marginTop: grouped ? 4 : 0,
      }}
    >
      <div
        className="avatar rounded-lg flex items-center justify-center text-sm font-bold text-white"
        style={{
          width: "var(--avatar-size)",
          height: "var(--avatar-size)",
          background: color,
          visibility: grouped ? "hidden" : "visible",
        }}
        aria-hidden="true"
      >
        {initials}
      </div>
      <div className="min-w-0">
        {!grouped && (
          <div className="flex items-baseline gap-2 mb-0.5">
            <span className="font-bold text-[15px]">{message.author.name}</span>
            <time className="text-xs" style={{ color: "var(--text-muted)" }} dateTime={message.createdAt}>
              {formatTime(message.createdAt)}
            </time>
          </div>
        )}
        {editing ? (
          <div className="composer-box focused mt-1">
            <textarea
              autoFocus
              rows={2}
              value={draft}
              aria-label="Mesajı düzenle"
              onChange={(e) => setDraft(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  saveEdit();
                }
                if (e.key === "Escape") {
                  e.preventDefault(); // ChatApp'in Esc'si thread'i kapatmasın
                  setEditing(false);
                }
              }}
            />
            <p className="px-3 pb-2 text-xs" style={{ color: "var(--text-muted)" }}>
              Enter kaydet · Esc vazgeç
            </p>
          </div>
        ) : (
        <div className="markdown-body text-[15px] leading-[1.466] break-words">
          <ReactMarkdown
            remarkPlugins={[remarkGfm]}
            rehypePlugins={[rehypeSanitize]}
            components={{
              // Yalnızca düz metin paragraflarında mention vurgusu; biçimli içerik (kalın, link) olduğu gibi kalır
              p: ({ children }) =>
                typeof children === "string" ? (
                  <MentionParagraph content={children} />
                ) : (
                  <p>{children}</p>
                ),
            }}
          >
            {message.content}
          </ReactMarkdown>
          {message.editedAt && (
            <span className="text-xs" style={{ color: "var(--text-muted)" }}>
              (düzenlendi)
            </span>
          )}
        </div>
        )}
        {message.attachments.length > 0 && (
          <div className="mt-2 space-y-1">
            {message.attachments.map((a) => (
              <a
                key={a.id}
                href={`/api/attachments/${a.id}`}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center gap-2 text-sm px-3 py-2 rounded-lg"
                style={{ background: "var(--bg-hover)", color: "var(--mention)" }}
              >
                📎 {a.fileName}
                <span style={{ color: "var(--text-muted)" }}>
                  ({formatFileSize(a.size)})
                </span>
              </a>
            ))}
          </div>
        )}
        {message.replyCount > 0 && onReply && (
          <button
            type="button"
            onClick={() => onReply(message)}
            className="text-xs mt-1"
            style={{ color: "var(--mention)" }}
          >
            {message.replyCount} yanıt
          </button>
        )}
      </div>
      {(onReply || onDelete || onEdit) && !editing && (
        <div className="msg-actions">
          {onReply && (
            <button type="button" onClick={() => onReply(message)} aria-label="Thread aç">
              <IconReply />
            </button>
          )}
          {onEdit && (
            <button
              type="button"
              onClick={() => {
                setDraft(message.content);
                setEditing(true);
              }}
              aria-label="Düzenle"
            >
              ✎
            </button>
          )}
          {onDelete && (
            <button
              type="button"
              onClick={onDelete}
              aria-label="Sil"
              style={{ color: "var(--danger)" }}
            >
              ✕
            </button>
          )}
        </div>
      )}
    </article>
  );
}
