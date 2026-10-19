"use client";

import { useEffect, useState } from "react";
import { useFeedStore } from "@/lib/store";

const WELCOME_KEY = "haber:welcome-dismissed";
const KBD_KEY = "haber:kbd-hidden";

/** SSR ile client ilk render'ını eşleştirmek için */
export function useMounted() {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  return mounted;
}

export function useResponsiveLayout() {
  const setLayout = useFeedStore((s) => s.setLayout);
  const setKbdHidden = useFeedStore((s) => s.setKbdHidden);
  const mounted = useMounted();

  useEffect(() => {
    if (!mounted) return;
    const update = () => {
      const w = window.innerWidth;
      // ponytail: <900 mobil sekmeler; >=900 tam sidebar — iki sütunlu "sidebar yok" ara modu yok
      if (w < 900) setLayout("mobile");
      else setLayout("three-col");
    };
    update();
    window.addEventListener("resize", update);
    return () => window.removeEventListener("resize", update);
  }, [mounted, setLayout]);

  useEffect(() => {
    if (!mounted) return;
    try {
      if (localStorage.getItem(KBD_KEY) === "1") setKbdHidden(true);
    } catch {
      /* ponytail: localStorage yoksa varsayılan görünür */
    }
  }, [mounted, setKbdHidden]);

  return mounted;
}

export function useWelcomeDismissed() {
  const mounted = useMounted();
  const [dismissed, setDismissed] = useState(true);

  useEffect(() => {
    try {
      setDismissed(localStorage.getItem(WELCOME_KEY) === "1");
    } catch {
      setDismissed(false);
    }
  }, []);

  const dismiss = () => {
    setDismissed(true);
    try {
      localStorage.setItem(WELCOME_KEY, "1");
    } catch {
      /* ignore */
    }
  };

  // ponytail: mount öncesi banner gösterme — SSR/hydration uyumu
  return { dismissed: !mounted || dismissed, dismiss };
}

export function persistKbdHidden(hidden: boolean) {
  try {
    localStorage.setItem(KBD_KEY, hidden ? "1" : "0");
  } catch {
    /* ignore */
  }
}
