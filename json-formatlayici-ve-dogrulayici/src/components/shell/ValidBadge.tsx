"use client";

import { useJsonStore } from "@/lib/store";

export default function ValidBadge() {
  const { rawJson, isValid, error, duplicateKeys } = useJsonStore();

  if (!rawJson.trim()) {
    return (
      <span className="valid-badge" role="status" aria-live="polite">
        <span className="dot" aria-hidden />
        Bekliyor
      </span>
    );
  }

  if (isValid) {
    const warn = duplicateKeys.length > 0;
    return (
      <span className={`valid-badge valid${warn ? " warning" : ""}`} role="status" aria-live="polite">
        <span className="dot" aria-hidden />
        {warn ? `Yinelenen anahtar: ${duplicateKeys.length}` : "Geçerli JSON"}
      </span>
    );
  }

  return (
    <span
      className="valid-badge invalid"
      role="button"
      tabIndex={0}
      aria-live="polite"
      aria-label={`Hata: satır ${error?.line}, sütun ${error?.column}`}
      onClick={() => window.dispatchEvent(new Event("json-toggle-error-panel"))}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          window.dispatchEvent(new Event("json-toggle-error-panel"));
        }
      }}
    >
      <span className="dot" aria-hidden />
      Satır {error?.line}:{error?.column}
    </span>
  );
}
