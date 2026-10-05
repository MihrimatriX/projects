import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : 3,
  // dev sunucusu ilk ziyarette sayfayi derler; paralel calismada beklemeler uzun tutulur.
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: "list",
  use: {
    baseURL: "http://127.0.0.1:3203",
    trace: "on-first-retry",
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: {
    command: "npm run dev -- -p 3203 -H 127.0.0.1",
    url: "http://127.0.0.1:3203",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
