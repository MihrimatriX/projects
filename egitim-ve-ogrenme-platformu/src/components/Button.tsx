import Link from "next/link";
import type { ButtonHTMLAttributes, ReactNode } from "react";

type Variant = "primary" | "secondary";

const base =
  "inline-flex min-h-10 items-center justify-center gap-2 rounded-[var(--button-radius)] px-3.5 text-sm font-semibold tracking-wide transition hover:-translate-y-px focus-visible:outline-none active:translate-y-px active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-50 disabled:transform-none";

const variants: Record<Variant, string> = {
  primary: "border border-transparent bg-accent text-white hover:bg-accent-hover",
  secondary: "border border-border bg-bg-card text-text-primary hover:border-accent",
};

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; children: ReactNode };

export function Button({ variant = "primary", className = "", children, type = "button", ...props }: ButtonProps) {
  return (
    <button type={type} className={`${base} ${variants[variant]} ${className}`} {...props}>
      {children}
    </button>
  );
}

type LinkButtonProps = { href: string; variant?: Variant; className?: string; children: ReactNode };

export function LinkButton({ href, variant = "primary", className = "", children }: LinkButtonProps) {
  return (
    <Link href={href} className={`${base} ${variants[variant]} ${className}`}>
      {children}
    </Link>
  );
}
