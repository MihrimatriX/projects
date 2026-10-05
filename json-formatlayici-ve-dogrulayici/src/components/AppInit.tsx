"use client";

import { useEffect } from "react";
import { initFromStorage, initFromUrlHash, startDraftAutosave } from "@/lib/store";

export default function AppInit({ children }: { children: React.ReactNode }) {
  useEffect(() => {
    initFromStorage();
    initFromUrlHash();
    document.documentElement.dataset.ready = "1"; // istemci hazir (UI testleri bekler)
    return startDraftAutosave();
  }, []);

  return <>{children}</>;
}
