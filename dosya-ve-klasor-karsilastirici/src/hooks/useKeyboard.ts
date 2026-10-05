import { useEffect } from "react";

type Handlers = {
  onCompare?: () => void;
  onHelp?: () => void;
  onSettings?: () => void;
  onEscape?: () => void;
};

export function useKeyboard(handlers: Handlers) {
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if (e.key === "F5") {
        e.preventDefault();
        handlers.onCompare?.();
      }
      if (e.key === "F1") {
        e.preventDefault();
        handlers.onHelp?.();
      }
      if (e.key === "Escape") handlers.onEscape?.();
      if (e.ctrlKey && e.key.toLowerCase() === ",") {
        e.preventDefault();
        handlers.onSettings?.();
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [handlers]);
}
