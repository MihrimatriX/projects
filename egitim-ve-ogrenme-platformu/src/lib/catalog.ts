import { courseCover } from "./covers";

export type CourseLevel = "baslangic" | "orta" | "ileri";

export type CatalogItem = {
  id?: string;
  title: string;
  coverTitle: string;
  coverImage: string;
  description: string;
  category: string;
  level: CourseLevel;
  levelLabel: string;
  featured: boolean;
  badge: string;
  badgeWarning?: boolean;
  rating: string;
  meta: string;
  price: string;
  enrolled?: boolean;
  action: "continue" | "disabled";
  href?: string;
};

export const STATIC_CATALOG: CatalogItem[] = [
  {
    title: "Next.js App Router ile Marketplace",
    coverTitle: "Next.js Marketplace",
    coverImage: courseCover("Next.js App Router ile Marketplace", "web"),
    description:
      "Route Handlers, Prisma SQLite ve katalog mimarisini üretim öncesi düzene taşı.",
    category: "web",
    level: "orta",
    levelLabel: "Orta",
    featured: true,
    badge: "Yakında",
    badgeWarning: true,
    rating: "Puan bekleniyor",
    meta: "12 ders · 2 quiz",
    price: "₺899",
    action: "disabled",
  },
  {
    title: "Ürün UI Sistemleri",
    coverTitle: "Ürün UI Sistemleri",
    coverImage: courseCover("Ürün UI Sistemleri", "tasarim"),
    description:
      "Token, radius, hover ve erişilebilirlik kararlarını tekrar kullanılabilir bileşenlere bağla.",
    category: "tasarim",
    level: "orta",
    levelLabel: "Orta",
    featured: false,
    badge: "Ücretsiz",
    rating: "4.7",
    meta: "6 ders · 1 ödev",
    price: "Ücretsiz",
    action: "disabled",
  },
  {
    title: "SQLite ile MVP Veri Modeli",
    coverTitle: "SQLite MVP Veri Modeli",
    coverImage: courseCover("SQLite ile MVP Veri Modeli", "veri"),
    description: "Kurs, ders, kayıt ve quiz yanıtlarını Prisma şemasında sade tutma pratiği.",
    category: "veri",
    level: "baslangic",
    levelLabel: "Başlangıç",
    featured: false,
    badge: "Ücretsiz",
    rating: "4.6",
    meta: "5 ders · 1 quiz",
    price: "Ücretsiz",
    action: "disabled",
  },
  {
    title: "Stripe Checkout Temelleri",
    coverTitle: "Stripe Checkout",
    coverImage: courseCover("Stripe Checkout Temelleri", "web"),
    description: "Ödeme akışı, webhook doğrulama ve ücretsiz badge fallback durumunu planla.",
    category: "web",
    level: "ileri",
    levelLabel: "İleri",
    featured: false,
    badge: "Faz 2",
    badgeWarning: true,
    rating: "Puan bekleniyor",
    meta: "9 ders · webhook lab",
    price: "₺699",
    action: "disabled",
  },
  {
    title: "Mux HLS Video Oynatıcı",
    coverTitle: "Mux HLS Video",
    coverImage: courseCover("Mux HLS Video Oynatıcı", "mobil"),
    description: "Poster, spinner, altyazı track ve hata durumunu tek ders yüzeyinde birleştir.",
    category: "mobil",
    level: "ileri",
    levelLabel: "İleri",
    featured: false,
    badge: "Faz 2",
    badgeWarning: true,
    rating: "Puan bekleniyor",
    meta: "7 ders · video lab",
    price: "₺799",
    action: "disabled",
  },
];

export const CATEGORIES = [
  { id: "all", label: "Tümü" },
  { id: "mobil", label: "Mobil" },
  { id: "web", label: "Web" },
  { id: "tasarim", label: "Tasarım" },
  { id: "veri", label: "Veri" },
] as const;
