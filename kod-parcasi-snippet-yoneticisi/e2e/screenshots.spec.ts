import { expect, test } from "@playwright/test";
import fs from "fs";
import path from "path";
import { appRoot, launch, today } from "./helpers";

// README görüntüleri: `$env:SNIP_SCREENSHOTS=1; npx playwright test screenshots` -> docs/*.png (örnek veriyle)
test.skip(!process.env.SNIP_SCREENSHOTS, "Yalnızca SNIP_SCREENSHOTS=1 ile");

const DEMO = [
  {
    id: "d1",
    title: "Debounce yardımcı",
    description: "Ardışık çağrıları birleştirir",
    language: "typescript",
    folder: "Web",
    tags: ["ts", "util"],
    code: "export function debounce<T extends (...a: any[]) => void>(fn: T, ms = 200) {\n  let t: ReturnType<typeof setTimeout>;\n  return (...args: Parameters<T>) => {\n    clearTimeout(t);\n    t = setTimeout(() => fn(...args), ms);\n  };\n}\n",
    lastUsedAt: today(),
  },
  { id: "d2", title: "Fetch JSON", language: "javascript", folder: "Web", tags: ["js", "http"], code: "const res = await fetch(url);\nconst data = await res.json();\n", lastUsedAt: today() },
  { id: "d3", title: "Liste üreteci", language: "python", folder: "Betik", tags: ["py"], code: "kareler = [x * x for x in range(10)]\n" },
  { id: "d4", title: "Dosyayı oku", language: "rust", folder: "Betik", tags: ["rs", "io"], code: "let s = std::fs::read_to_string(\"girdi.txt\")?;\n" },
  { id: "d5", title: "Git son commit'i geri al", language: "bash", folder: "Git", tags: ["git"], code: "git reset --soft HEAD~1\n" },
  { id: "d6", title: "Tarih damgalı not", language: "markdown", folder: "Notlar", tags: ["şablon"], code: "## {{date}} toplantı notu\n- \n" },
];

test("README ekran görüntüleri", async () => {
  const docs = path.join(appRoot, "docs");
  fs.mkdirSync(docs, { recursive: true });
  const ctx = await launch(DEMO);
  const { app, page } = ctx;
  try {
    await app.evaluate(({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].setContentSize(1280, 800));
    await page.getByRole("listbox", { name: "Snippet listesi" }).getByText("Debounce yardımcı").click();
    await expect(page.getByLabel("Kod alanı")).toHaveValue(/debounce/);
    await page.waitForTimeout(300);
    await page.screenshot({ path: path.join(docs, "ekran.png") });

    const [palette] = await Promise.all([app.waitForEvent("window"), page.getByRole("button", { name: "Palet" }).click()]);
    await palette.waitForSelector(".palette");
    await palette.getByLabel("Palet araması").fill("web");
    await expect(palette.getByRole("option")).toHaveCount(2);
    await palette.waitForTimeout(300);
    await palette.screenshot({ path: path.join(docs, "ekran-palet.png") });
  } finally {
    await ctx.close();
  }
});
