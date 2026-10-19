import path from "path";
import { defineConfig } from "vitest/config";

// API testleri prisma/dev.db yerine her calistirmada sifirdan kurulan test-results/vitest.db kullanir.
const testDb = path.resolve(__dirname, "test-results/vitest.db");

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    globalSetup: ["tests/vitest-setup.ts"],
    env: { DATABASE_URL: `file:${testDb.replace(/\\/g, "/")}` },
    fileParallelism: false,
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
