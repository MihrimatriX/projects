import { useMemo, useState } from "react";
import type { ConflictResolution, ThreeWayContent } from "../types";

type Props = {
  data: ThreeWayContent;
  onSave: (
    merged: string,
    resolutions: Record<number, ConflictResolution>
  ) => Promise<void>;
};

export function ThreeWayPane({ data, onSave }: Props) {
  const [resolutions, setResolutions] = useState<Record<number, ConflictResolution>>({});
  const [mergedPreview, setMergedPreview] = useState(data.merge.merged);
  const [saving, setSaving] = useState(false);

  const unresolved = useMemo(
    () => data.merge.conflicts.filter((c) => !resolutions[c.index]),
    [data.merge.conflicts, resolutions]
  );

  function pick(index: number, choice: ConflictResolution) {
    const next = { ...resolutions, [index]: choice };
    setResolutions(next);
    const lines = data.merge.merged.split("\n");
    const conflict = data.merge.conflicts.find((c) => c.index === index);
    if (!conflict) return;
    const lineIdx = index - 1;
    if (choice === "left") lines[lineIdx] = conflict.left;
    else if (choice === "right") lines[lineIdx] = conflict.right;
    else if (choice === "base") lines[lineIdx] = conflict.base;
    else lines[lineIdx] = `${conflict.left}\n${conflict.right}`;
    setMergedPreview(lines.join("\n"));
  }

  async function handleSave() {
    setSaving(true);
    try {
      await onSave(mergedPreview, resolutions);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="three-way">
      <div className="three-way-panels">
        <div className="three-way-col">
          <div className="three-way-header">Base</div>
          <pre className="three-way-code">{data.base.slice(0, 8000)}</pre>
        </div>
        <div className="three-way-col">
          <div className="three-way-header">Sol</div>
          <pre className="three-way-code">{data.left.slice(0, 8000)}</pre>
        </div>
        <div className="three-way-col">
          <div className="three-way-header">Sağ</div>
          <pre className="three-way-code">{data.right.slice(0, 8000)}</pre>
        </div>
      </div>
      <div className="merge-section">
        <h4>
          Çakışmalar: {data.merge.conflicts.length} · Otomatik: {data.merge.autoResolved} ·
          Bekleyen: {unresolved.length}
        </h4>
        {data.merge.conflicts.length === 0 ? (
          <p className="merge-empty">Çakışma yok; birleştirilmiş içerik hazır.</p>
        ) : (
          <div className="conflict-list">
            {data.merge.conflicts.map((c) => (
              <div key={c.index} className="conflict-row">
                <span className="conflict-line">Satır {c.index}</span>
                <code className="conflict-snippet">{c.left || "∅"} ↔ {c.right || "∅"}</code>
                <div className="conflict-actions">
                  <button
                    type="button"
                    aria-pressed={resolutions[c.index] === "left"}
                    onClick={() => pick(c.index, "left")}
                  >
                    Sol Al
                  </button>
                  <button
                    type="button"
                    aria-pressed={resolutions[c.index] === "right"}
                    onClick={() => pick(c.index, "right")}
                  >
                    Sağ Al
                  </button>
                  <button
                    type="button"
                    aria-pressed={resolutions[c.index] === "base"}
                    onClick={() => pick(c.index, "base")}
                  >
                    Base
                  </button>
                  <button
                    type="button"
                    aria-pressed={resolutions[c.index] === "both"}
                    onClick={() => pick(c.index, "both")}
                  >
                    Her İkisi
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
        <div className="merge-footer">
          <button
            type="button"
            className="btn btn-primary"
            disabled={saving || unresolved.length > 0}
            onClick={handleSave}
          >
            {saving ? "Kaydediliyor…" : "Birleştirilmiş Dosyayı Kaydet"}
          </button>
          {unresolved.length > 0 && (
            <span className="merge-hint">Tüm çakışmaları çözün.</span>
          )}
        </div>
      </div>
    </div>
  );
}
