type IconProps = { className?: string };

export function IconSwap({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
      <path d="M4 6h8M12 6l-2-2M12 6l-2 2M12 10H4M4 10l2-2M4 10l2 2" />
    </svg>
  );
}

export function IconSidebar({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" aria-hidden>
      <path d="M2 3h5v10H2zM9 3h5v10H9z" />
    </svg>
  );
}

export function IconFile({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2" aria-hidden>
      <path d="M3 2h7l3 3v9H3V2z" />
      <path d="M10 2v3h3" />
    </svg>
  );
}

export function IconFolder({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.2" aria-hidden>
      <path d="M2 3h5l2 2h5v8H2V3z" />
    </svg>
  );
}

export function IconChevron({ className, open }: IconProps & { open?: boolean }) {
  return (
    <svg
      className={`tree-chevron${open ? " open" : ""}${className ? ` ${className}` : ""}`}
      viewBox="0 0 16 16"
      fill="currentColor"
      aria-hidden
    >
      <path d="M6 4l4 4-4 4z" />
    </svg>
  );
}
