import path from "path";
import { defineConfig, devices } from "@playwright/test";

// e2e sunucusu prisma/dev.db yerine her baslangicta sifirdan kurulan prisma/e2e.db ile calisir.
const e2eDb = path.resolve(__dirname, "prisma/e2e.db");

export default defineConfig({
  testDir: "./tests/e2e",
  // Tek isci: testler ayni e2e veritabanini paylasir; eszamanli ilk derlemelerde Turbopack dev nadiren 404 verdi
  fullyParallel: false,
  workers: 1,
  timeout: 60_000,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:3201",
    trace: "on-first-retry",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: `node scripts/create-db.mjs "${e2eDb}" && npx next dev -p 3201 -H 127.0.0.1`,
    url: "http://127.0.0.1:3201/katalog",
    env: { DATABASE_URL: `file:${e2eDb.replace(/\\/g, "/")}` },
    reuseExistingServer: !process.env.CI,
    timeout: 180_000,
  },
});
