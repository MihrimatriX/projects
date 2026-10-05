export const COVER_BY_TITLE: Record<string, string> = {
  "Flutter Temelleri": "/covers/flutter.svg",
  "Next.js App Router ile Marketplace": "/covers/nextjs.svg",
  "Ürün UI Sistemleri": "/covers/ui-systems.svg",
  "SQLite ile MVP Veri Modeli": "/covers/sqlite.svg",
  "Stripe Checkout Temelleri": "/covers/stripe.svg",
  "Mux HLS Video Oynatıcı": "/covers/video.svg",
};

export function courseCover(title: string, category = "mobil"): string {
  return COVER_BY_TITLE[title] ?? `/covers/${category}.svg`;
}
