import type { NextConfig } from "next";

// `npm run build:static` -> out/ (Electron kabugu icin statik export); normal build degismez.
const isStatic = process.env.npm_lifecycle_event === "build:static";

const nextConfig: NextConfig = {
  output: isStatic ? "export" : undefined,
  images: isStatic ? { unoptimized: true } : undefined,
  devIndicators: false,
};

export default nextConfig;
