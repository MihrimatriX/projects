import { defineConfig } from "@playwright/test";

// Masaustu kabugu testi: publish.ps1 once desktop\stage (standalone sunucu) uretir.
export default defineConfig({
  testDir: "./tests/electron",
  reporter: "list",
  timeout: 120_000,
});
