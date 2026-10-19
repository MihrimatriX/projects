import { expect, test, type APIRequestContext } from "@playwright/test";
import { readFile } from "fs/promises";

const uid = () => `${Date.now()}-${Math.floor(Math.random() * 1e6)}`;

// Eklentinin "JSON indir" bicimiyle ayni yedek: icerik hazir oldugu icin hicbir sayfa indirilmez
function backupItem(id: string, title: string) {
  return {
    url: `https://ornek.test/makale/${id}`,
    title,
    excerpt: "Bisiklet yolları hakkında kısa özet.",
    content:
      "<h2>Giriş</h2><p>Şehirde bisiklet kullanımı her yıl artıyor ve yeni yollar açılıyor.</p>" +
      '<p>İkinci paragraf.</p><img src="x" onerror="alert(1)"><script>alert(2)</script>',
    tags: ["ulasim"],
    highlights: [{ id: "eklenti-1", text: "yeni yollar açılıyor", note: null, createdAt: new Date().toISOString() }],
    isRead: false,
    isStarred: false,
    createdAt: new Date().toISOString(),
  };
}

// Soguk dev sunucuda dinamik API route'larinin ilk derlemesi sirasinda gelen istekler basarisiz olabiliyor:
// testlerden once bir kez derletilir.
test.beforeAll(async ({ request }) => {
  for (const path of ["/api/clips/isinma", "/api/highlights/isinma", "/api/backup", "/api/stats"]) {
    await request.get(path, { timeout: 120_000 }).catch(() => undefined);
  }
});

async function importBackup(request: APIRequestContext, items: unknown) {
  const res = await request.post("/api/backup", { data: items });
  expect(res.status()).toBe(200);
  return res.json();
}

test("yedekten ice aktar, oku, yildizla, filtrele ve sil", async ({ page, request }) => {
  const id = uid();
  const title = `Bisiklet makalesi ${id}`;
  expect(await importBackup(request, [backupItem(id, title)])).toMatchObject({ imported: 1, skipped: 0 });
  // Ayni yedek ikinci kez: atlanir
  expect(await importBackup(request, { clips: [backupItem(id, title)] })).toMatchObject({ imported: 0, skipped: 1 });

  await page.goto("/");
  await page.getByRole("searchbox", { name: "Makale ara" }).fill(id);
  const card = page.getByRole("link", { name: new RegExp(title) });
  await expect(card).toBeVisible();
  await card.click();

  await expect(page.getByRole("heading", { level: 1, name: title })).toBeVisible();
  await expect(page.getByText("Şehirde bisiklet kullanımı her yıl artıyor")).toBeVisible();
  await expect(page.getByText("Vurgular (1)")).toBeVisible();
  // Sunucu icerigi temizlemis olmali
  const html = await page.locator(".reader-content").innerHTML();
  expect(html).not.toContain("onerror");
  expect(html.toLowerCase()).not.toContain("<script");

  await page.getByRole("button", { name: "Yıldızla" }).click();
  await expect(page.getByRole("button", { name: "Yıldızla" })).toHaveClass(/starred/);

  await page.getByRole("link", { name: "Liste" }).click();
  await page.getByRole("button", { name: /Yıldızlı/ }).first().click();
  await expect(page.getByRole("heading", { name: "Yıldızlı" })).toBeVisible();
  await expect(page.getByRole("link", { name: new RegExp(title) })).toBeVisible();

  await page.getByRole("link", { name: new RegExp(title) }).click();
  page.once("dialog", (d) => void d.accept());
  await page.getByRole("button", { name: "Kaydı sil" }).click();
  await expect(page).toHaveURL(/\/$/);
  await page.getByRole("searchbox", { name: "Makale ara" }).fill(id);
  await expect(page.getByText("Sonuç yok")).toBeVisible();
});

test("okurken metin secince vurgu eklenir ve not kaydedilir", async ({ page, request }) => {
  const id = uid();
  const item = { ...backupItem(id, `Vurgu testi ${id}`), highlights: [] };
  await importBackup(request, [item]);
  const { clips } = await (await request.get(`/api/clips?q=${id}`)).json();

  await page.goto(`/read/${clips[0].id}`);
  // Paragrafi sec ve fare birakmayi tetikle (cift/uclu tiklama ara secimlerde fazladan vurgu uretebilir)
  const paragraph = page.getByText("İkinci paragraf.");
  await paragraph.evaluate((el) => {
    const range = document.createRange();
    range.selectNodeContents(el);
    getSelection()!.removeAllRanges();
    getSelection()!.addRange(range);
  });
  await paragraph.dispatchEvent("mouseup");
  await expect(page.getByText("Vurgular (1)")).toBeVisible();
  const note = page.getByPlaceholder("Not ekle…");
  await note.fill("Sunumda kullan");
  await note.blur();
  await expect
    .poll(async () => (await (await request.get(`/api/clips/${clips[0].id}`)).json()).clip.highlights[0]?.note)
    .toBe("Sunumda kullan");
});

test("ayarlardan yedek indirilir; ozetli kayitta tam metin dugmesi gorunur", async ({ page, request }) => {
  const id = uid();
  const url = `https://ornek.test/ozet/${id}`;
  const created = await request.post("/api/clips", {
    data: { url, title: `Özetli ${id}`, excerpt: "Yalnızca özet var.", tags: ["rss"] },
  });
  expect(created.status()).toBe(201);
  const { clip } = await created.json();

  await page.goto(`/read/${clip.id}`);
  await expect(page.getByText("Yalnızca özet var.")).toBeVisible();
  await expect(page.getByRole("button", { name: "Tam metni getir" })).toBeVisible();

  await page.goto("/settings");
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("link", { name: "Yedeği indir (JSON)" }).click();
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toMatch(/^kayitli-okuma-\d{4}-\d{2}-\d{2}\.json$/);
  const backup = JSON.parse(await readFile(await download.path(), "utf8"));
  expect(backup).toContainEqual(expect.objectContaining({ url, tags: ["rss"], excerpt: "Yalnızca özet var." }));

  // Ayarlar sayfasindan geri yukleme: kayit zaten var
  await page.getByLabel("Yedek dosyası seç").setInputFiles({
    name: "yedek.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(backup.filter((b: { url: string }) => b.url === url))),
  });
  await expect(page.getByText("0 kayıt içe aktarıldı, 1 kayıt zaten vardı.")).toBeVisible();
});

test("API tehlikeli adresleri ve bozuk istekleri reddeder", async ({ request }) => {
  expect((await request.post("/api/clips", { data: { url: "javascript:alert(1)" } })).status()).toBe(400);
  expect((await request.post("/api/clips", { data: { url: "file:///C:/gizli.txt" } })).status()).toBe(400);
  expect((await request.post("/api/clips", { headers: { "Content-Type": "application/json" }, data: "{bozuk" })).status()).toBe(400);
  expect((await request.patch("/api/clips/olmayan", { data: { isRead: true } })).status()).toBe(404);
  expect((await request.delete("/api/clips/olmayan")).status()).toBe(404);
  expect((await request.delete("/api/highlights/olmayan")).status()).toBe(404);
  expect((await request.post("/api/backup", { data: { foo: 1 } })).status()).toBe(400);
  // Yerel aga RSS istegi yapilmaz
  const feed = await request.post("/api/feeds", { data: { url: "http://127.0.0.1:9/feed.xml" } });
  expect(feed.status()).toBe(502);
  expect((await feed.json()).error).toContain("Özel ağ");
});
