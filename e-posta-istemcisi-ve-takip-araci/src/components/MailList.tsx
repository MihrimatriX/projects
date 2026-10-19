import { useRef } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import type { MailFolderView, MailMessage } from "../types";
import { formatMailDate, formatSnoozeLabel, previewBody, senderName } from "../format";
import { IconPlus, IconSearch, IconStar } from "./icons";

const FOLDER_LABELS: Record<MailFolderView, string> = {
  inbox: "Gelen Kutusu",
  unified: "Birleşik Gelen",
  starred: "Yıldızlı",
  sent: "Gönderilmiş",
  drafts: "Taslaklar",
  tracking: "Takip",
  snoozed: "Ertelenen",
  archive: "Arşiv",
  trash: "Çöp",
};

type Props = {
  folder: MailFolderView;
  messages: MailMessage[];
  selectedId: string | null;
  selectedIds: Set<string>;
  search: string;
  bulkMode: boolean;
  multiAccount: boolean;
  onFolderChange: (folder: MailFolderView) => void;
  onCompose: () => void;
  onSearchChange: (value: string) => void;
  onSelect: (msg: MailMessage) => void;
  onToggleSelect: (id: string) => void;
  onStar: (id: string) => void;
  onBulk: (action: string, payload?: unknown) => void;
  onToggleBulk: () => void;
};

export function MailList({
  folder,
  messages,
  selectedId,
  selectedIds,
  search,
  bulkMode,
  multiAccount,
  onFolderChange,
  onCompose,
  onSearchChange,
  onSelect,
  onToggleSelect,
  onStar,
  onBulk,
  onToggleBulk,
}: Props) {
  const parentRef = useRef<HTMLDivElement>(null);
  const virtualizer = useVirtualizer({
    count: messages.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 72,
    overscan: 8,
  });

  const folderLabel = FOLDER_LABELS[folder];
  const emptyTitle = search ? "Eşleşen mail yok" : `${folderLabel} boş`;
  const emptyBody = search
    ? "Aramayı temizleyin veya başka bir klasöre geçin."
    : "Bu klasörde gösterilecek mail yok.";

  return (
    <section className="list-pane">
      <div className="list-header">
        <div className="mobile-list-actions" aria-label="Kompakt posta araçları">
          <select
            className="folder-select"
            value={folder}
            onChange={(e) => onFolderChange(e.target.value as MailFolderView)}
            aria-label="Klasör seç"
          >
            {Object.entries(FOLDER_LABELS).map(([id, label]) => {
              if (id === "unified" && !multiAccount) return null;
              return (
                <option key={id} value={id}>
                  {label}
                </option>
              );
            })}
          </select>
          <button type="button" className="mobile-compose-btn" onClick={onCompose}>
            <IconPlus size={15} />
            Yeni
          </button>
        </div>

        <div className="search-wrap">
          <IconSearch />
          <input
            type="search"
            value={search}
            onChange={(e) => onSearchChange(e.target.value)}
            placeholder="Mail ara… ( / )"
            aria-label="Mail ara"
          />
        </div>

        <div className="list-toolbar">
          <span className="list-count">
            {messages.length} mail
          </span>
          <span>
            <kbd>j</kbd> <kbd>k</kbd> gezin · <kbd>c</kbd> yaz
            {" · "}
            <button type="button" className="toolbar-link" onClick={onToggleBulk}>
              {bulkMode ? "Seçimi kapat" : "Toplu seç"}
            </button>
          </span>
        </div>

        {bulkMode && selectedIds.size > 0 && (
          <div className="bulk-bar">
            <button type="button" onClick={() => onBulk("read")}>Okundu</button>
            <button type="button" onClick={() => onBulk("unread")}>Okunmadı</button>
            <button type="button" onClick={() => onBulk("star")}>Yıldızla</button>
            <button type="button" onClick={() => onBulk("archive")}>Arşivle</button>
            <button
              type="button"
              onClick={() => onBulk("snooze", new Date(Date.now() + 86400000).toISOString())}
            >
              Ertele
            </button>
            <button type="button" onClick={() => onBulk("delete")}>Sil</button>
          </div>
        )}
      </div>

      <div ref={parentRef} className="mail-list" role="list" aria-label={folderLabel}>
        {messages.length === 0 && (
          <div className="empty-state" role="status">
            <div>
              <strong>{emptyTitle}</strong>
              <br />
              <span>{emptyBody}</span>
            </div>
          </div>
        )}

        <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
          {virtualizer.getVirtualItems().map((row) => {
            const msg = messages[row.index];
            const snoozed = msg.snoozedUntil && new Date(msg.snoozedUntil) > new Date();
            const classes = [
              "mail-row",
              !msg.read ? "unread" : "",
              selectedId === msg.id ? "selected" : "",
            ]
              .filter(Boolean)
              .join(" ");

            return (
              <div
                key={msg.id}
                ref={virtualizer.measureElement}
                data-index={row.index}
                className={classes}
                style={{
                  position: "absolute",
                  top: 0,
                  left: 0,
                  width: "100%",
                  transform: `translateY(${row.start}px)`,
                }}
              >
                <div
                  className="mail-row-inner"
                  role="listitem"
                  tabIndex={0}
                  aria-current={selectedId === msg.id ? "true" : undefined}
                  onClick={(e) => {
                    if ((e.target as HTMLElement).closest("[data-star]")) return;
                    if (bulkMode) {
                      onToggleSelect(msg.id);
                      return;
                    }
                    onSelect(msg);
                  }}
                  onKeyDown={(e) => {
                    if (e.key === "Enter" || e.key === " ") {
                      e.preventDefault();
                      if (bulkMode) onToggleSelect(msg.id);
                      else onSelect(msg);
                    }
                  }}
                >
                  {bulkMode ? (
                    <input
                      type="checkbox"
                      checked={selectedIds.has(msg.id)}
                      onChange={() => onToggleSelect(msg.id)}
                      onClick={(e) => e.stopPropagation()}
                      aria-label={`Seç: ${msg.subject}`}
                    />
                  ) : (
                    <span className={`unread-dot${msg.read ? " read" : ""}`} aria-hidden />
                  )}

                  <div className="mail-content">
                    <div className="mail-top">
                      <span className="mail-from">{senderName(msg.from)}</span>
                      <span className="mail-date">{formatMailDate(msg.date)}</span>
                    </div>
                    <div className="mail-subject">{msg.subject}</div>
                    <div className="mail-preview">{previewBody(msg.body)}</div>
                    {(msg.tracking?.waitingReply || snoozed || (msg.attachments?.length ?? 0) > 0) && (
                      <div className="mail-badges">
                        {msg.tracking?.waitingReply && (
                          <span className="badge badge-wait">Yanıt bekleniyor</span>
                        )}
                        {snoozed && msg.snoozedUntil && (
                          <span className="badge badge-snooze">
                            Snooze: {formatSnoozeLabel(msg.snoozedUntil)}
                          </span>
                        )}
                        {(msg.attachments?.length ?? 0) > 0 && (
                          <span className="badge badge-attach">📎 {msg.attachments!.length}</span>
                        )}
                      </div>
                    )}
                  </div>

                  <button
                    type="button"
                    className={`star-btn${msg.starred ? " starred" : ""}`}
                    data-star={msg.id}
                    aria-label={msg.starred ? "Yıldızı kaldır" : "Yıldızla"}
                    aria-pressed={msg.starred}
                    onClick={(e) => {
                      e.stopPropagation();
                      onStar(msg.id);
                    }}
                  >
                    <IconStar size={16} filled={msg.starred} />
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
