import { defineConfig, devices } from "@playwright/test";
import os from "os";
import path from "path";

// Testler gelistirme veritabanina (prisma/dev.db) ve 3106'da calisan sunucuya dokunmaz:
// gecici klasorde her kosuda sifirlanan ayri bir SQLite + ayri port (uretim derlemesi; soguk derleme beklemesi yok).
const E2E_PORT = 3196;
const dataDir = path.join(os.tmpdir(), "takim-sohbet-e2e").replace(/\\/g, "/");

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  timeout: 60000,
  expect: { timeout: 10000 },
  use: {
    baseURL: `http://localhost:${E2E_PORT}`,
    trace: "on-first-retry",
    ...devices["Desktop Chrome"],
  },
  projects: [
    { name: "e2e", testMatch: "chat.spec.ts" },
    { name: "ui", testMatch: "ui.spec.ts" },
    { name: "electron", testMatch: "electron.spec.ts" },
    { name: "screens", testMatch: "screens.spec.ts" },
  ],
  webServer: {
    // Gecici test klasoru her kosuda bastan kurulur (yalnizca bu config'in olusturdugu dosyalar silinir)
    command:
      "node -e \"const fs=require('fs'),d=process.env.E2E_DATA_DIR;fs.rmSync(d,{recursive:true,force:true});fs.mkdirSync(d,{recursive:true})\" && npm run build && npx prisma db push && npx tsx prisma/seed.ts && npx tsx server.ts",
    url: `http://localhost:${E2E_PORT}/api/health`,
    reuseExistingServer: false,
    timeout: 600000,
    env: {
      NODE_ENV: "production",
      PORT: String(E2E_PORT),
      NEXT_PUBLIC_APP_URL: `http://localhost:${E2E_PORT}`,
      DATABASE_URL: `file:${dataDir}/e2e.db`,
      UPLOAD_DIR: `${dataDir}/uploads`,
      SESSION_SECRET: "e2e-gizli-anahtar-en-az-32-karakter-uzunlukta",
      PRISMA_HIDE_UPDATE_MESSAGE: "1",
      E2E_DATA_DIR: dataDir,
    },
  },
});
