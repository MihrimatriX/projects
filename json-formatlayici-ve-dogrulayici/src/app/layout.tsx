import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import AppInit from "@/components/AppInit";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
});

export const metadata: Metadata = {
  title: "JSON Formatlayıcı ve Doğrulayıcı",
  description:
    "JSON verilerinizi tarayıcıda yerel olarak formatlayın, doğrulayın, minify edin ve ağaç görünümünde inceleyin. Sunucuya veri gönderilmez.",
  keywords: [
    "json formatter",
    "json validator",
    "json lint",
    "json pretty print",
    "formatlayıcı",
    "doğrulayıcı",
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="tr" className={`${inter.variable} ${jetbrainsMono.variable}`} suppressHydrationWarning>
      <body className="antialiased">
        <AppInit>{children}</AppInit>
      </body>
    </html>
  );
}
