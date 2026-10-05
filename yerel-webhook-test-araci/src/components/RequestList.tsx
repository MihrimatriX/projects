import { useRef, useState } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import { MethodBadge } from "./MethodBadge";
import { relativeTime } from "../lib/time";
import { filterActive } from "../lib/filterRequests";
import type { RequestFilters, WebhookRequest } from "../types";

type Props = {
  requests: WebhookRequest[];
  selectedId: string | null;
  newId: string | null;
  filters: RequestFilters;
  onSelect: (id: string) => void;
  onClear: () => void;
};

export function RequestList({ requests, selectedId, newId, filters, onSelect, onClear }: Props) {
  const parentRef = useRef<HTMLDivElement>(null);
  const [confirmClear, setConfirmClear] = useState(false);
  const virtualizer = useVirtualizer({
    count: requests.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 44,
    overscan: 12,
  });

  const filterNote = filterActive(filters) ? " · filtre aktif" : "";

  return (
    <>
      <div className="requests-scroll" ref={parentRef} role="listbox" aria-label="İstekler" aria-live="polite">
        {requests.length === 0 ? (
          <p className="empty-list">
            {filterActive(filters)
              ? "Filtreyle eşleşen istek yok."
              : "Henüz istek yok. Webhook URL'ine istek gönderin."}
          </p>
        ) : (
          <div style={{ height: virtualizer.getTotalSize(), position: "relative", width: "100%" }}>
            {virtualizer.getVirtualItems().map((item) => {
              const r = requests[item.index];
              return (
                <button
                  key={r.id}
                  type="button"
                  role="option"
                  aria-selected={selectedId === r.id}
                  className={`request-row ${selectedId === r.id ? "selected" : ""} ${newId === r.id ? "new-flash" : ""}`}
                  style={{
                    position: "absolute",
                    top: 0,
                    left: 0,
                    width: "100%",
                    height: `${item.size}px`,
                    transform: `translateY(${item.start}px)`,
                  }}
                  onClick={() => onSelect(r.id)}
                >
                  <MethodBadge method={r.method} />
                  <span className="request-path">{r.url}</span>
                  <span className="request-time">{relativeTime(r.timestamp)}</span>
                </button>
              );
            })}
          </div>
        )}
      </div>
      <div className="list-status">
        <span>
          {requests.length} istek{filterNote}
        </span>
        {requests.length > 0 && (
          // Kalıcı silme: ilk tık onay ister, ikinci tık bu endpoint'in tüm isteklerini siler.
          <button
            type="button"
            className="filter-clear"
            onClick={() => {
              if (!confirmClear) return setConfirmClear(true);
              setConfirmClear(false);
              onClear();
            }}
            onBlur={() => setConfirmClear(false)}
          >
            {confirmClear ? "Emin misiniz? Tümünü sil" : "Tüm istekleri sil"}
          </button>
        )}
      </div>
    </>
  );
}
