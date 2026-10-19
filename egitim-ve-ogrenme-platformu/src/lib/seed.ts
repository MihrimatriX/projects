import { prisma } from "@/lib/prisma";

const DEMO_TITLE = "Flutter Temelleri";
// Sabit kimlik: eşzamanlı ilk istekler aynı kursu yaratmaya çalışırsa yalnızca biri başarır.
const DEMO_ID = "demo-flutter-temelleri";

const QUIZ = [
  {
    question: "Flutter hangi programlama dilini kullanır?",
    options: ["Java", "Dart", "Kotlin", "Swift"],
    correctIndex: 1,
  },
  {
    question: "Widget ağacında her şey ne olarak modellenir?",
    options: ["Component", "Widget", "Node", "View"],
    correctIndex: 1,
  },
  {
    question: "Basit yerel state için hangi yöntem kullanılır?",
    options: ["Provider only", "setState", "Redux", "Bloc only"],
    correctIndex: 1,
  },
];

const LESSONS = [
  {
    title: "Kurulum ve proje yapısı",
    content:
      "Flutter SDK kurulumu, `flutter create` ve proje klasör yapısı. lib/main.dart giriş noktasıdır.",
  },
  {
    title: "Widget ağacı",
    content:
      "Flutter'da her şey bir widget'tır. StatelessWidget ve StatefulWidget temel yapı taşlarıdır.",
  },
  {
    title: "State yönetimine giriş",
    content:
      "Küçük etkileşimlerde state local kalabilir; quiz sonucu ve ilerleme gibi paylaşılan veriler üst seviyeye taşınmalıdır.",
  },
];

// Demo kursu yoksa tek bir atomik create ile oluşturur (dersler + boş ilerleme + quiz).
// Eski sürümlerin eşzamanlı isteklerle yarattığı kopyaları silerek tek kurs bırakır.
// Sayfalar ve /api/courses her istekte çağırır.
export async function ensureSeed() {
  const dupes = await prisma.course.findMany({
    where: { title: DEMO_TITLE },
    orderBy: { createdAt: "asc" },
  });
  if (dupes.length > 1) {
    await prisma.course.deleteMany({ where: { id: { in: dupes.slice(1).map((c) => c.id) } } });
  }
  if (dupes.length >= 1) return;

  try {
    await prisma.course.create({
      data: {
        id: DEMO_ID,
        title: DEMO_TITLE,
        description:
          "Widget ağacı, state yönetimi ve küçük bir quiz akışıyla mobil temelleri öğren.",
        lessons: {
          create: LESSONS.map((l, i) => ({ ...l, order: i + 1, progress: { create: {} } })),
        },
        quiz: { create: { title: "Quiz: State seçimi", questions: JSON.stringify(QUIZ) } },
      },
    });
  } catch (err) {
    // P2002: başka bir istek aynı anda oluşturdu
    if ((err as { code?: string }).code !== "P2002") throw err;
  }
}
