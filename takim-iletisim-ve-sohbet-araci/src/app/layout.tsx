import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Takım Sohbet",
  description: "Self-host takım iletişimi — kanallar, DM, thread, webhook",
  icons: {
    icon: "/icon.svg",
    apple: "/icon-192.png",
  },
};

// Seçili tema ilk boyamadan önce uygulanır (açık temada koyu yanıp sönme olmaz)
const themeScript = `try{if(localStorage.getItem("sohbet-tema")==="light")document.documentElement.dataset.theme="light"}catch(e){}`;

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="tr" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body>{children}</body>
    </html>
  );
}
