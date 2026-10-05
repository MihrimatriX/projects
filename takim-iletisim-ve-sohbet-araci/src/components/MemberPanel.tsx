"use client";

import type { MemberItem } from "@/types";

type Props = {
  members: MemberItem[];
  self: { id: string; name: string };
  onStartDm: (userId: string) => void;
};

const statusClass: Record<string, string> = {
  ONLINE: "online",
  AWAY: "away",
  OFFLINE: "offline",
};

export function MemberPanel({ members, self, onStartDm }: Props) {
  // Başlıktaki "çevrimiçi" sayısı kendini de sayar; liste de seni en üstte gösterir
  const online = members.filter((m) => m.status === "ONLINE").length + 1;

  return (
    <aside
      className="members-panel flex flex-col h-full border-l overflow-y-auto scrollbar-thin p-4"
      style={{
        background: "var(--bg-sidebar)",
        borderColor: "var(--border)",
      }}
      aria-label="Üyeler"
    >
      <h3
        className="text-[13px] font-semibold uppercase tracking-wider mb-3"
        style={{ color: "var(--text-muted)" }}
      >
        Çevrimiçi — {online}
      </h3>
      <div className="flex items-center gap-2.5 py-1.5 text-sm" style={{ color: "var(--text-muted)" }}>
        <span className="presence online" />
        {self.name} (sen)
      </div>
      {members.map((m) => (
        <button
          key={m.id}
          type="button"
          onClick={() => onStartDm(m.id)}
          title={`${m.name} ile doğrudan mesaj`}
          className="flex items-center gap-2.5 py-1.5 text-sm w-full text-left"
        >
          <span className={`presence ${statusClass[m.status] ?? "offline"}`} />
          {m.name}
        </button>
      ))}
    </aside>
  );
}
