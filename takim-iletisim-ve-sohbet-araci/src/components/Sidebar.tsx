"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { IconDm, IconHash, IconLock, IconSearch, IconSettings } from "@/components/icons";
import type { ChannelSummary } from "@/types";

type Props = {
  channels: ChannelSummary[];
  activeId: string | null;
  onSelect: (id: string) => void;
  onCreateChannel: (name: string) => void;
  onSearch: () => void;
  onShortcuts: () => void;
  workspaceName: string;
  mobileOpen: boolean;
  onMobileClose: () => void;
};

export function Sidebar({
  channels,
  activeId,
  onSelect,
  onCreateChannel,
  onSearch,
  onShortcuts,
  workspaceName,
  mobileOpen,
  onMobileClose,
}: Props) {
  const [filter, setFilter] = useState("");
  const [newChannel, setNewChannel] = useState("");

  const publicChannels = useMemo(
    () => channels.filter((c) => c.type === "PUBLIC"),
    [channels],
  );
  const dmChannels = useMemo(
    () => channels.filter((c) => c.type === "DM"),
    [channels],
  );

  const q = filter.toLowerCase();
  const filteredPublic = publicChannels.filter((c) =>
    c.name.toLowerCase().includes(q),
  );
  const filteredDm = dmChannels.filter((c) =>
    (c.dmPartner?.name ?? "").toLowerCase().includes(q),
  );

  function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    const name = newChannel.trim();
    if (!name) return;
    onCreateChannel(name);
    setNewChannel("");
  }

  return (
    <aside
      className={`sidebar-mobile flex flex-col h-full overflow-hidden border-r ${mobileOpen ? "open" : ""}`}
      style={{ background: "var(--bg-sidebar)", borderColor: "var(--border)" }}
      aria-label="Kanal listesi"
    >
      <div className="px-3 pt-3 pb-2 shrink-0">
        <div
          className="flex items-center justify-between px-2 pb-3 mb-2 border-b font-semibold text-[15px]"
          style={{ borderColor: "var(--border)" }}
        >
          <span>{workspaceName}</span>
          <Link href="/settings" className="icon-btn" aria-label="Ayarlar">
            <IconSettings />
          </Link>
        </div>
        <div className="relative">
          <span
            className="absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none"
            style={{ color: "var(--text-muted)" }}
          >
            <IconSearch size={16} />
          </span>
          <input
            type="search"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            placeholder="Kanal ara…"
            aria-label="Kanal ara"
            className="w-full text-[13px] pl-8 pr-3 py-2 rounded-lg outline-none"
            style={{
              background: "var(--bg-input)",
              color: "var(--text-primary)",
              border: "1px solid transparent",
            }}
            onFocus={(e) => {
              e.currentTarget.style.borderColor = "var(--mention)";
            }}
            onBlur={(e) => {
              e.currentTarget.style.borderColor = "transparent";
            }}
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto scrollbar-thin px-2 pb-4">
        <p
          className="px-2 py-1 text-[13px] font-semibold"
          style={{ color: "var(--text-muted)" }}
        >
          Kanallar
        </p>
        {filteredPublic.map((ch) => (
          <ChannelItem
            key={ch.id}
            label={ch.name}
            type={ch.type}
            active={activeId === ch.id}
            unread={ch.unreadCount}
            onClick={() => {
              onSelect(ch.id);
              onMobileClose();
            }}
          />
        ))}

        <form onSubmit={handleCreate} className="px-1 py-2 flex gap-1">
          <input
            value={newChannel}
            onChange={(e) => setNewChannel(e.target.value)}
            placeholder="Yeni kanal"
            aria-label="Yeni kanal adı"
            className="flex-1 min-w-0 text-sm px-2 py-1.5 rounded outline-none"
            style={{ background: "var(--bg-input)", color: "var(--text-primary)" }}
          />
          <button type="submit" className="send-btn px-2.5" aria-label="Kanal oluştur" title="Kanal oluştur">
            +
          </button>
        </form>

        {filteredDm.length > 0 && (
          <>
            <p
              className="px-2 py-1 mt-2 text-[13px] font-semibold"
              style={{ color: "var(--text-muted)" }}
            >
              Doğrudan mesajlar
            </p>
            {filteredDm.map((ch) => (
              <ChannelItem
                key={ch.id}
                label={ch.dmPartner?.name ?? "DM"}
                type="DM"
                active={activeId === ch.id}
                unread={ch.unreadCount}
                onClick={() => {
                  onSelect(ch.id);
                  onMobileClose();
                }}
              />
            ))}
          </>
        )}
      </div>

      <div className="px-3 py-2 border-t shrink-0" style={{ borderColor: "var(--border)" }}>
        <button
          type="button"
          onClick={onSearch}
          className="channel-item w-full"
          style={{ color: "var(--text-muted)" }}
        >
          <IconSearch size={18} />
          Hızlı arama (Ctrl+K)
        </button>
        <button
          type="button"
          onClick={onShortcuts}
          className="channel-item w-full"
          style={{ color: "var(--text-muted)" }}
        >
          <span aria-hidden="true" className="w-[18px] text-center font-bold">?</span>
          Kısayollar (Ctrl+/)
        </button>
      </div>
    </aside>
  );
}

function ChannelItem({
  label,
  type,
  active,
  unread,
  onClick,
}: {
  label: string;
  type: string;
  active: boolean;
  unread: number;
  onClick: () => void;
}) {
  const Icon = type === "DM" ? IconDm : type === "PRIVATE" ? IconLock : IconHash;
  return (
    <button
      type="button"
      onClick={onClick}
      className={`channel-item ${active ? "active" : ""} ${unread > 0 && !active ? "unread" : ""}`}
    >
      <Icon size={18} />
      <span className="truncate">{label}</span>
      {unread > 0 && <span className="unread-badge">{unread}</span>}
    </button>
  );
}
