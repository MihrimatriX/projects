import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  // publish.ps1 masaustu surumu icin standalone sunucu uretir; `npm start` normal akista kalir.
  ...(process.env.NEXT_STANDALONE === "1" && {
    output: "standalone" as const,
  }),
};

export default nextConfig;
