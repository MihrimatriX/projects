"use client";

import { useEffect } from "react";
import { useRegexStore } from "@/lib/store";

export default function HistoryBootstrap() {
  const refreshHistory = useRegexStore((s) => s.refreshHistory);

  useEffect(() => {
    refreshHistory();
  }, [refreshHistory]);

  return null;
}
