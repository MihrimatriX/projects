import { useEffect, useState } from "react";
import type { MailTemplate } from "../types";
import { Modal } from "./Modal";

type Props = {
  open: boolean;
  onClose: () => void;
};

export function TemplatesModal({ open, onClose }: Props) {
  const [templates, setTemplates] = useState<MailTemplate[]>([]);
  const [editing, setEditing] = useState<MailTemplate | null>(null);

  useEffect(() => {
    if (open) window.electronAPI.listTemplates().then(setTemplates);
  }, [open]);

  if (!open) return null;

  async function save() {
    if (!editing) return;
    await window.electronAPI.saveTemplate(editing);
    setTemplates(await window.electronAPI.listTemplates());
    setEditing(null);
  }

  async function remove(id: string) {
    await window.electronAPI.deleteTemplate(id);
    setTemplates(await window.electronAPI.listTemplates());
  }

  return (
    <Modal title="Şablonlar" onClose={onClose} wide closeOnBackdrop={!editing}>
        <p className="hint">Değişkenler: {"{ad}"}, {"{konu}"}</p>
        {templates.length === 0 && <p className="hint">Henüz şablon yok.</p>}
        <ul className="template-list">
          {templates.map((t) => (
            <li key={t.id}>
              <strong>{t.name}</strong>
              <span>{t.subject}</span>
              <button type="button" className="btn-sm" aria-label={`${t.name} şablonunu düzenle`} onClick={() => setEditing({ ...t })}>
                Düzenle
              </button>
              <button type="button" className="btn-sm danger" aria-label={`${t.name} şablonunu sil`} onClick={() => remove(t.id)}>
                Sil
              </button>
            </li>
          ))}
        </ul>
        <button
          type="button"
          className="btn-secondary"
          onClick={() =>
            setEditing({
              id: `tpl-${Date.now()}`,
              name: "Yeni şablon",
              subject: "Re: {konu}",
              body: "Merhaba {ad},\n\n",
            })
          }
        >
          + Yeni şablon
        </button>
        {editing && (
          <div className="account-card">
            <label htmlFor="tpl-name">Ad</label>
            <input id="tpl-name" value={editing.name} onChange={(e) => setEditing({ ...editing, name: e.target.value })} />
            <label htmlFor="tpl-subject">Konu</label>
            <input id="tpl-subject" value={editing.subject} onChange={(e) => setEditing({ ...editing, subject: e.target.value })} />
            <label htmlFor="tpl-body">Gövde</label>
            <textarea id="tpl-body" rows={6} value={editing.body} onChange={(e) => setEditing({ ...editing, body: e.target.value })} />
            <div className="modal-actions">
              <button type="button" className="btn-ghost" onClick={() => setEditing(null)}>
                Vazgeç
              </button>
              <button type="button" className="btn-primary" disabled={!editing.name.trim()} onClick={save}>
                Şablonu kaydet
              </button>
            </div>
          </div>
        )}
        <div className="modal-actions">
          <button type="button" className="btn-sm" onClick={onClose}>
            Kapat
          </button>
        </div>
    </Modal>
  );
}
