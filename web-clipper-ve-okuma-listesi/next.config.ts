import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  serverExternalPackages: ["jsdom", "@mozilla/readability"],
  // publish.ps1 masaustu surumu icin standalone sunucu uretir; npm run dev / npm start akisi degismez.
  ...(process.env.NEXT_STANDALONE === "1" && { output: "standalone" as const }),
};

export default nextConfig;
