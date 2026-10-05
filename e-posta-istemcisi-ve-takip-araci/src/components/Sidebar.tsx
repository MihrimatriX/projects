import type { Account, FolderCounts, MailFolderView, MailMessage } from "../types";
import { trackingDaysLeft, senderName } from "../format";
import {
  IconArchive,
  IconDrafts,
  IconInbox,
  IconMoon,
  IconPlus,
  IconSent,
  IconStar,
  IconTracking,
  IconTrash,
  IconUnified,
} from "./icons";

type Props = {
  folder: MailFolderView;
  counts: FolderCounts;
  tracking: MailMessage[];
  multiAccount: boolean;
  account: Pick<Account, "displayName" | "email"> | null;
  onFolderChange: (folder: MailFolderView) => void;
  onCompose: () => void;
  onOpenMessage: (id: string) => void;
};

const NAV: { id: MailFolderView; label: string; icon: React.ReactNode }[] = [
  { id: "inbox", label: "Gelen Kutusu", icon: <IconInbox /> },
  { id: "unified", label: "Birleşik Gelen", icon: <IconUnified /> },
  { id: "starred", label: "Yıldızlı", icon: <IconStar /> },
  { id: "sent", label: "Gönderilmiş", icon: <IconSent /> },
  { id: "drafts", label: "Taslaklar", icon: <IconDrafts /> },
  { id: "tracking", label: "Takip", icon: <IconTracking /> },
  { id: "snoozed", label: "Ertelenen", icon: <IconMoon /> },
  { id: "archive", label: "Arşiv", icon: <IconArchive /> },
  { id: "trash", label: "Çöp", icon: <IconTrash /> },
];

const BADGE_FOLDERS = new Set<MailFolderView>(["inbox", "unified", "drafts", "starred", "tracking", "snoozed"]);

export function Sidebar({
  folder,
  counts,
  tracking,
  multiAccount,
  account,
  onFolderChange,
  onCompose,
  onOpenMessage,
}: Props) {
  const initial = (account?.displayName || account?.email || "?").charAt(0).toUpperCase();

  return (
    <nav className="sidebar" aria-label="Klasörler">
      <div className="account-row">
        <div className="avatar" aria-hidden>
          {initial}
        </div>
        <div>
          <div className="account-name">{account?.displayName || "Hesap ekle"}</div>
          <div className="account-email">{account?.email || "Ayarlar → hesap bağla"}</div>
        </div>
      </div>

      <button type="button" className="compose-btn" onClick={onCompose}>
        <IconPlus />
        Yeni Mail
      </button>

      <ul className="nav-list">
        {NAV.map((item) => {
          if (item.id === "unified" && !multiAccount) return null;
          const count = counts[item.id];
          return (
            <li key={item.id}>
              <button
                type="button"
                className={`nav-item${folder === item.id ? " active" : ""}`}
                onClick={() => onFolderChange(item.id)}
                aria-current={folder === item.id ? "page" : undefined}
              >
                {item.icon}
                <span>{item.label}</span>
                {count > 0 && BADGE_FOLDERS.has(item.id) && (
                  <span className="nav-badge">{count}</span>
                )}
              </button>
            </li>
          );
        })}
      </ul>

      {tracking.length > 0 && (
        <div className="tracking-panel">
          <h4>Takip Paneli</h4>
          {tracking.slice(0, 4).map((msg) => {
            const days =
              msg.tracking?.waitingReply && msg.tracking.startedAt
                ? trackingDaysLeft(msg.tracking.startedAt, msg.tracking.reminderDays)
                : 0;
            return (
              <button
                key={msg.id}
                type="button"
                className="track-item"
                onClick={() => onOpenMessage(msg.id)}
              >
                <IconTracking size={14} />
                <span>
                  {senderName(msg.folder === "sent" ? msg.to : msg.from)} — {msg.subject.slice(0, 28)}
                  <span className="track-meta">
                    {" "}
                    · {days === 0 ? "süre doldu" : `${days} gün`}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      )}
    </nav>
  );
}
