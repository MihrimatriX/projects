import { useEffect, useRef, useState } from "react";
import { snoozeNextWeek, snoozeTonight, snoozeTomorrowMorning } from "../format";

type Props = {
  onPick: (iso: string) => void;
};

export function SnoozePicker({ onPick }: Props) {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onDocClick(e: MouseEvent) {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("click", onDocClick);
    return () => document.removeEventListener("click", onDocClick);
  }, [open]);

  function pick(iso: string) {
    onPick(iso);
    setOpen(false);
  }

  return (
    <div
      className="snooze-wrap"
      ref={wrapRef}
      onKeyDown={(e) => {
        if (e.key === "Escape" && open) {
          e.stopPropagation();
          setOpen(false);
        }
      }}
    >
      <button
        type="button"
        className="btn-sm"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={(e) => {
          e.stopPropagation();
          setOpen((v) => !v);
        }}
      >
        Ertele
      </button>
      {open && (
        <div className="snooze-menu" role="menu">
          <button type="button" role="menuitem" onClick={() => pick(snoozeTonight())}>
            {new Date().getHours() >= 18 ? "Yarın akşam 18:00" : "Bu akşam 18:00"}
          </button>
          <button type="button" role="menuitem" onClick={() => pick(snoozeTomorrowMorning())}>
            Yarın 09:00
          </button>
          <button type="button" role="menuitem" onClick={() => pick(snoozeNextWeek())}>
            Gelecek hafta
          </button>
          <input
            type="datetime-local"
            aria-label="Özel tarih"
            onChange={(e) => {
              if (!e.target.value) return;
              pick(new Date(e.target.value).toISOString());
            }}
          />
        </div>
      )}
    </div>
  );
}
