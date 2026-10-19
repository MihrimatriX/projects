import { useEffect, useState } from "react";
import { IconClose } from "./Icons";
import type { MockRule } from "../types";

type Props = {
  open: boolean;
  endpointId: string | null;
  rules: MockRule[];
  onClose: () => void;
  onSave: (rule: MockRule) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
};

function emptyRule(endpointId: string): MockRule {
  return {
    id: "",
    endpointId,
    method: "POST",
    pathPattern: null,
    statusCode: 200,
    body: '{"received":true}',
    contentType: "application/json",
    priority: 10,
  };
}

export function MockRulesModal({ open, endpointId, rules, onClose, onSave, onDelete }: Props) {
  const [draft, setDraft] = useState<MockRule | null>(null);

  useEffect(() => {
    if (open && endpointId) setDraft(emptyRule(endpointId));
  }, [open, endpointId]);

  if (!open || !endpointId) return null;

  return (
    <div className="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="mock-title" onClick={onClose}>
      <div className="modal wide" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2 id="mock-title">Mock yanıt kuralları</h2>
          <button type="button" className="icon-btn" aria-label="Kapat" onClick={onClose}>
            <IconClose />
          </button>
        </div>
        <div className="modal-body">
          <p className="field-hint">Eşleşen ilk kural (yüksek öncelik) uygulanır.</p>

          {rules.length === 0 && <p className="field-hint">Henüz kural yok; eşleşmeyen isteklere varsayılan 200 yanıtı döner.</p>}
          <ul className="mock-list">
            {rules.map((r) => (
              <li key={r.id} className="mock-item">
                <span>
                  {r.method ?? "*"} {r.pathPattern ?? "*"} → {r.statusCode}
                </span>
                <button
                  type="button"
                  className="icon-btn"
                  aria-label={`Kuralı sil: ${r.method ?? "*"} ${r.pathPattern ?? "*"} → ${r.statusCode}`}
                  onClick={() => void onDelete(r.id)}
                >
                  ×
                </button>
              </li>
            ))}
          </ul>

          {draft && (
            <div className="mock-form">
              <input
                className="input input-mono"
                placeholder="Method (boş = tümü)"
                aria-label="Mock method"
                value={draft.method ?? ""}
                onChange={(e) => setDraft({ ...draft, method: e.target.value || null })}
              />
              <input
                className="input input-mono"
                placeholder="Path regex"
                aria-label="Mock path regex"
                value={draft.pathPattern ?? ""}
                onChange={(e) => setDraft({ ...draft, pathPattern: e.target.value || null })}
              />
              <input
                type="number"
                className="input input-mono"
                placeholder="Status"
                aria-label="Mock durum kodu"
                value={draft.statusCode}
                onChange={(e) => setDraft({ ...draft, statusCode: Number(e.target.value) || 200 })}
              />
              <textarea
                className="input textarea"
                aria-label="Mock yanıt gövdesi"
                rows={3}
                value={draft.body}
                onChange={(e) => setDraft({ ...draft, body: e.target.value })}
              />
            </div>
          )}

          <div className="modal-actions">
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              Kapat
            </button>
            {draft && (
              <button
                type="button"
                className="btn btn-primary"
                style={{ flex: "none" }}
                onClick={async () => {
                  await onSave(draft);
                  setDraft(emptyRule(endpointId));
                }}
              >
                Kural ekle
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
