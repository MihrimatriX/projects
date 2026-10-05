"use client";

import { useEffect, useState } from "react";

export function StatusToast({ message }: { message: string | null }) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (!message) return;
    setVisible(true);
    const t = setTimeout(() => setVisible(false), 2200);
    return () => clearTimeout(t);
  }, [message]);

  return (
    <div
      role="status"
      aria-live="polite"
      aria-atomic
      className={`fixed left-1/2 bottom-6 z-[200] -translate-x-1/2 px-4 py-2.5 text-[13px] font-medium text-white bg-[var(--text-primary)] rounded-[var(--radius-md)] shadow-[var(--shadow-card-hover)] transition-[opacity,transform,visibility] duration-[var(--dur-ui)] ${
        visible ? "opacity-100 visible translate-y-0" : "opacity-0 invisible translate-y-3"
      }`}
    >
      {message}
    </div>
  );
}

type SaveState = "idle" | "saving" | "saved" | "error";

export function SaveBanner({ state, message }: { state: SaveState; message: string }) {
  if (state === "idle") return null;

  const tone =
    state === "saving"
      ? "bg-[var(--bg-saving)] text-[#92400e]"
      : state === "saved"
        ? "bg-[var(--bg-saved)] text-[#166534]"
        : "bg-[var(--bg-error)] text-[#991b1b]";

  return (
    <div
      role="status"
      aria-live="polite"
      className={`fixed top-[var(--toolbar-height)] left-1/2 -translate-x-1/2 z-30 px-4 py-2 text-xs font-medium tracking-wide rounded-b-[var(--radius-md)] shadow-[var(--shadow-ui)] transition-[transform,opacity] duration-[var(--dur-modal)] max-md:top-auto max-md:bottom-[calc(var(--toolbar-height)+8px)] ${tone}`}
    >
      {message}
    </div>
  );
}
