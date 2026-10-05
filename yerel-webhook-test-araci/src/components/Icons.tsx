type IconProps = { className?: string };

export function IconSettings({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
    </svg>
  );
}

export function IconCopy({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden>
      <rect x="9" y="9" width="13" height="13" rx="2" />
      <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
    </svg>
  );
}

export function IconReplay({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden>
      <path d="M1 4v6h6" />
      <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
    </svg>
  );
}

export function IconClose({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden>
      <path d="M18 6L6 18M6 6l12 12" />
    </svg>
  );
}

export function IconMenu({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden>
      <path d="M3 12h18M3 6h18M3 18h18" />
    </svg>
  );
}

export function IconMock({ className }: IconProps) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" aria-hidden>
      <path d="M4 7h16M4 12h10M4 17h14" />
      <circle cx="19" cy="17" r="2" />
    </svg>
  );
}
