// README ekran görüntüleri (yalnızca demo veri): npx playwright test --project=screens
// Her koşuda veritabanı sıfırlanır; ayrı çalıştırıldığında diğer testlerin mesajları görünmez.
import { expect, test, type Page } from "@playwright/test";
import path from "path";
import { bubble, login, newUserPage, openChannel, send } from "./helpers";

const docs = path.join(__dirname, "..", "docs");

async function post(page: Page, channel: string, content: string, parentId?: string) {
  const { channels } = await (await page.request.get("/api/channels")).json();
  const id = channels.find((c: { name: string }) => c.name === channel).id;
  const res = await page.request.post(`/api/channels/${id}/messages`, { data: { content, parentId } });
  return (await res.json()).message.id as string;
}

test("ekran görüntüleri", async ({ browser }) => {
  test.setTimeout(120000);
  const ayse = await newUserPage(browser, "ayse@acme.local");
  const can = await newUserPage(browser, "can@acme.local");
  const page = await (await browser.newContext({ viewport: { width: 1280, height: 800 } })).newPage();
  await login(page);

  const root = await post(ayse, "genel", "Yarınki sürüm notlarını kim hazırlıyor? Taslak `docs/surum.md` içinde.");
  await post(can, "genel", "Ben üstleniyorum, öğlene kadar PR açarım.", root);
  await post(page, "genel", "Teşekkürler @Can! Changelog'a *webhook* düzeltmesini de ekle.", root);
  await post(can, "genel", "- [x] Webhook testi\n- [x] Okunmamış rozetleri\n- [ ] Ekran görüntüleri");
  await post(ayse, "tasarım", "Açık tema paleti hazır, yorumlarınızı bekliyorum.");
  await post(can, "geliştirme", "CI 3 dakikaya indi.");

  await page.reload();
  await openChannel(page, "genel");
  await expect(page.getByText("Ekran görüntüleri")).toBeVisible();
  await expect(page.getByRole("button", { name: /^tasarım \d+$/ })).toBeVisible();
  await page.mouse.move(0, 0);
  await page.screenshot({ path: path.join(docs, "ekran.png") });

  const b = bubble(page, "sürüm notlarını");
  await b.hover();
  await b.getByRole("button", { name: "Thread aç" }).click();
  await expect(page.getByRole("complementary", { name: "Thread" }).getByText("PR açarım")).toBeVisible();
  await page.mouse.move(0, 0);
  await page.screenshot({ path: path.join(docs, "ekran-thread.png") });

  await page.goto("/settings");
  await page.getByLabel("Tema").selectOption("light");
  await page.getByLabel("Yeni webhook").fill("GitHub CI");
  await page.getByLabel("Webhook kanalı").selectOption({ label: "#geliştirme" });
  await page.getByRole("button", { name: "Webhook oluştur" }).click();
  await expect(page.getByRole("group", { name: "GitHub CI webhook" })).toBeVisible();
  await page.goto("/chat");
  await openChannel(page, "tasarım");
  await send(page, "Açık tema böyle görünüyor 👀");
  await page.screenshot({ path: path.join(docs, "ekran-acik-tema.png") });
});
