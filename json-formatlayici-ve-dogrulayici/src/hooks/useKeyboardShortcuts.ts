"use client";

import { useEffect } from "react";
import { openJsonFile, saveJson } from "@/lib/file-io";
import { useJsonStore } from "@/lib/store";

export function useKeyboardShortcuts() {
  const { formatJson, minifyJson, sortKeys } = useJsonStore();

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === "F1") {
        e.preventDefault();
        window.dispatchEvent(new Event("json-open-help"));
        return;
      }

      if (!e.ctrlKey && !e.metaKey) return;

      const key = e.key.toLowerCase();
      if (e.shiftKey && key === "f") {
        e.preventDefault();
        formatJson();
      } else if (e.shiftKey && key === "m") {
        e.preventDefault();
        minifyJson();
      } else if (e.shiftKey && key === "k") {
        e.preventDefault();
        sortKeys();
      } else if (!e.shiftKey && key === "o") {
        e.preventDefault();
        openJsonFile();
      } else if (!e.shiftKey && key === "s") {
        e.preventDefault();
        void saveJson();
      }
    };

    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [formatJson, minifyJson, sortKeys]);
}
