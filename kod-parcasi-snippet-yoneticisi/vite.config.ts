import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import electron from "vite-plugin-electron/simple";
import path from "path";

export default defineConfig({
  publicDir: "assets",
  plugins: [
    react(),
    electron({
      main: {
        entry: "electron/main.ts",
      },
      preload: {
        input: path.join(__dirname, "electron/preload.ts"),
      },
    }),
  ],
  base: "./",
  server: { port: 5173, strictPort: true },
  build: {
    outDir: "dist",
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
