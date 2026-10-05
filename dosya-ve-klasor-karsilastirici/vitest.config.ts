import os from "os";
import path from "path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["tests/**/*.test.ts", "electron/**/*.test.ts"],
    // Ayarlar ve hash önbelleği gerçek %LocalAppData% yerine geçici klasöre yazılsın.
    env: { LOCALAPPDATA: path.join(os.tmpdir(), "dk-vitest-local") },
  },
});
