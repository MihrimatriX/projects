"use client";

import { useEffect, useRef, useState } from "react";
import { IconAttach } from "@/components/icons";
import { getSocket } from "@/lib/socket-client";
import type { MessageItem } from "@/types";

// Yarım kalan mesajlar kanal (ve thread) başına tarayıcıda saklanır; kanal değiştirince kaybolmaz
function draftKey(channelId: string, parentId?: string) {
  return `sohbet-taslak:${channelId}${parentId ? `:${parentId}` : ""}`;
}

function readDraft(key: string): string {
  try {
    return localStorage.getItem(key) ?? "";
  } catch {
    return "";
  }
}

function writeDraft(key: string, value: string) {
  try {
    if (value) localStorage.setItem(key, value);
    else localStorage.removeItem(key);
  } catch {
    // depolama kapalıysa taslak yalnızca bellekte kalır
  }
}

type Props = {
  channelId: string;
  placeholder?: string;
  parentId?: string;
  onSent: (message: MessageItem & { channelId: string }) => void;
};

export function MessageComposer({
  channelId,
  placeholder = "Mesaj yaz…",
  parentId,
  onSent,
}: Props) {
  const [text, setText] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [sending, setSending] = useState(false);
  const [focused, setFocused] = useState(false);
  const [error, setError] = useState("");
  const key = draftKey(channelId, parentId);

  useEffect(() => {
    setText(readDraft(key));
    setFile(null);
    setError("");
  }, [key]);
  const typingTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  function emitTyping(active: boolean) {
    const socket = getSocket();
    if (active) socket.emit("typing:start", channelId);
    else socket.emit("typing:stop", channelId);
  }

  function handleChange(value: string) {
    setText(value);
    writeDraft(key, value);
    emitTyping(true);
    if (typingTimer.current) clearTimeout(typingTimer.current);
    typingTimer.current = setTimeout(() => emitTyping(false), 1500);
    if (textareaRef.current) {
      textareaRef.current.style.height = "auto";
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 120)}px`;
    }
  }

  async function submit(e?: React.FormEvent) {
    e?.preventDefault();
    if (!text.trim() && !file) return;
    setSending(true);
    setError("");
    emitTyping(false);

    try {
      let res: Response;
      if (file && !parentId) {
        const form = new FormData();
        form.append("channelId", channelId);
        form.append("content", text.trim());
        form.append("file", file);
        res = await fetch("/api/upload", { method: "POST", body: form });
      } else {
        res = await fetch(`/api/channels/${channelId}/messages`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            content: text.trim(),
            ...(parentId ? { parentId } : {}),
          }),
        });
      }
      const data = await res.json().catch(() => ({}));
      // Gönderilemeyen mesaj silinmez; kullanıcı düzeltip tekrar deneyebilir
      if (!res.ok) throw new Error(data.error ?? "Mesaj gönderilemedi");
      setText("");
      writeDraft(key, "");
      setFile(null);
      if (textareaRef.current) textareaRef.current.style.height = "auto";
      onSent({ ...data.message, channelId });
    } catch (err) {
      setError(
        err instanceof Error && err.message !== "Failed to fetch"
          ? err.message
          : "Sunucuya ulaşılamadı, mesaj gönderilemedi",
      );
    } finally {
      setSending(false);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      submit();
    }
  }

  const canSend = !sending && (text.trim() || file);

  return (
    <div className="px-5 pb-5 shrink-0">
      {file && (
        <div
          className="mb-2 text-sm flex items-center gap-2 px-3 py-2 rounded-lg"
          style={{ background: "var(--bg-hover)" }}
        >
          📎 {file.name}
          <button
            type="button"
            onClick={() => setFile(null)}
            className="ml-auto text-xs"
            style={{ color: "var(--unread)" }}
          >
            Kaldır
          </button>
        </div>
      )}
      {error && (
        <p role="alert" className="mb-2 text-sm" style={{ color: "var(--danger)" }}>
          {error}
        </p>
      )}
      <form
        onSubmit={submit}
        className={`composer-box ${focused ? "focused" : ""}`}
      >
        <textarea
          ref={textareaRef}
          rows={1}
          value={text}
          onChange={(e) => handleChange(e.target.value)}
          onKeyDown={handleKeyDown}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          placeholder={placeholder}
          aria-label="Mesaj yaz"
        />
        <div className="flex items-center justify-between px-2 pb-2">
          <div className="flex gap-0.5">
            {!parentId && (
              <label className="icon-btn cursor-pointer" title="Dosya ekle">
                <IconAttach />
                <input
                  type="file"
                  aria-label="Dosya ekle"
                  className="hidden"
                  onChange={(e) => {
                    setFile(e.target.files?.[0] ?? null);
                    e.target.value = ""; // aynı dosya kaldırılıp yeniden seçilebilsin
                  }}
                />
              </label>
            )}
          </div>
          <button type="submit" disabled={!canSend} className="send-btn">
            {parentId ? "Yanıtla" : "Gönder"}
          </button>
        </div>
      </form>
    </div>
  );
}
