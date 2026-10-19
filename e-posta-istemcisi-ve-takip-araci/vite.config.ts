import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import electron from "vite-plugin-electron/simple";
import path from "path";

export default defineConfig({
  plugins: [
    react(),
    electron({
      main: {
        entry: "electron/main.ts",
        vite: {
          build: {
            rolldownOptions: {
              external: ["better-sqlite3"],
            },
          },
        },
      },
      preload: {
        input: path.join(import.meta.dirname, "electron/preload.ts"),
      },
    }),
  ],
  base: "./",
  server: { port: 5172, strictPort: true },
  build: {
    outDir: "dist",
  },
  resolve: {
    alias: {
      "@": path.resolve(import.meta.dirname, "./src"),
    },
  },
});
