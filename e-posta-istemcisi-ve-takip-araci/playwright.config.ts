import { defineConfig } from "@playwright/test";

// Electron e2e: önce `npm run build` (dist/ + dist-electron/) gerekir.
export default defineConfig({
  testDir: "e2e",
  timeout: 90_000,
  workers: 1,
  reporter: "list",
});
