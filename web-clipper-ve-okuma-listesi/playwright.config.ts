import path from "path";
import { defineConfig, devices } from "@playwright/test";

// e2e sunucusu prisma/dev.db yerine her baslangicta sifirdan kurulan prisma/e2e.db ile 3207'de calisir.
// Testler internete cikmaz: kayitlar yedek/API ile ozetli eklenir, Readability yerel orneklerle (vitest) test edilir.
const e2eDb = path.resolve(__dirname, "prisma/e2e.db");

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: 2,
  reporter: "list",
  // Dev sunucuda ilk sayfa derlemesi yavas makinelerde uzun surebilir
  timeout: 120_000,
  expect: { timeout: 30_000 },
  use: {
    baseURL: "http://127.0.0.1:3207",
    trace: "on-first-retry",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: `node scripts/create-db.mjs "${e2eDb}" && npx next dev -p 3207 -H 127.0.0.1`,
    url: "http://127.0.0.1:3207/api/stats",
    env: { DATABASE_URL: `file:${e2eDb.replace(/\\/g, "/")}` },
    reuseExistingServer: !process.env.CI,
    timeout: 300_000,
  },
});
