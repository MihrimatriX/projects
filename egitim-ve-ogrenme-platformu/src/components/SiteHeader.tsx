import Link from "next/link";
import { BrandMark } from "./BrandMark";

const LINKS = [
  { href: "/", label: "Merkez" },
  { href: "/katalog", label: "Katalog" },
  { href: "/ders", label: "Ders" },
  { href: "/egitmen", label: "Eğitmen" },
] as const;

type Props = {
  current?: (typeof LINKS)[number]["href"];
  cta?: { href: string; label: string };
};

export function SiteHeader({ current, cta }: Props) {
  return (
    <header className="sticky top-0 z-10 border-b border-border/90 bg-bg-card/92 backdrop-blur-xl">
      <nav
        className="mx-auto flex min-h-[72px] w-[min(100%-2rem,var(--container-max))] flex-wrap items-center justify-between gap-x-5 gap-y-2 max-[720px]:min-h-0 max-[720px]:py-3.5"
        aria-label="Ana gezinme"
      >
        <Link href="/" className="inline-flex items-center gap-3 font-bold tracking-tight" aria-label="Öğrenim Pazarı ana sayfa">
          <BrandMark />
          <span>Öğrenim Pazarı</span>
        </Link>

        {/* Dar ekranda bağlantılar gizleniyordu (mobil menü yoktu); artık alt satıra iniyor */}
        <div className="order-last flex w-full items-center gap-1.5 overflow-x-auto text-sm font-medium text-text-secondary md:order-none md:w-auto">
          {LINKS.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={current === link.href ? "page" : undefined}
              className={`inline-flex min-h-10 items-center rounded-[var(--button-radius)] px-3 hover:bg-bg-muted hover:text-text-primary focus-visible:bg-bg-muted focus-visible:text-text-primary focus-visible:outline-none ${
                current === link.href ? "bg-bg-muted text-text-primary" : ""
              }`}
            >
              {link.label}
            </Link>
          ))}
        </div>

        {cta && (
          <Link
            href={cta.href}
            className="inline-flex min-h-10 items-center gap-2 rounded-[var(--button-radius)] bg-accent px-3.5 text-sm font-semibold tracking-wide text-white transition hover:-translate-y-px hover:bg-accent-hover focus-visible:outline-none active:translate-y-px active:scale-[0.99]"
          >
            {cta.label}
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" className="h-4 w-4" aria-hidden="true">
              <path d="M5 12h14" />
              <path d="m13 6 6 6-6 6" />
            </svg>
          </Link>
        )}
      </nav>
    </header>
  );
}
