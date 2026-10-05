import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["test/**/*.test.ts"], // e2e/ Playwright ile ayrı çalışır
  },
});
