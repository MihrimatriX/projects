import path from "path";
import { defineConfig, devices } from "@playwright/test";

// e2e internete cikmaz: feed'ler tests/fixtures altindaki yerel sunucudan (3214) gelir,
// veritabani her baslangicta sifirdan kurulan prisma/e2e.db'dir.
const e2eDb = path.resolve(__dirname, "prisma/e2e.db");
const FIXTURES = "http://127.0.0.1:3214";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  workers: 1,
  timeout: 60_000,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:3204",
    trace: "on-first-retry",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: [
    {
      command: "node tests/fixtures/serve.mjs 3214",
      url: `${FIXTURES}/teknoloji.xml`,
      reuseExistingServer: !process.env.CI,
    },
    {
      command: `node scripts/create-db.mjs "${e2eDb}" && npx next dev -p 3204 -H 127.0.0.1`,
      url: "http://127.0.0.1:3204/settings",
      env: {
        DATABASE_URL: `file:${e2eDb.split(path.sep).join("/")}`,
        RSS_ALLOW_PRIVATE_HOSTS: "1",
        DEFAULT_FEEDS: JSON.stringify([
          { url: `${FIXTURES}/teknoloji.xml`, folder: "Teknoloji", title: "Yerel Teknoloji" },
        ]),
      },
      reuseExistingServer: !process.env.CI,
      timeout: 300_000,
    },
  ],
});
