import { SiteHeader } from "@/components/SiteHeader";
import { CatalogClient } from "@/components/CatalogClient";
import { STATIC_CATALOG, type CatalogItem } from "@/lib/catalog";
import { courseCover } from "@/lib/covers";
import { ensureSeed } from "@/lib/seed";
import { prisma } from "@/lib/prisma";

// Veritabanından okunur; build sırasında statik HTML'e dondurulmasın (ilerleme her istekte güncel olmalı).
export const dynamic = "force-dynamic";

export default async function KatalogPage() {
  await ensureSeed();

  const courses = await prisma.course.findMany({
    include: { lessons: { orderBy: { order: "asc" }, include: { progress: true } }, quiz: true },
    orderBy: { createdAt: "asc" },
  });

  const dbItems: CatalogItem[] = courses.map((c) => {
    const done = c.lessons.filter((l) => l.progress[0]?.completed).length;
    const progress = c.lessons.length ? Math.round((done / c.lessons.length) * 100) : 0;
    const activeLesson = c.lessons.find((l) => !l.progress[0]?.completed) ?? c.lessons.at(-1);
    return {
      id: c.id,
      title: c.title,
      coverTitle: c.title,
      coverImage: courseCover(c.title, "mobil"),
      description: c.description,
      category: "mobil",
      level: "baslangic",
      levelLabel: "Başlangıç",
      featured: true,
      badge: progress > 0 ? "Kayıtlı" : "Ücretsiz",
      rating: "4.8",
      meta: `${c.lessons.length} ders · ${c.quiz ? "1 quiz" : "quiz yok"}`,
      price: "Ücretsiz",
      enrolled: true,
      action: "continue",
      href: `/course/${c.id}`,
    };
  });

  const items = [...dbItems, ...STATIC_CATALOG.filter((s) => !dbItems.some((d) => d.title === s.title))];
  const primary = courses[0];
  const continueCourse = primary
    ? {
        title: primary.title,
        href: `/course/${primary.id}`,
        coverImage: courseCover(primary.title, "mobil"),
        progress: primary.lessons.length
          ? Math.round(
              (primary.lessons.filter((l) => l.progress[0]?.completed).length / primary.lessons.length) * 100
            )
          : 0,
        lessonHint: (() => {
          const next = primary.lessons.find((l) => !l.progress[0]?.completed);
          return next
            ? `Ders ${next.order}: ${next.title}. Quiz açılmadan önce dersi tamamla.`
            : "Tüm dersler tamamlandı — quiz'e geçebilirsin.";
        })(),
      }
    : undefined;

  return (
    <>
      <SiteHeader current="/katalog" />
      <main id="icerik" className="mx-auto w-[min(100%-2rem,var(--container-max))] px-0 py-[34px] pb-16 max-[680px]:pt-5">
        <CatalogClient items={items} continueCourse={continueCourse} />
      </main>
    </>
  );
}
