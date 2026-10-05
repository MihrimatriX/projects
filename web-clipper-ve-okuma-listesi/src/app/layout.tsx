import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Kayıtlı Okuma — Web Clipper ve Okuma Listesi",
  description: "Pocket tarzı self-host okuma listesi — MV3 eklenti ile tek tıkla kaydet, temiz okuma modu.",
  icons: {
    icon: "/icon.svg",
    apple: "/apple-touch-icon.png",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tr">
      <body>{children}</body>
    </html>
  );
}
