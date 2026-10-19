import path from "path";
import { defineConfig, devices } from "@playwright/test";

// e2e sunucusu prisma/dev.db yerine her baslangicta sifirdan kurulan prisma/e2e.db ile 3202'de calisir.
const e2eDb = path.resolve(__dirname, "prisma/e2e.db");

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: "list",
  // Dev sunucuda ilk derleme (tldraw) yavas makinelerde dakikalar surebilir
  timeout: 180_000,
  workers: 2,
  expect: { timeout: 30_000 },
  use: {
    baseURL: "http://127.0.0.1:3202",
    trace: "on-first-retry",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: `node scripts/create-db.mjs "${e2eDb}" && node scripts/copy-tldraw-assets.mjs && npx next dev -p 3202 -H 127.0.0.1`,
    url: "http://127.0.0.1:3202",
    env: { DATABASE_URL: `file:${e2eDb.replace(/\\/g, "/")}` },
    reuseExistingServer: !process.env.CI,
    timeout: 300_000,
  },
});
