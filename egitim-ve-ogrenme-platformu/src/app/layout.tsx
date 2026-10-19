import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Öğrenim Pazarı",
  description: "Türkçe-first eğitim marketplace — katalog, ders ilerlemesi ve quiz",
  icons: {
    icon: [{ url: "/icon.svg", type: "image/svg+xml" }],
    apple: [{ url: "/icon.png" }],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="tr">
      <body>
        <a
          href="#icerik"
          className="fixed left-4 top-4 z-20 -translate-y-[140%] rounded-[var(--button-radius)] bg-text-primary px-3.5 py-2.5 text-sm font-semibold text-text-inverse transition focus:translate-y-0 focus:outline focus:outline-[3px] focus:outline-offset-[3px] focus:outline-[color-mix(in_oklch,var(--accent),white_35%)]"
        >
          İçeriğe atla
        </a>
        {children}
        <footer className="mx-auto flex w-[min(100%-2rem,var(--container-max))] justify-between gap-4 border-t border-border py-6 pb-9 text-sm text-text-secondary max-[720px]:grid">
          <span>Öğrenim Pazarı</span>
          <span>Türkçe-first, self-host edilebilir eğitim marketplace.</span>
        </footer>
      </body>
    </html>
  );
}
