import { expect, test } from "@playwright/test";

test("dersleri tamamla, quiz'i coz, gecmisi gor, ilerlemeyi sifirla", async ({ page, request }) => {
  // Sunucu onceki calistirmadan kalmis olabilir: ilerlemeyi API ile sifirla.
  const { courses } = await (await request.get("/api/courses")).json();
  const id = courses[0].id as string;
  expect((await request.post(`/api/courses/${id}/reset`)).ok()).toBeTruthy();

  await page.goto("/ders");
  await expect(page).toHaveURL(new RegExp(`/course/${id}$`));
  await expect(page.getByLabel("Kurs ilerlemesi")).toContainText("0%");

  // Kilitli quiz'e goz at: gonderim kapali
  await page.getByRole("button", { name: /Quiz kilitli/ }).click();
  await expect(page.getByRole("button", { name: "Cevabı gönder" })).toBeDisabled();

  for (const title of ["Kurulum ve proje yapısı", "Widget ağacı", "State yönetimine giriş"]) {
    await page.getByRole("button", { name: new RegExp(title) }).click();
    await page.getByRole("button", { name: "Dersi tamamla" }).click();
    await expect(page.getByRole("button", { name: "Dersi tamamla" })).toHaveCount(0);
  }
  await expect(page.getByLabel("Kurs ilerlemesi")).toContainText("100%");

  await page.getByRole("button", { name: "Quiz'e geç" }).click();
  for (const answer of ["Dart", "Widget", "setState"]) await page.getByLabel(answer, { exact: true }).check();
  await page.getByRole("button", { name: "Cevabı gönder" }).click();
  await expect(page.getByRole("status")).toHaveText("Sonuç: 3/3 (%100)");
  await expect(page.getByLabel("Quiz geçmişi")).toContainText("en iyi %100");

  page.once("dialog", (d) => void d.accept());
  await page.getByRole("button", { name: "İlerlemeyi sıfırla" }).click();
  await expect(page.getByLabel("Kurs ilerlemesi")).toContainText("0%");
});
