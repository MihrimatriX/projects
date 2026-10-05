"use client";

import { useEffect, useState } from "react";
import { useJsonStore } from "@/lib/store";

export default function ErrorPanel() {
  const { isValid, error, repairAndParse } = useJsonStore();
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    const toggle = () => setExpanded((v) => !v);
    window.addEventListener("json-toggle-error-panel", toggle);
    return () => window.removeEventListener("json-toggle-error-panel", toggle);
  }, []);

  useEffect(() => {
    if (isValid) setExpanded(false);
  }, [isValid]);

  const hasErrors = !isValid && !!error;

  return (
    <div className={`error-panel${hasErrors ? " has-errors expanded" : ""}${expanded ? " expanded" : ""}`}>
      <div
        className="error-panel-handle"
        role="button"
        tabIndex={0}
        aria-expanded={expanded}
        onClick={() => hasErrors && setExpanded((v) => !v)}
        onKeyDown={(e) => {
          if ((e.key === "Enter" || e.key === " ") && hasErrors) {
            e.preventDefault();
            setExpanded((v) => !v);
          }
        }}
      >
        <svg viewBox="0 0 12 12" fill="currentColor" aria-hidden>
          <path d="M3 4l3 3 3-3" />
        </svg>
        <span>{hasErrors ? "1 hata" : "Hata paneli"}</span>
      </div>
      {hasErrors && error && (
        <div className="error-panel-body" role="alert" aria-live="assertive">
          <div className="error-item" data-line={error.line}>
            <span className="error-loc">
              {error.line}:{error.column}
            </span>
            <span>{error.message}</span>
            <button
              type="button"
              className="btn-ghost"
              data-testid="btn-repair"
              title="Tek tırnak, sondaki virgül ve BOM düzeltilir"
              onClick={repairAndParse}
            >
              Onar
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
