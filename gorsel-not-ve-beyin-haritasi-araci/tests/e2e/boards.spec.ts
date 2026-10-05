import { expect, test, type Page } from "@playwright/test";

const unique = (prefix: string) => `${prefix} ${Date.now()}-${Math.floor(Math.random() * 1e4)}`;

async function createBoard(page: Page, name: string) {
  await page.goto("/");
  await page.getByRole("button", { name: "Yeni pano", exact: true }).click();
  await page.getByLabel("Pano adı").fill(name);
  await page.getByRole("dialog").getByRole("button", { name: "Oluştur" }).click();
  // router.push URL'i ancak hedef sayfa derlenince degistirir; ilk acilista tldraw derlemesi uzun surer
  await expect(page).toHaveURL(/\/board\//, { timeout: 120_000 });
  await expect(page.locator(".tl-canvas")).toBeVisible({ timeout: 60_000 });
}

async function drawRectangle(page: Page) {
  const canvas = page.locator(".tl-canvas");
  const box = (await canvas.boundingBox())!;
  await page.keyboard.press("r");
  await page.mouse.move(box.x + box.width / 2 - 80, box.y + box.height / 2 - 60);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width / 2 + 80, box.y + box.height / 2 + 60, { steps: 8 });
  await page.mouse.up();
  await expect(page.locator(".tl-shape")).toHaveCount(1);
}

test("pano olustur, sekil ciz, otomatik kayit sonrasi yeniden yuklemede korunur", async ({ page }) => {
  // tldraw ikon/yazi tipleri yerelden gelmeli (cevrimdisi masaustu surumu)
  const cdn: string[] = [];
  page.on("request", (r) => {
    if (r.url().includes("cdn.tldraw.com")) cdn.push(r.url());
  });
  const name = unique("Beyin firtinasi");
  await createBoard(page, name);
  await expect(page.getByText("Başlamak için tuvalde çift tıklayın")).toBeVisible();

  await drawRectangle(page);
  await expect(page.getByRole("status").filter({ hasText: "Kaydedildi" })).toBeVisible();

  await page.reload();
  await expect(page.locator(".tl-shape")).toHaveCount(1);
  await expect(page.getByText("Başlamak için tuvalde çift tıklayın")).toHaveCount(0);

  // Ana sayfada pano artik "bos" degil
  await page.goto("/");
  const card = page.getByRole("listitem").filter({ hasText: name });
  await expect(card).toBeVisible();
  await expect(card).not.toContainText("boş");
  expect(cdn).toEqual([]);
});

test("2 sn dolmadan baska sayfaya gecince son degisiklik kaybolmaz", async ({ page }) => {
  await createBoard(page, unique("Hizli gecis"));
  const url = page.url();
  await drawRectangle(page);
  // Debounce beklemeden ana sayfaya don
  await page.getByRole("link", { name: "Tüm panolara dön" }).click();
  await expect(page).toHaveURL(/\/$/);
  await page.goto(url);
  await expect(page.locator(".tl-shape")).toHaveCount(1);
});

test("ara, yeniden adlandir ve sil", async ({ page }) => {
  const name = unique("Arama hedefi");
  await createBoard(page, name);
  await page.goto("/");

  const search = page.getByRole("searchbox", { name: "Panolarda ara" });
  await search.fill("eşleşmeyecek-xyz");
  await expect(page.getByText("ile eşleşen pano yok")).toBeVisible();
  await search.fill(name.toLocaleUpperCase("tr"));
  const card = page.getByRole("listitem").filter({ hasText: name });
  await expect(card).toBeVisible();

  const renamed = unique("Yeni ad");
  await card.getByRole("button", { name: "Yeniden adlandır" }).click();
  await page.getByLabel("Yeni ad").fill(renamed);
  await page.getByRole("dialog").getByRole("button", { name: "Kaydet" }).click();
  await search.fill(renamed);
  const renamedCard = page.getByRole("listitem").filter({ hasText: renamed });
  await expect(renamedCard).toBeVisible();

  await renamedCard.getByRole("button", { name: "Sil" }).click();
  await page.getByRole("alertdialog").getByRole("button", { name: "Sil" }).click();
  await expect(page.getByText(`"${renamed}" silindi`)).toBeVisible();
  await expect(page.getByRole("listitem").filter({ hasText: renamed })).toHaveCount(0);
});

test("JSON disa aktar ve ice aktar", async ({ page }) => {
  const name = unique("Yedek");
  await createBoard(page, name);
  await drawRectangle(page);

  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "JSON yedeği indir" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/^Yedek-.*\.json$/);
  const file = await download.path();

  await page.goto("/");
  await page.getByLabel("Pano dosyası seç").setInputFiles(file);
  await expect(page.getByText(`"${name}" içe aktarıldı`)).toBeVisible();
  // Asil pano + ice aktarilan kopya
  const cards = page.getByRole("listitem").filter({ hasText: name });
  await expect(cards).toHaveCount(2);
  await cards.first().getByRole("link").click();
  await expect(page.locator(".tl-shape")).toHaveCount(1);
});

test("API bozuk veri ve olmayan panoyu reddeder", async ({ request }) => {
  const created = await request.post("/api/boards", { data: { name: "  " } });
  expect(created.status()).toBe(201);
  const { board } = await created.json();
  expect(board.name).toBe("Yeni pano");

  expect((await request.patch(`/api/boards/${board.id}`, { data: { data: "{bozuk" } })).status()).toBe(400);
  expect((await request.patch(`/api/boards/${board.id}`, { data: { name: " " } })).status()).toBe(400);
  expect((await request.post("/api/boards", { data: { data: "[]" } })).status()).toBe(400);
  expect((await request.patch("/api/boards/yok", { data: { name: "x" } })).status()).toBe(404);
  expect((await request.delete("/api/boards/yok")).status()).toBe(404);
  expect((await request.delete(`/api/boards/${board.id}`)).status()).toBe(200);
});
