"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { APP_SCREENS, type AppScreenHref } from "./screens";

export default function ToolbarNav({ active }: { active: AppScreenHref }) {
  const pathname = usePathname();

  return (
    <nav className="toolbar-nav" aria-label="Ekran gezintisi">
      {APP_SCREENS.map((p) => {
        const isActive = p.href === active || (p.href !== "/" && pathname === p.href);
        return (
          <Link key={p.href} href={p.href} className={isActive ? "active" : undefined}>
            {p.label}
          </Link>
        );
      })}
    </nav>
  );
}
