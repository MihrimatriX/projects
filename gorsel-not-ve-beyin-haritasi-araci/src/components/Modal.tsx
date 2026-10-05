"use client";

import { useEffect, useId, useRef } from "react";

type Props = {
  open: boolean;
  onClose: () => void;
  title: string;
  titleId?: string;
  children: React.ReactNode;
  role?: "dialog" | "alertdialog";
  describedBy?: string;
};

export function Modal({ open, onClose, title, titleId, children, role = "dialog", describedBy }: Props) {
  const fallbackId = useId();
  const headingId = titleId ?? fallbackId;
  const lastFocused = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) return;
    lastFocused.current = document.activeElement as HTMLElement | null;
    document.body.style.overflow = "hidden";

    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") onClose();
    }
    document.addEventListener("keydown", onKey);
    return () => {
      document.body.style.overflow = "";
      document.removeEventListener("keydown", onKey);
      lastFocused.current?.focus?.();
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-[rgba(15,23,42,0.4)] animate-[reveal-in_var(--dur-modal)_var(--ease-out)_forwards]"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div
        role={role}
        aria-modal
        aria-labelledby={headingId}
        aria-describedby={describedBy}
        className="w-full max-w-[400px] rounded-[var(--radius-lg)] bg-[var(--bg-ui)] p-6 shadow-[0_20px_40px_rgba(0,0,0,0.12)]"
      >
        <h2 id={headingId} className="text-lg font-semibold tracking-tight mb-4">
          {title}
        </h2>
        {children}
      </div>
    </div>
  );
}

export function ModalActions({ children }: { children: React.ReactNode }) {
  return <div className="flex justify-end gap-2">{children}</div>;
}

export function BtnGhost({ children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      className="px-3.5 py-2 text-[13px] font-medium text-[var(--text-secondary)] rounded-[var(--radius-sm)] tracking-wide transition-[background,transform] duration-[var(--dur-fast)] hover:bg-[var(--bg-hover)] active:scale-[0.98]"
      {...props}
    >
      {children}
    </button>
  );
}

export function BtnPrimary({
  children,
  compact,
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { compact?: boolean }) {
  return (
    <button
      type="submit"
      className={`inline-flex items-center gap-2 font-medium text-white bg-[var(--accent)] rounded-[var(--radius-md)] tracking-wide transition-[background,transform] duration-[var(--dur-fast)] hover:bg-[var(--accent-hover)] active:scale-[0.98] ${
        compact ? "px-3.5 py-2 text-[13px] rounded-[var(--radius-sm)]" : "px-4 py-2.5 text-[13px]"
      }`}
      {...props}
    >
      {children}
    </button>
  );
}

export function BtnDanger({ children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      className="px-3.5 py-2 text-[13px] font-medium text-white bg-[var(--danger)] rounded-[var(--radius-sm)] tracking-wide transition-[filter,transform] duration-[var(--dur-fast)] hover:brightness-95 active:scale-[0.98]"
      {...props}
    >
      {children}
    </button>
  );
}

export function FieldLabel({ htmlFor, children }: { htmlFor: string; children: React.ReactNode }) {
  return (
    <label htmlFor={htmlFor} className="block text-xs font-medium text-[var(--text-secondary)] mb-1.5 tracking-wide">
      {children}
    </label>
  );
}

export function FieldInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className="w-full px-3 py-2.5 mb-5 text-sm border border-[var(--border)] rounded-[var(--radius-sm)] bg-[var(--bg-ui)] transition-[border-color,box-shadow] duration-[var(--dur-fast)] focus:outline-none focus:border-[var(--border-focus)] focus:shadow-[var(--focus-ring)]"
      {...props}
    />
  );
}
