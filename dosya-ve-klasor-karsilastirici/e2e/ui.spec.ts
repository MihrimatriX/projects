import { expect, test } from "@playwright/test";
import fs from "fs";
import os from "os";
import path from "path";
import { launch, mockDialogs, revealed, write } from "./helpers";

// Arayüz envanteri: docs/arayuz-testi.md. Her test kendi geçici profilini kullanır.

test("karşılama, hata, yardım, ayarlar (tüm bölümler), git diff, gözat", async () => {
  const ctx = await launch();
  const { app, page, tmp } = ctx;
  try {
    // Karşılama + sürükle-bırak bölgesi
    await expect(page.getByRole("heading", { name: "Dosya ve Klasör Karşılaştırıcı" })).toBeVisible();
    const drop = page.locator(".drop-zone");
    await drop.dispatchEvent("dragover");
    await expect(drop).toHaveClass(/drag-over/);
    await drop.dispatchEvent("dragleave");
    await expect(drop).not.toHaveClass(/drag-over/);

    // Boş yolla karşılaştır -> hata bandı
    await page.getByRole("button", { name: "Karşılaştır", exact: true }).click();
    await expect(page.locator(".error-banner")).toContainText("sol ve sağ yol zorunlu");

    // Var olmayan yol -> anlaşılır hata
    await page.getByLabel("Sol dosya yolu").fill(path.join(tmp, "yok-sol"));
    await page.getByLabel("Sağ dosya yolu").fill(path.join(tmp, "yok-sag"));
    await page.getByLabel("Sağ dosya yolu").press("Enter");
    await expect(page.locator(".error-banner")).toContainText("Sol bulunamadı");
    await expect(page.locator(".error-banner")).not.toContainText("Error invoking");
    await page.getByRole("button", { name: "Hatayı kapat" }).click();
    await expect(page.locator(".error-banner")).toHaveCount(0);

    // Gözat düğmeleri (yerel diyalog sahte), iptal yolu değiştirmez
    const a = path.join(tmp, "a.txt");
    const b = path.join(tmp, "b.txt");
    write(a, "x\n");
    write(b, "y\n");
    await mockDialogs(app, [a, b], []);
    await page.getByRole("button", { name: "Sol yolu seç" }).click();
    await expect(page.getByLabel("Sol dosya yolu")).toHaveValue(a);
    await page.getByRole("button", { name: "Sağ yolu seç" }).click();
    await expect(page.getByLabel("Sağ dosya yolu")).toHaveValue(b);
    await page.getByRole("button", { name: "Sağ yolu seç" }).click(); // kuyruk boş = iptal
    await expect(page.getByLabel("Sağ dosya yolu")).toHaveValue(b);
    // Tırnaklı yapıştırma temizlenir
    await page.getByLabel("Sol dosya yolu").fill(`"${a}"`);

    // Yardım: F1, Esc ve Tamam
    await page.keyboard.press("F1");
    const help = page.getByRole("dialog", { name: "Yardım" });
    await expect(help).toBeVisible();
    await expect(help).toContainText("Alt+↓");
    await page.keyboard.press("Escape");
    await expect(help).toHaveCount(0);
    await page.keyboard.press("F1");
    await page.getByRole("button", { name: "Tamam" }).click();
    await expect(help).toHaveCount(0);

    // Ayarlar: Ctrl+,
    fs.mkdirSync(path.join(tmp, "local", "DosyaKarsilastirici", "hash-cache"), { recursive: true });
    await page.keyboard.press("Control+,");
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    await expect(settings).toBeVisible();
    await expect(settings).toContainText("sürüm 2.");

    // Genel: tema, .bak, önbellek
    await settings.getByLabel("Tema").selectOption("light");
    await expect(page.locator("html")).toHaveAttribute("data-theme", "light");
    await expect.poll(() => ctx.settings().theme).toBe("light");
    const bak = settings.getByRole("switch", { name: ".bak yedekleme" });
    await expect(bak).toHaveAttribute("aria-checked", "true");
    await bak.click();
    await expect(bak).toHaveAttribute("aria-checked", "false");
    await expect.poll(() => ctx.settings().createBackupOnMerge).toBe(false);
    await bak.click();
    await expect.poll(() => ctx.settings().createBackupOnMerge).toBe(true);
    await settings.getByRole("button", { name: "Önbelleği temizle" }).click();
    await expect(settings.getByRole("status")).toHaveText("Hash önbelleği temizlendi");
    expect(fs.existsSync(path.join(tmp, "local", "DosyaKarsilastirici", "hash-cache"))).toBe(false);

    // Diff: limitler, varsayılan görünüm, base yolu
    await settings.getByRole("button", { name: "Diff" }).click();
    await expect(settings.getByLabel("Metin dosya limiti")).toHaveValue("4 MB");
    await expect(settings.getByLabel("Hex görünüm limiti")).toHaveValue("256 KB");
    await settings.getByLabel("Varsayılan görünüm").selectOption("inline");
    await expect.poll(() => ctx.settings().defaultViewMode).toBe("inline");
    await settings.getByLabel("Base yolu").fill("  C:\\base  ");
    await settings.getByLabel("Base yolu").blur();
    await expect.poll(() => ctx.settings().lastBasePath).toBe("C:\\base");
    await settings.getByLabel("Base yolu").fill("");
    await settings.getByLabel("Base yolu").blur();
    await settings.getByLabel("Varsayılan görünüm").selectOption("side-by-side");

    // Son çiftler: boş durum + temizle
    await settings.getByRole("button", { name: "Son Çiftler" }).click();
    await expect(settings.getByText("Henüz kayıt yok.")).toBeVisible();
    await settings.getByRole("button", { name: "Listeyi Temizle" }).click();
    await expect.poll(() => ctx.settings().recentPairs).toEqual([]);

    // Gitignore: desenler + anahtar
    await settings.getByRole("button", { name: "Gitignore" }).click();
    await settings.getByLabel("Filtre desenleri").fill("build/\n\n  tmp/ ");
    await settings.getByRole("button", { name: "Kaydet" }).click();
    await expect.poll(() => ctx.settings().extraIgnoreDirs).toEqual(["build/", "tmp/"]);
    await settings.getByRole("switch", { name: ".gitignore" }).click();
    await expect.poll(() => ctx.settings().useGitignore).toBe(false);

    // Kapatma yolları: ✕, alt bağlantı, Esc
    await settings.getByRole("button", { name: "Kapat" }).click();
    await expect(settings).toHaveCount(0);
    await page.keyboard.press("Control+,");
    await settings.getByRole("button", { name: "← Karşılaştırmaya dön" }).click();
    await expect(settings).toHaveCount(0);
    await page.keyboard.press("Control+,");
    await settings.getByRole("button", { name: "Genel" }).click();
    await expect(settings.getByLabel("Tema")).toHaveValue("light");
    await page.keyboard.press("Escape");
    await expect(settings).toHaveCount(0);

    // Git'ten yükle: iptal, boşken pasif, çok dosyalı gezinme, patch
    await page.getByRole("button", { name: "Git'ten Yükle" }).click();
    const git = page.getByRole("dialog", { name: "Git diff içe aktar" });
    await expect(git.getByRole("button", { name: "İçe Aktar" })).toBeDisabled();
    await git.getByRole("button", { name: "İptal" }).click();
    await expect(git).toHaveCount(0);
    await page.getByRole("button", { name: "Git'ten Yükle" }).click();
    await git.getByLabel("Git diff metni").fill(
      [
        "diff --git a/one.txt b/one.txt",
        "--- a/one.txt",
        "+++ b/one.txt",
        "@@ -1,2 +1,2 @@",
        " ortak",
        "-eski",
        "+yeni",
        "diff --git a/two.txt b/two.txt",
        "--- a/two.txt",
        "+++ b/two.txt",
        "@@ -1 +1 @@",
        "-a",
        "+b",
        "",
      ].join("\n")
    );
    await git.getByRole("button", { name: "İçe Aktar" }).click();
    await expect(git).toHaveCount(0);
    const status = page.locator(".status-bar");
    await expect(status).toContainText("Git 1/2");
    await expect(status).toContainText("one.txt");
    await expect(page.getByRole("button", { name: "Önceki git dosyası" })).toBeDisabled();
    await page.getByRole("button", { name: "Sonraki git dosyası" }).click();
    await expect(status).toContainText("Git 2/2");
    await expect(status).toContainText("two.txt");
    await page.getByRole("button", { name: "Önceki git dosyası" }).click();
    await expect(status).toContainText("Git 1/2");
    // Git modunda birleştirme yok, patch var
    await expect(page.getByRole("button", { name: /Birleştir/ })).toHaveCount(0);
    const patch = path.join(tmp, "git.patch");
    await mockDialogs(app, [], [patch]);
    await page.getByRole("button", { name: "Patch Dışa Aktar" }).click();
    await expect.poll(() => fs.existsSync(patch)).toBe(true);
    expect(fs.readFileSync(patch, "utf8")).toContain("+yeni");
    // Açık tema Monaco'ya da uygulanır
    await expect(page.locator(".monaco-diff-editor")).toBeVisible({ timeout: 20_000 });
    await expect(page.locator(".monaco-editor.vs").first()).toBeVisible();

    // Geçersiz git metni -> hata
    await page.getByRole("button", { name: "Git'ten Yükle" }).click();
    await git.getByLabel("Git diff metni").fill("bu bir diff değil");
    await git.getByRole("button", { name: "İçe Aktar" }).click();
    await expect(page.locator(".error-banner")).toContainText("Geçerli diff bulunamadı");
  } finally {
    await ctx.close();
  }
});

test("dosya modu: görünümler, fark gezinme, değiştir, birleştir, patch, 3-yönlü, hex", async () => {
  const ctx = await launch();
  const { app, page, tmp } = ctx;
  try {
    const lines = (n: number, change: Record<number, string>) =>
      Array.from({ length: n }, (_, i) => change[i + 1] ?? `satir ${i + 1}`).join("\n") + "\n";
    const left = path.join(tmp, "sol.txt");
    const right = path.join(tmp, "sag.txt");
    const base = path.join(tmp, "base.txt");
    write(base, lines(60, {}));
    write(left, lines(60, { 5: "SOL-5", 50: "SOL-50" }));
    write(right, lines(60, { 5: "SAG-5", 50: "SAG-50" }));

    await page.getByLabel("Sol dosya yolu").fill(left);
    await page.getByLabel("Sağ dosya yolu").fill(right);
    await page.getByLabel("Sol dosya yolu").press("Enter");
    await expect(page.locator(".summary")).toContainText("+2");
    await expect(page.locator(".summary")).toContainText("−2");
    await expect(page.locator(".monaco-diff-editor")).toBeVisible({ timeout: 20_000 });
    await expect(page.locator(".status-bar")).toContainText("sol.txt");

    // Görünüm sekmeleri
    const tab = (name: string) => page.getByRole("tab", { name });
    await expect(tab("Yan Yana")).toHaveAttribute("aria-selected", "true");
    await expect(tab("Hex Görünüm")).toBeDisabled();
    await expect(tab("3-Yönlü Birleştir")).toBeDisabled();
    await tab("Satır İçi").click();
    await expect(tab("Satır İçi")).toHaveAttribute("aria-selected", "true");
    await expect(page.locator(".pane-headers")).toHaveCount(0);
    await tab("Yan Yana").click();
    await expect(page.locator(".pane-headers")).toBeVisible();

    // Önceki/sonraki fark (düğme + Alt+Ok): aktif satır numarası fark satırına gider
    const activeLine = page.locator(".editor.modified .line-numbers.active-line-number");
    await page.getByRole("button", { name: "↓ Sonraki fark" }).click();
    await expect(activeLine).toHaveText("5");
    await page.getByRole("button", { name: "↓ Sonraki fark" }).click();
    await expect(activeLine).toHaveText("50");
    await page.keyboard.press("Alt+ArrowUp");
    await expect(activeLine).toHaveText("5");
    await page.keyboard.press("Alt+ArrowDown");
    await expect(activeLine).toHaveText("50");
    await page.getByRole("button", { name: "↑ Önceki fark" }).click();
    await expect(activeLine).toHaveText("5");

    // Yolları değiştir (iki kez = eski hal)
    await page.getByRole("button", { name: "Yolları değiştir" }).click();
    await expect(page.getByLabel("Sol dosya yolu")).toHaveValue(right);
    await expect(page.getByRole("status")).toHaveText("Yollar değiştirildi");
    await page.getByRole("button", { name: "Yolları değiştir" }).click();
    await expect(page.getByLabel("Sol dosya yolu")).toHaveValue(left);

    // Patch dışa aktar (kaydet diyaloğu iptal -> dosya yok; sonra kaydet)
    const patch = path.join(tmp, "out.patch");
    await mockDialogs(app, [], ["", patch]);
    await page.getByRole("button", { name: "Patch Dışa Aktar" }).click();
    await page.getByRole("button", { name: "Patch Dışa Aktar" }).click();
    await expect.poll(() => fs.existsSync(patch)).toBe(true);
    expect(fs.readFileSync(patch, "utf8")).toMatch(/-SOL-5[\s\S]*\+SAG-5/);

    // 3-yönlü: base ayarlardan, çakışmaları çöz, kaydet
    await page.keyboard.press("Control+,");
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    await settings.getByRole("button", { name: "Diff" }).click();
    await settings.getByLabel("Base yolu").fill(base);
    await settings.getByLabel("Base yolu").blur();
    await expect.poll(() => ctx.settings().lastBasePath).toBe(base);
    await page.keyboard.press("Escape");
    await tab("3-Yönlü Birleştir").click();
    await expect(page.locator(".merge-section h4")).toContainText("Çakışmalar: 2");
    const save = page.getByRole("button", { name: "Birleştirilmiş Dosyayı Kaydet" });
    await expect(save).toBeDisabled();
    await expect(page.getByText("Tüm çakışmaları çözün.")).toBeVisible();
    const rows = page.locator(".conflict-row");
    for (const name of ["Sağ Al", "Base", "Her İkisi"]) {
      await rows.nth(0).getByRole("button", { name }).click();
      await expect(rows.nth(0).getByRole("button", { name })).toHaveAttribute("aria-pressed", "true");
    }
    await rows.nth(0).getByRole("button", { name: "Sol Al" }).click();
    await expect(rows.nth(0).getByRole("button", { name: "Base" })).toHaveAttribute("aria-pressed", "false");
    await rows.nth(1).getByRole("button", { name: "Sağ Al" }).click();
    await expect(save).toBeEnabled();
    const merged = path.join(tmp, "merged.txt");
    await mockDialogs(app, [], [merged]);
    await save.click();
    await expect.poll(() => fs.existsSync(merged)).toBe(true);
    const out = fs.readFileSync(merged, "utf8");
    expect(out).toContain("SOL-5");
    expect(out).toContain("SAG-50");
    await expect(page.getByRole("status")).toContainText("Kaydedildi");
    await tab("Yan Yana").click();

    // Birleştir → (sol sağa, .bak yedeği) ve ← Birleştir
    await page.getByRole("button", { name: "Birleştir →" }).click();
    await expect.poll(() => fs.readFileSync(right, "utf8")).toBe(fs.readFileSync(left, "utf8"));
    expect(fs.readFileSync(`${right}.bak`, "utf8")).toContain("SAG-5");
    await expect(page.getByRole("status")).toContainText("Yedek:");
    await expect(page.locator(".summary")).toContainText("+0");
    write(left, "degisti\n");
    await page.getByRole("button", { name: "← Birleştir" }).click();
    await expect.poll(() => fs.readFileSync(left, "utf8")).toContain("SOL-5");

    // Binary dosyalar -> otomatik hex
    const binL = path.join(tmp, "a.bin");
    const binR = path.join(tmp, "b.bin");
    write(binL, Buffer.from([0, 1, 2, 3, 255]));
    write(binR, Buffer.from([0, 1, 2, 4]));
    await page.getByLabel("Sol dosya yolu").fill(binL);
    await page.getByLabel("Sağ dosya yolu").fill(binR);
    await page.keyboard.press("F5");
    await expect(tab("Hex Görünüm")).toHaveAttribute("aria-selected", "true");
    await expect(page.locator(".hex-pane-header").first()).toContainText("5 bayt");
    await expect(page.locator(".hex-pane-header").nth(1)).toContainText("4 bayt");
    await expect(page.getByRole("button", { name: "Patch Dışa Aktar" })).toBeDisabled();
  } finally {
    await ctx.close();
  }
});

test("klasör modu: ağaç, arama, filtre, klasör aç/kapa, göster, kopyala, son çiftler, dar pencere", async () => {
  const data = fs.mkdtempSync(path.join(os.tmpdir(), "dk-ui-data-"));
  const left = path.join(data, "left");
  const right = path.join(data, "right");
  write(path.join(left, "same.txt"), "ayni");
  write(path.join(right, "same.txt"), "ayni");
  write(path.join(left, "diff.txt"), "a\nb\n");
  write(path.join(right, "diff.txt"), "a\nc\n");
  write(path.join(left, "only.txt"), "sadece sol");
  write(path.join(right, "sag-yalniz.txt"), "sadece sag");
  write(path.join(left, "alt", "ic.txt"), "1");
  write(path.join(right, "alt", "ic.txt"), "2");
  // Son çift karşılama ekranında listelenir; tıklamak karşılaştırır.
  const ctx = await launch({ recentPairs: [{ left, right, at: 1 }] });
  const { app, page } = ctx;
  try {
    await page.getByRole("button", { name: /left.*right/ }).click();
    const tree = page.getByRole("tree");
    await expect(tree.getByText("diff.txt")).toBeVisible();
    await expect(page.locator(".status-bar")).toContainText("Sol: 4 · Sağ: 4");
    await expect(page.locator(".sidebar-count")).toHaveText("4 fark");
    await expect(tree.getByText("same.txt")).toHaveCount(0);

    // Alt klasör: kök seviyede açık; tıklayınca kapanır/açılır
    const folder = tree.getByRole("treeitem", { name: /^alt\// });
    await expect(folder).toHaveAttribute("aria-expanded", "true");

    // Filtre + arama + boş durum
    await page.getByLabel("Aynı dosyaları da göster").check();
    await expect(tree.getByText("same.txt")).toBeVisible();
    await page.getByLabel("Klasör ağacında dosya ara").fill("ONLY");
    await expect(tree.getByText("diff.txt")).toHaveCount(0);
    await page.getByLabel("Klasör ağacında dosya ara").fill("zzz");
    await expect(tree.getByText("Eşleşen dosya yok.")).toBeVisible();
    await page.getByLabel("Klasör ağacında dosya ara").fill("");
    await page.getByLabel("Aynı dosyaları da göster").uncheck();

    // Klavye ile seçim (Enter) ve klasörde göster
    await mockDialogs(app, [], []);
    await tree.getByRole("treeitem", { name: /ic\.txt/ }).press("Enter");
    await expect(page.locator(".status-bar")).toContainText("alt/ic.txt");
    await tree.getByRole("button", { name: "diff.txt dosyasını klasörde göster" }).click();
    await expect.poll(() => revealed(app)).toEqual([`${left.replace(/\\/g, "/")}/diff.txt`]);
    await expect(tree.getByRole("button", { name: "sag-yalniz.txt dosyasını klasörde göster" })).toHaveCount(0);

    // Yalnız sağda olan: yalnızca ← yönü
    await tree.getByText("sag-yalniz.txt").click();
    await expect(page.getByText("Dosya yalnızca sağ tarafta mevcut.")).toBeVisible();
    await expect(page.getByRole("button", { name: "Birleştir →" })).toHaveCount(0);
    await expect(page.getByRole("button", { name: "Patch Dışa Aktar" })).toBeDisabled();

    // Yalnız solda olan: kopyala
    await tree.getByText("only.txt").click();
    await expect(page.getByRole("button", { name: "← Birleştir" })).toHaveCount(0);
    await page.getByRole("button", { name: "Birleştir →" }).click();
    await expect.poll(() => fs.existsSync(path.join(right, "only.txt"))).toBe(true);
    await expect(tree.getByText("only.txt")).toHaveCount(0);

    // Farklı dosyada Monaco (yerel paket, CDN yok)
    await tree.getByText("diff.txt").click();
    await expect(page.locator(".monaco-diff-editor")).toBeVisible({ timeout: 20_000 });

    // Klasörü kapat/aç (fare + Enter)
    await folder.click();
    await expect(folder).toHaveAttribute("aria-expanded", "false");
    await expect(tree.getByText("ic.txt")).toHaveCount(0);
    await folder.press("Enter");
    await expect(folder).toHaveAttribute("aria-expanded", "true");
    await expect(tree.getByText("ic.txt")).toBeVisible();

    // Son çiftler ayarlarda: tıklayınca karşılaştırır ve kapanır
    await page.keyboard.press("Control+,");
    const settings = page.getByRole("dialog", { name: "Ayarlar" });
    await settings.getByRole("button", { name: "Son Çiftler" }).click();
    await settings.locator(".recent-item").first().click();
    await expect(settings).toHaveCount(0);
    await expect(tree.getByText("diff.txt")).toBeVisible();

    // Dar pencere: kenar çubuğu aç/kapa düğmesi
    await app.evaluate(({ BrowserWindow }) => {
      const w = BrowserWindow.getAllWindows()[0];
      w.setMinimumSize(400, 400);
      w.setSize(820, 700);
    });
    const toggle = page.getByRole("button", { name: "Klasör ağacını aç/kapat" });
    await expect(toggle).toBeVisible();
    await expect(toggle).toHaveAttribute("aria-expanded", "true");
    await toggle.click();
    await expect(toggle).toHaveAttribute("aria-expanded", "false");
    await expect(page.locator(".sidebar")).not.toHaveClass(/ open/);
  } finally {
    await ctx.close();
    fs.rmSync(data, { recursive: true, force: true });
  }
});
