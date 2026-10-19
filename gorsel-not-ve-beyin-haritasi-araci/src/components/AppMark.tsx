type Props = { size?: "sm" | "md"; className?: string };

export function AppMark({ size = "md", className = "" }: Props) {
  const box = size === "sm" ? "w-7 h-7 rounded-[var(--radius-sm)]" : "w-10 h-10 rounded-[var(--radius-md)]";
  const icon = size === "sm" ? "w-4 h-4" : "w-[22px] h-[22px]";

  return (
    <span
      className={`${box} shrink-0 grid place-items-center bg-[var(--bg-ui)] border border-[var(--border)] shadow-[var(--shadow-ui)] ${className}`}
      aria-hidden
    >
      <svg className={`${icon} stroke-[var(--accent)] fill-none`} viewBox="0 0 24 24" strokeWidth="1.5">
        <rect x="3" y="3" width="8" height="6" rx="1.5" />
        <rect x="13" y="3" width="8" height="6" rx="1.5" />
        <rect x="8" y="13" width="8" height="8" rx="1.5" />
        <path d="M11 9v2M13 9v4" />
      </svg>
    </span>
  );
}

export function IconPlus({ className = "w-[18px] h-[18px]" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden stroke="currentColor" fill="none" strokeWidth="1.5">
      <path d="M12 5v14M5 12h14" />
    </svg>
  );
}

export function IconExport({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden stroke="currentColor" fill="none" strokeWidth="1.5">
      <path d="M12 3v12M8 11l4 4 4-4M5 19h14" />
    </svg>
  );
}

export function IconCheck({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden stroke="currentColor" fill="none" strokeWidth="2">
      <path d="M5 12l5 5L20 7" />
    </svg>
  );
}

export function IconMenu({ className = "w-5 h-5" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden stroke="currentColor" fill="none" strokeWidth="1.5">
      <path d="M4 6h16M4 12h16M4 18h16" />
    </svg>
  );
}

export function IconClose({ className = "w-4 h-4" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" aria-hidden stroke="currentColor" fill="none" strokeWidth="1.5">
      <path d="M6 6l12 12M18 6L6 18" />
    </svg>
  );
}
