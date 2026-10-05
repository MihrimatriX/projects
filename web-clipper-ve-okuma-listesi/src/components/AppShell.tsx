"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect } from "react";
import {
  IconBookmark,
  IconBook,
  IconCircle,
  IconSettings,
  IconStar,
} from "@/components/icons";

type Filter = "all" | "unread" | "starred";

type Props = {
  activeFilter: Filter;
  activeTag: string | null;
  tags: { id: string; name: string; count: number }[];
  counts: { all: number; unread: number; starred: number };
  onFilter: (f: Filter) => void;
  onTag: (tag: string | null) => void;
  sidebarOpen: boolean;
  onSidebarOpen: (open: boolean) => void;
  children: React.ReactNode;
};

const FILTER_LABELS: Record<Filter, string> = {
  all: "Tümü",
  unread: "Okunmamış",
  starred: "Yıldızlı",
};

export default function AppShell({
  activeFilter,
  activeTag,
  tags,
  counts,
  onFilter,
  onTag,
  sidebarOpen,
  onSidebarOpen,
  children,
}: Props) {
  const pathname = usePathname();

  useEffect(() => {
    onSidebarOpen(false);
  }, [pathname, onSidebarOpen]);

  function selectFilter(f: Filter) {
    onFilter(f);
    onSidebarOpen(false);
  }

  function selectTag(name: string) {
    onTag(activeTag === name ? null : name);
    onSidebarOpen(false);
  }

  return (
    <div className="app-shell">
      {sidebarOpen && (
        <button
          type="button"
          className="sidebar-overlay open"
          aria-label="Menüyü kapat"
          onClick={() => onSidebarOpen(false)}
        />
      )}

      <aside className={`sidebar ${sidebarOpen ? "open" : ""}`} aria-label="Etiket filtresi">
        <div className="sidebar-header">
          <Link href="/" className="sidebar-brand">
            <IconBookmark className="text-[var(--accent)]" />
            Kayıtlı Okuma
          </Link>
        </div>

        <nav className="sidebar-nav">
          {(["all", "unread", "starred"] as const).map((f) => (
            <button
              key={f}
              type="button"
              className={`nav-item ${activeFilter === f && !activeTag ? "active" : ""}`}
              onClick={() => selectFilter(f)}
            >
              {f === "all" ? <IconBook /> : f === "unread" ? <IconCircle /> : <IconStar />}
              {FILTER_LABELS[f]}
              <span className="nav-count">{counts[f]}</span>
            </button>
          ))}

          {tags.length > 0 && (
            <>
              <div className="nav-section-label">Etiketler</div>
              <div className="tag-list">
                {tags.map((t) => (
                  <button
                    key={t.id}
                    type="button"
                    className={`tag-chip ${activeTag === t.name ? "active" : ""}`}
                    onClick={() => selectTag(t.name)}
                  >
                    {t.name}
                  </button>
                ))}
              </div>
            </>
          )}
        </nav>

        <div className="sidebar-footer">
          <Link href="/settings">
            <IconSettings />
            Ayarlar
          </Link>
        </div>
      </aside>

      <div className="main-area">{children}</div>
    </div>
  );
}

export function filterTitle(filter: Filter, tag: string | null): string {
  if (tag) return `#${tag}`;
  return filter === "all" ? "Tüm makaleler" : filter === "unread" ? "Okunmamış" : "Yıldızlı";
}
