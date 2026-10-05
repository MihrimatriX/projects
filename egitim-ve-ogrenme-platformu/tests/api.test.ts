import { beforeAll, describe, expect, it } from "vitest";
import { prisma } from "@/lib/prisma";
import { ensureSeed } from "@/lib/seed";
import { GET as listCourses } from "@/app/api/courses/route";
import { GET as getCourse } from "@/app/api/courses/[id]/route";
import { POST as submitQuiz } from "@/app/api/courses/[id]/quiz/submit/route";
import { POST as resetCourse } from "@/app/api/courses/[id]/reset/route";
import { POST as completeLesson } from "@/app/api/lessons/[id]/complete/route";

const ctx = (id: string) => ({ params: Promise.resolve({ id }) });
const req = (body?: unknown) =>
  new Request("http://test/", { method: "POST", body: body === undefined ? undefined : JSON.stringify(body) });

let courseId = "";
let lessonIds: string[] = [];

beforeAll(async () => {
  // Bos veritabaninda eszamanli ilk istekler tek demo kurs birakmali
  await Promise.all([ensureSeed(), ensureSeed(), ensureSeed()]);
  const course = await prisma.course.findFirstOrThrow({ include: { lessons: { orderBy: { order: "asc" } } } });
  courseId = course.id;
  lessonIds = course.lessons.map((l) => l.id);
});

describe("kurs API", () => {
  it("demo kursu bir kez olusturur ve ilerlemeyi listeler", async () => {
    await ensureSeed();
    const data = await (await listCourses()).json();
    expect(data.courses).toHaveLength(1);
    expect(data.courses[0]).toMatchObject({ title: "Flutter Temelleri", lessons: 3, progress: 0, hasQuiz: true });
  });

  it("kurs detayi dogru cevaplari istemciye gondermez", async () => {
    const data = await (await getCourse(req(), ctx(courseId))).json();
    expect(data.course.quiz.questions).toHaveLength(3);
    expect(JSON.stringify(data.course.quiz)).not.toContain("correctIndex");
    expect((await getCourse(req(), ctx("yok"))).status).toBe(404);
  });

  it("olmayan ders icin 404 doner (500 degil)", async () => {
    expect((await completeLesson(req(), ctx("olmayan-ders"))).status).toBe(404);
  });

  it("dersler bitmeden quiz gonderimi sunucuda reddedilir", async () => {
    const res = await submitQuiz(req({ answers: [1, 1, 1] }), ctx(courseId));
    expect(res.status).toBe(403);
    expect(await prisma.quizAttempt.count()).toBe(0);
  });

  it("tum dersler bitince quiz puanlanir, eksik/bozuk cevap reddedilir, gecmis ve en iyi sonuc doner", async () => {
    for (const id of lessonIds) expect((await completeLesson(req(), ctx(id))).status).toBe(200);

    expect((await submitQuiz(req({ answers: [1] }), ctx(courseId))).status).toBe(400);
    expect((await submitQuiz(new Request("http://test/", { method: "POST", body: "{bozuk" }), ctx(courseId))).status).toBe(400);
    expect((await submitQuiz(req({ answers: [1, 1, 1] }), ctx("yok"))).status).toBe(404);

    const ok = await (await submitQuiz(req({ answers: [1, 1, 1] }), ctx(courseId))).json();
    expect(ok).toMatchObject({ score: 3, total: 3, percent: 100 });
    const partial = await (await submitQuiz(req({ answers: [0, 1, 0] }), ctx(courseId))).json();
    expect(partial).toMatchObject({ score: 1, total: 3, percent: 33, correct: [false, true, false] });

    const { course } = await (await getCourse(req(), ctx(courseId))).json();
    expect(course.quiz.attempts.map((a: { score: number }) => a.score)).toEqual([1, 3]);
    expect(course.quiz.bestPercent).toBe(100);
  });

  it("ilerlemeyi sifirlar, quiz gecmisini korur", async () => {
    expect((await resetCourse(req(), ctx("yok"))).status).toBe(404);
    expect((await resetCourse(req(), ctx(courseId))).status).toBe(200);
    const data = await (await listCourses()).json();
    expect(data.courses[0].progress).toBe(0);
    expect(await prisma.quizAttempt.count()).toBe(2);
    expect((await submitQuiz(req({ answers: [1, 1, 1] }), ctx(courseId))).status).toBe(403);
  });
});
