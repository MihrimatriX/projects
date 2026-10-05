import { useEffect, useRef, useState } from "react";
import type { AttachmentInput, MailMessage, MailTemplate } from "../types";
import { applyTemplate, bodyToHtml, extractEmail } from "../format";
import { Modal } from "./Modal";

function errorText(e: unknown) {
  const msg = e instanceof Error ? e.message : String(e);
  return msg.replace(/^Error invoking remote method '[^']+': (Error: )?/, "");
}

type Props = {
  open: boolean;
  mode: "new" | "reply" | "forward" | "draft";
  source?: MailMessage | null;
  draft?: MailMessage | null;
  accountId?: string;
  onClose: () => void;
  onSend: (input: {
    to: string;
    subject: string;
    body: string;
    bodyHtml?: string;
    draftId?: string;
    inReplyTo?: string;
    accountId?: string;
    attachments?: AttachmentInput[];
    requestReadReceipt?: boolean;
    startTracking?: boolean;
    trackingDays?: number;
  }) => Promise<void>;
  onSaveDraft: (input: { to: string; subject: string; body: string; id?: string; accountId?: string }) => Promise<void>;
};

export function ComposeModal({
  open,
  mode,
  source,
  draft,
  accountId,
  onClose,
  onSend,
  onSaveDraft,
}: Props) {
  const [to, setTo] = useState("");
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [templates, setTemplates] = useState<MailTemplate[]>([]);
  const [attachments, setAttachments] = useState<AttachmentInput[]>([]);
  const [requestReadReceipt, setRequestReadReceipt] = useState(false);
  const [startTracking, setStartTracking] = useState(false);
  const [trackingDays, setTrackingDays] = useState(3);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  // Açılıştaki içerik; Esc ile kapatırken değişiklik varsa taslağa kaydedilir (yazılan kaybolmaz).
  const initialRef = useRef("");

  useEffect(() => {
    if (!open) return;
    window.electronAPI.listTemplates().then(setTemplates);
    setAttachments([]);
    setRequestReadReceipt(false);
    setStartTracking(false);
    setError("");

    let init: [string, string, string] = ["", "", ""];
    if (draft) init = [draft.to, draft.subject, draft.body];
    else if (source && mode === "reply")
      init = [
        extractEmail(source.from),
        source.subject.startsWith("Re:") ? source.subject : `Re: ${source.subject}`,
        `\n\n---\n${source.from} yazdı:\n${source.body}`,
      ];
    else if (source && mode === "forward")
      init = [
        "",
        source.subject.startsWith("Fwd:") ? source.subject : `Fwd: ${source.subject}`,
        `\n\n--- İletilen mesaj ---\nKimden: ${source.from}\nKonu: ${source.subject}\n\n${source.body}`,
      ];
    setTo(init[0]);
    setSubject(init[1]);
    setBody(init[2]);
    initialRef.current = JSON.stringify(init);
  }, [open, source, mode, draft]);

  if (!open) return null;

  function requestClose() {
    const dirty = JSON.stringify([to, subject, body]) !== initialRef.current;
    if (dirty && (to.trim() || subject.trim() || body.trim())) void handleSaveDraft();
    else onClose();
  }

  async function handleSend() {
    setSending(true);
    setError("");
    try {
      await onSend({
        to,
        subject,
        body,
        bodyHtml: bodyToHtml(body),
        draftId: draft?.id,
        inReplyTo: mode === "reply" ? source?.id : undefined,
        accountId,
        attachments,
        requestReadReceipt,
        startTracking,
        trackingDays,
      });
      onClose();
    } catch (e) {
      // Gönderim hatası (SMTP, eksik hesap ayarı…) modalda gösterilir; yazılan mesaj kaybolmaz.
      setError(errorText(e));
    } finally {
      setSending(false);
    }
  }

  async function handleSaveDraft() {
    try {
      await onSaveDraft({ to, subject, body, id: draft?.id, accountId });
    } catch (e) {
      setError(errorText(e));
    }
  }

  async function pickAttachments() {
    const picked = await window.electronAPI.pickAttachments();
    setAttachments((prev) => [...prev, ...picked]);
  }

  const title =
    mode === "reply" ? "Yanıtla" : mode === "forward" ? "İlet" : draft ? "Taslak düzenle" : "Yeni mesaj";

  return (
    <Modal title={title} onClose={requestClose} wide closeOnBackdrop={false}>
      <div
        className="compose-form"
        onKeyDown={(e) => {
          if (e.key === "Enter" && (e.ctrlKey || e.metaKey) && to.trim() && !sending) {
            e.preventDefault();
            void handleSend();
          }
        }}
      >
        <label htmlFor="compose-to">Kime</label>
        <input id="compose-to" value={to} onChange={(e) => setTo(e.target.value)} placeholder="alici@ornek.com" />
        <label htmlFor="compose-subject">Konu</label>
        <input id="compose-subject" value={subject} onChange={(e) => setSubject(e.target.value)} />
        <label htmlFor="compose-template">Şablon</label>
        <select
          id="compose-template"
          onChange={(e) => {
            const tpl = templates.find((t) => t.id === e.target.value);
            if (!tpl) return;
            setSubject(applyTemplate(tpl.subject, { konu: subject.replace(/^(Re|Fwd):\s*/, ""), ad: "..." }));
            setBody(applyTemplate(tpl.body, { konu: subject, ad: "..." }));
          }}
          defaultValue=""
        >
          <option value="">Şablon seç…</option>
          {templates.map((t) => (
            <option key={t.id} value={t.id}>
              {t.name}
            </option>
          ))}
        </select>
        <label htmlFor="compose-body">Mesaj</label>
        <textarea id="compose-body" rows={8} value={body} onChange={(e) => setBody(e.target.value)} />
        <div className="compose-options">
          <label className="checkbox-inline">
            <input type="checkbox" checked={requestReadReceipt} onChange={(e) => setRequestReadReceipt(e.target.checked)} />
            Okundu bildirimi iste (etik — gizli pixel yok)
          </label>
          <label className="checkbox-inline">
            <input type="checkbox" checked={startTracking} onChange={(e) => setStartTracking(e.target.checked)} />
            Yanıt takibi başlat
          </label>
          {startTracking && (
            <select aria-label="Takip süresi" value={trackingDays} onChange={(e) => setTrackingDays(Number(e.target.value))}>
              <option value={3}>3 gün</option>
              <option value={5}>5 gün</option>
              <option value={7}>7 gün</option>
            </select>
          )}
        </div>
        <div className="attachment-row">
          <button type="button" className="btn-sm" onClick={pickAttachments}>
            📎 Ek ekle
          </button>
          {attachments.map((a) => (
            <span key={a.path} className="badge badge-attach">
              {a.name}
              <button
                type="button"
                className="link-btn"
                aria-label={`${a.name} ekini kaldır`}
                onClick={() => setAttachments((p) => p.filter((x) => x.path !== a.path))}
              >
                ×
              </button>
            </span>
          ))}
        </div>
        {error && (
          <p className="form-error" role="alert">
            {error}
          </p>
        )}
        <div className="modal-actions">
          <button type="button" className="btn-ghost" onClick={onClose}>
            İptal
          </button>
          <button
            type="button"
            className="btn-ghost"
            onClick={handleSaveDraft}
          >
            Taslak kaydet
          </button>
          <button
            type="button"
            className="btn-primary"
            disabled={sending || !to.trim()}
            onClick={handleSend}
            title="Gönder (Ctrl+Enter)"
          >
            {sending ? "Gönderiliyor…" : "Gönder"}
          </button>
        </div>
      </div>
    </Modal>
  );
}
