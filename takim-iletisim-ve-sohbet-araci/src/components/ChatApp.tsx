"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { IconMenu, IconThread, IconWarn } from "@/components/icons";
import { MemberPanel } from "@/components/MemberPanel";
import { MessageComposer } from "@/components/MessageComposer";
import { MessageFeed } from "@/components/MessageFeed";
import { SearchDialog } from "@/components/SearchDialog";
import { Sidebar } from "@/components/Sidebar";
import { ThreadPanel } from "@/components/ThreadPanel";
import { channelLabel } from "@/lib/format";
import { connectSocket, disconnectSocket, getSocket } from "@/lib/socket-client";
import { useChatStore } from "@/lib/store";
import type { MessageItem } from "@/types";

const LAST_CHANNEL_KEY = "sohbet-son-kanal";

const SHORTCUTS: [string, string][] = [
  ["Ctrl+K", "Mesajlarda hızlı arama"],
  ["Alt+↑ / Alt+↓", "Önceki / sonraki kanal"],
  ["Enter", "Mesajı gönder / düzenlemeyi kaydet"],
  ["Shift+Enter", "Yeni satır"],
  ["Esc", "Thread'i, menüyü veya diyaloğu kapat; düzenlemeden vazgeç"],
  ["Ctrl+/", "Bu listeyi aç/kapat"],
];

export function ChatApp() {
  const router = useRouter();
  const {
    user,
    workspaceName,
    channels,
    activeChannelId,
    messages,
    members,
    searchOpen,
    setUser,
    setWorkspaceName,
    setChannels,
    setActiveChannelId,
    setMessages,
    prependMessages,
    addMessage,
    removeMessage,
    updateMessage,
    bumpReplyCount,
    setMembers,
    updateMemberStatus,
    setTyping,
    setSearchOpen,
    bumpUnread,
    clearUnread,
  } = useChatStore();

  const [hasMore, setHasMore] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [loading, setLoading] = useState(true);
  const [threadMessageId, setThreadMessageId] = useState<string | null>(null);
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [switching, setSwitching] = useState(false);
  const [reconnecting, setReconnecting] = useState(false);
  const [error, setError] = useState("");
  const [threadVersion, setThreadVersion] = useState(0);
  const [shortcutsOpen, setShortcutsOpen] = useState(false);
  const threadRef = useRef(threadMessageId);
  threadRef.current = threadMessageId;

  const errorTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const showError = useCallback((message: string) => {
    setError(message);
    if (errorTimer.current) clearTimeout(errorTimer.current); // art arda hatada yenisi erken silinmesin
    errorTimer.current = setTimeout(() => setError(""), 4000);
  }, []);

  const activeChannelRef = useRef(activeChannelId);
  activeChannelRef.current = activeChannelId;

  const activeChannel = channels.find((c) => c.id === activeChannelId);
  const publicChannels = channels.filter((c) => c.type === "PUBLIC");
  const onlineCount = members.filter((m) => m.status === "ONLINE").length + 1;

  const refreshChannels = useCallback(async () => {
    const res = await fetch("/api/channels");
    if (res.status === 401) {
      router.push("/login");
      return;
    }
    const data = await res.json();
    setChannels(data.channels ?? []);
  }, [router, setChannels]);

  const loadMessages = useCallback(
    async (channelId: string, cursor?: string) => {
      const url = cursor
        ? `/api/channels/${channelId}/messages?cursor=${cursor}`
        : `/api/channels/${channelId}/messages`;
      const res = await fetch(url);
      const data = await res.json();
      // Yanıt gelene kadar başka kanala geçildiyse eski kanalın mesajları yazılmaz
      if (channelId !== activeChannelRef.current) return;
      const fetched: MessageItem[] = data.messages ?? [];
      if (cursor) prependMessages(fetched);
      else {
        // Yükleme sürerken gönderilen/soketten gelen mesajlar listeden düşmesin
        const ids = new Set(fetched.map((m) => m.id));
        const pending = useChatStore.getState().messages.filter((m) => !ids.has(m.id));
        setMessages([...fetched, ...pending]);
      }
      setHasMore(data.hasMore ?? false);
      setLoaded(true);
    },
    [prependMessages, setMessages],
  );

  const markRead = useCallback(
    async (channelId: string) => {
      await fetch(`/api/channels/${channelId}/messages`, { method: "PATCH" });
      clearUnread(channelId);
    },
    [clearUnread],
  );

  const selectChannel = useCallback(
    (id: string) => {
      if (id === activeChannelId) return;
      setSwitching(true);
      setTimeout(() => {
        setActiveChannelId(id);
        setThreadMessageId(null);
        setSwitching(false);
      }, 90);
    },
    [activeChannelId, setActiveChannelId],
  );

  useEffect(() => {
    async function init() {
      const meRes = await fetch("/api/auth/me");
      const me = await meRes.json();
      if (!me.user) {
        router.push("/login");
        return;
      }
      setUser(me.user);
      if (me.workspace) setWorkspaceName(me.workspace.name);

      await refreshChannels();
      const membersRes = await fetch("/api/users");
      const membersData = await membersRes.json();
      setMembers(membersData.members ?? []);
      setLoading(false);
    }
    init();
  }, [router, refreshChannels, setMembers, setUser, setWorkspaceName]);

  useEffect(() => {
    if (channels.length > 0 && !activeChannelId) {
      // Son açılan kanal hatırlanır; yoksa okunmamış mesajı olan, o da yoksa ilk kanal
      let last: string | null = null;
      try {
        last = localStorage.getItem(LAST_CHANNEL_KEY);
      } catch {
        // depolama kapalı
      }
      const start =
        channels.find((c) => c.id === last) ??
        channels.find((c) => c.unreadCount > 0) ??
        channels[0]!;
      setActiveChannelId(start.id);
    }
  }, [channels, activeChannelId, setActiveChannelId]);

  useEffect(() => {
    if (!activeChannelId || !user) return;
    try {
      localStorage.setItem(LAST_CHANNEL_KEY, activeChannelId);
    } catch {
      // depolama kapalı
    }
    setMessages([]);
    setLoaded(false);
    loadMessages(activeChannelId);
    markRead(activeChannelId);
    // Sunucu bağlantıda tüm kanal odalarına katar; bu yalnızca yeni açılan kanal için güvence.
    // Odadan ayrılınmaz: diğer kanalların mesajları okunmamış rozetini anlık günceller.
    getSocket().emit("channel:join", activeChannelId);
  }, [activeChannelId, user, loadMessages, markRead, setMessages]);

  // Tek soket bağlantısı: aktif kanal ref'ten okunur, böylece kanal değişince soket kapatılıp açılmaz
  useEffect(() => {
    if (!user) return;

    const socket = connectSocket({
      onMessage: (msg) => {
        if (msg.channelId === activeChannelRef.current) {
          // Thread yanıtları da kanal odasına yayınlanır; ana akışa yalnızca üst seviye mesajlar eklenir
          if (!msg.parentId) addMessage(msg as MessageItem);
          else {
            bumpReplyCount(msg.parentId);
            if (threadRef.current === msg.parentId) setThreadVersion((v) => v + 1);
          }
          markRead(msg.channelId);
        } else {
          bumpUnread(msg.channelId);
        }
        refreshChannels();
      },
      onDelete: ({ messageId, channelId, parentId }) => {
        if (channelId !== activeChannelRef.current) return;
        if (parentId) {
          bumpReplyCount(parentId, -1);
          if (threadRef.current === parentId) setThreadVersion((v) => v + 1);
        } else {
          removeMessage(messageId);
          if (threadRef.current === messageId) setThreadMessageId(null);
        }
      },
      onUpdate: ({ id, channelId, parentId, content, editedAt }) => {
        if (channelId !== activeChannelRef.current) return;
        updateMessage(id, { content, editedAt });
        if (parentId && threadRef.current === parentId) setThreadVersion((v) => v + 1);
      },
      onPresence: ({ userId, status }) => {
        updateMemberStatus(userId, status as "ONLINE" | "AWAY" | "OFFLINE");
      },
      onTypingStart: ({ channelId, userName }) => {
        if (userName !== user.name) setTyping(channelId, userName, true);
      },
      onTypingStop: ({ channelId, userName }) => {
        setTyping(channelId, userName, false);
      },
    });

    socket.on("connect", () => {
      setReconnecting(false);
      // Yeniden bağlanınca sunucudaki oda üyeliği sıfırlanır; aktif kanala tekrar katıl
      if (activeChannelRef.current) socket.emit("channel:join", activeChannelRef.current);
    });
    socket.on("disconnect", () => setReconnecting(true));
    // Başka biri yeni kanal açtı ya da bana DM başlattı
    socket.on("channels:changed", refreshChannels);

    return () => disconnectSocket();
  }, [
    user,
    addMessage,
    removeMessage,
    updateMessage,
    bumpReplyCount,
    bumpUnread,
    markRead,
    refreshChannels,
    setTyping,
    updateMemberStatus,
  ]);

  useEffect(() => {
    function onKeyDown(e: KeyboardEvent) {
      if (e.altKey && e.key === "ArrowUp") {
        e.preventDefault();
        const idx = publicChannels.findIndex((c) => c.id === activeChannelId);
        const next = publicChannels[(idx - 1 + publicChannels.length) % publicChannels.length];
        if (next) selectChannel(next.id);
      }
      if (e.altKey && e.key === "ArrowDown") {
        e.preventDefault();
        const idx = publicChannels.findIndex((c) => c.id === activeChannelId);
        const next = publicChannels[(idx + 1) % publicChannels.length];
        if (next) selectChannel(next.id);
      }
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setSearchOpen(true);
      }
      if ((e.ctrlKey || e.metaKey) && e.key === "/") {
        e.preventDefault();
        setShortcutsOpen((v) => !v);
      }
      // Düzenleme kutusu Esc'yi kendisi kullanır (preventDefault); açık diyalog önce kapanır
      if (e.key === "Escape" && !e.defaultPrevented) {
        if (shortcutsOpen) return setShortcutsOpen(false);
        if (searchOpen) return;
        setSidebarOpen(false);
        setThreadMessageId(null);
      }
    }
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [publicChannels, activeChannelId, selectChannel, setSearchOpen, searchOpen, shortcutsOpen]);

  async function handleCreateChannel(name: string) {
    const res = await fetch("/api/channels", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      showError(data.error ?? "Kanal oluşturulamadı");
      return;
    }
    await refreshChannels();
    selectChannel(data.channel.id);
  }

  async function handleEdit(messageId: string, content: string) {
    const res = await fetch(`/api/messages/${messageId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ content }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      showError(data.error ?? "Mesaj düzenlenemedi");
      return false;
    }
    updateMessage(messageId, { content: data.message.content, editedAt: data.message.editedAt });
    return true;
  }

  async function deleteMessage(id: string) {
    if (!confirm("Bu mesaj kalıcı olarak silinsin mi?")) return false;
    const res = await fetch(`/api/messages/${id}`, { method: "DELETE" }).catch(() => null);
    if (!res?.ok) showError("Mesaj silinemedi");
    return Boolean(res?.ok);
  }

  async function handleStartDm(userId: string) {
    const res = await fetch("/api/dm", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ userId }),
    });
    const data = await res.json().catch(() => ({}));
    if (!data.channel) {
      showError(data.error ?? "Doğrudan mesaj açılamadı");
      return;
    }
    await refreshChannels();
    selectChannel(data.channel.id);
  }

  if (loading || !user) {
    return (
      <div className="h-screen flex items-center justify-center" style={{ color: "var(--text-muted)" }}>
        Yükleniyor…
      </div>
    );
  }

  const headerTitle = activeChannel
    ? channelLabel(activeChannel.name, activeChannel.type, activeChannel.dmPartner)
    : "Kanal seçin";

  const gridClass = threadMessageId
    ? "app-grid thread-open"
    : "app-grid with-members";

  return (
    <div className={gridClass}>
      <Sidebar
        channels={channels}
        activeId={activeChannelId}
        onSelect={selectChannel}
        onCreateChannel={handleCreateChannel}
        onSearch={() => setSearchOpen(true)}
        onShortcuts={() => setShortcutsOpen(true)}
        workspaceName={workspaceName}
        mobileOpen={sidebarOpen}
        onMobileClose={() => setSidebarOpen(false)}
      />

      <section className="flex flex-col min-w-0" style={{ background: "var(--bg-main)" }}>
        {reconnecting && (
          <div className="reconnect-banner" role="status">
            <IconWarn />
            Bağlantı koptu — yeniden bağlanılıyor…
          </div>
        )}
        {error && (
          <div className="reconnect-banner" role="alert">
            <IconWarn />
            {error}
          </div>
        )}
        <header
          className="flex items-center justify-between px-5 shrink-0 border-b"
          style={{ height: 49, borderColor: "var(--border)" }}
        >
          <div className="flex items-center gap-3 min-w-0">
            <button
              type="button"
              className="icon-btn menu-toggle"
              aria-label="Menüyü aç"
              onClick={() => setSidebarOpen(true)}
            >
              <IconMenu />
            </button>
            <div className="min-w-0">
              <h1 className="font-bold text-lg truncate tracking-tight">{headerTitle}</h1>
              <div className="text-[13px] truncate" style={{ color: "var(--text-muted)" }}>
                {members.length + 1} üye · {onlineCount} çevrimiçi
              </div>
            </div>
          </div>
          <div className="flex items-center gap-1 shrink-0">
            {threadMessageId && (
              <button
                type="button"
                className="icon-btn"
                aria-label="Thread paneli"
                aria-pressed="true"
                onClick={() => setThreadMessageId(null)}
              >
                <IconThread />
              </button>
            )}
          </div>
        </header>

        {activeChannelId && activeChannel ? (
          <>
            <MessageFeed
              messages={messages}
              userId={user.id}
              channelId={activeChannelId}
              hasMore={hasMore}
              switching={switching}
              loaded={loaded}
              onReply={(m) => setThreadMessageId(m.id)}
              onDelete={async (id) => {
                if (await deleteMessage(id)) removeMessage(id);
              }}
              onEdit={handleEdit}
              onLoadMore={() => {
                if (messages[0]) loadMessages(activeChannelId, messages[0].id);
              }}
            />
            <MessageComposer
              channelId={activeChannelId}
              onSent={(m) => {
                if (m.channelId === activeChannelRef.current) addMessage(m);
              }}
            />
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center" style={{ color: "var(--text-muted)" }}>
            Bir kanal seçin
          </div>
        )}
      </section>

      {threadMessageId && activeChannelId ? (
        <ThreadPanel
          messageId={threadMessageId}
          channelId={activeChannelId}
          userId={user.id}
          version={threadVersion}
          onEdit={handleEdit}
          onDelete={deleteMessage} // thread, message:delete soket olayıyla yenilenir
          onClose={() => setThreadMessageId(null)}
        />
      ) : (
        <MemberPanel
          members={members}
          self={user}
          onStartDm={handleStartDm}
        />
      )}

      <SearchDialog
        open={searchOpen}
        onClose={() => setSearchOpen(false)}
        onSelectChannel={selectChannel}
      />

      {shortcutsOpen && (
        <div
          className="modal-overlay open"
          role="dialog"
          aria-modal="true"
          aria-label="Klavye kısayolları"
          onClick={() => setShortcutsOpen(false)}
        >
          <div className="quick-search p-5" onClick={(e) => e.stopPropagation()}>
            <h2 className="text-lg font-bold mb-3">Klavye kısayolları</h2>
            <table className="w-full text-sm">
              <tbody>
                {SHORTCUTS.map(([keys, what]) => (
                  <tr key={keys}>
                    <td className="py-1 pr-4 whitespace-nowrap">
                      <kbd>{keys}</kbd>
                    </td>
                    <td className="py-1" style={{ color: "var(--text-secondary)" }}>
                      {what}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <button type="button" autoFocus className="btn btn-ghost mt-4" onClick={() => setShortcutsOpen(false)}>
              Kapat
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
