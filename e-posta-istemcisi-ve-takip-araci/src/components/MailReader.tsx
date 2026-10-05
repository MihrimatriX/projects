import { useMemo } from "react";
import type { MailMessage } from "../types";
import { formatFullDate } from "../format";
import { IconBack, IconForward, IconReply } from "./icons";
import { SnoozePicker } from "./SnoozePicker";

type Props = {
  message: MailMessage | null;
  overlay?: boolean;
  onReply: (msg: MailMessage) => void;
  onForward: (msg: MailMessage) => void;
  onStar: (id: string) => void;
  onArchive: (id: string) => void;
  onDelete: (id: string) => void;
  onSnooze: (id: string, until: string) => void;
  onToggleTrack: (msg: MailMessage) => void;
  onMarkUnread: (id: string) => void;
  onRestore: (id: string) => void;
  onClose?: () => void;
};

export function MailReader({
  message,
  overlay,
  onReply,
  onForward,
  onStar,
  onArchive,
  onDelete,
  onSnooze,
  onToggleTrack,
  onMarkUnread,
  onRestore,
  onClose,
}: Props) {
  // HTML gövde script'siz sandbox iframe'de gösterilir; CSP dış kaynakları (izleme pikseli, uzak
  // görsel/CSS/font) engeller — yalnızca gömülü data: görseller ve satır içi stil yüklenir.
  const sandboxHtml = useMemo(() => {
    if (!message?.bodyHtml) return null;
    return `<!DOCTYPE html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: cid:; style-src 'unsafe-inline'"><base target="_blank"><style>html{background:#fff}body{font-family:system-ui,sans-serif;font-size:15px;line-height:1.6;margin:12px;color:#111827}a{color:#2563eb}img{max-width:100%}</style></head><body>${message.bodyHtml}</body></html>`;
  }, [message?.bodyHtml]);

  if (!message) {
    return (
      <main className="reader">
        <div className="reader-empty">
          Bir mail seçin veya <kbd>j</kbd> ile gezin
        </div>
      </main>
    );
  }

  const tracking = Boolean(message.tracking?.waitingReply);
  const snoozed = Boolean(message.snoozedUntil && new Date(message.snoozedUntil) > new Date());

  return (
    <main className={`reader${overlay ? " reader-overlay" : ""}`}>
      <div className="reader-content">
        <header className="reader-header">
          {onClose && (
            <button type="button" className="reader-back" onClick={onClose}>
              <IconBack />
              Gelen kutusuna dön
            </button>
          )}
          <h1 className="reader-subject">{message.subject}</h1>
          <div className="reader-meta">
            {message.from} → {message.to} · {formatFullDate(message.date)}
          </div>
          {message.attachments && message.attachments.length > 0 && (
            <div className="attachment-list">
              {message.attachments.map((a) => (
                <span key={a.name} className="badge badge-attach">
                  📎 {a.name} ({Math.round(a.size / 1024)} KB)
                </span>
              ))}
            </div>
          )}
          {message.tracking?.repliedAt && !tracking && (
            <div className="safe-html-note">Yanıt geldi · {formatFullDate(message.tracking.repliedAt)} — takip otomatik kapatıldı</div>
          )}
          {snoozed && message.snoozedUntil && (
            <div className="safe-html-note">Ertelendi · {formatFullDate(message.snoozedUntil)} tarihinde gelen kutusuna döner</div>
          )}
          {sandboxHtml && (
            <div className="safe-html-note">Güvenli HTML görünümü · dış içerik engelli</div>
          )}
          <div className="reader-actions">
            <button type="button" className="btn-sm" onClick={() => onReply(message)}>
              <IconReply />
              Yanıtla
            </button>
            <button type="button" className="btn-sm" onClick={() => onForward(message)}>
              <IconForward />
              İlet
            </button>
            <button
              type="button"
              className="btn-sm"
              aria-pressed={message.starred}
              onClick={() => onStar(message.id)}
            >
              {message.starred ? "Yıldızı kaldır" : "Yıldızla"}
            </button>
            <SnoozePicker onPick={(iso) => onSnooze(message.id, iso)} />
            <button
              type="button"
              className="btn-sm"
              aria-pressed={tracking}
              onClick={() => onToggleTrack(message)}
            >
              {tracking ? "Takibi bırak" : "Takip et"}
            </button>
            {message.folder !== "trash" && !message.archived && (
              <button type="button" className="btn-sm" onClick={() => onArchive(message.id)}>
                Arşivle
              </button>
            )}
            {(message.folder === "trash" || message.archived || snoozed) && (
              <button type="button" className="btn-sm" onClick={() => onRestore(message.id)}>
                {message.folder === "trash" ? "Geri yükle" : "Gelen kutusuna taşı"}
              </button>
            )}
            <button type="button" className="btn-sm" onClick={() => onMarkUnread(message.id)}>
              Okunmadı
            </button>
            <button type="button" className="btn-sm danger" onClick={() => onDelete(message.id)}>
              {message.folder === "trash" ? "Kalıcı sil" : "Sil"}
            </button>
          </div>
        </header>
        {sandboxHtml ? (
          <iframe className="reader-iframe" sandbox="" title="Mail içeriği" srcDoc={sandboxHtml} />
        ) : (
          <div className="reader-body">{message.body}</div>
        )}
      </div>
    </main>
  );
}
