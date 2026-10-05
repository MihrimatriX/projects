import { defineConfig } from "@playwright/test";

// Electron kabugu testi: once `npm run build:static` ile out/ uretilmis olmali.
export default defineConfig({
  testDir: "./tests/electron",
  reporter: "list",
  timeout: 60_000,
});
