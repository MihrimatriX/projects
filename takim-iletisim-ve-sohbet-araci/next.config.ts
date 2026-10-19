import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // Masaüstü paketi (publish.ps1) için; npm run dev / tsx server.ts akışını etkilemez
  output: "standalone",
};

export default nextConfig;
