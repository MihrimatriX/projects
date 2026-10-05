export function BrandMark({ className = "" }: { className?: string }) {
  return (
    <span
      className={`grid h-9 w-9 place-items-center rounded-[10px] bg-accent text-white shadow-[0_8px_20px_color-mix(in_oklch,var(--accent),transparent_72%)] ${className}`}
      aria-hidden="true"
    >
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="h-5 w-5">
        <path d="M4 6.5h11a4 4 0 0 1 4 4v7H8a4 4 0 0 1-4-4v-7Z" />
        <path d="M8 10h7" />
        <path d="M8 13.5h5" />
      </svg>
    </span>
  );
}
