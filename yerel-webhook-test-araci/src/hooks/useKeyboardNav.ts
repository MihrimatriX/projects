import { useEffect, useRef } from "react";

type Options = {
  ids: string[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  onReplay?: () => void;
  onCopyCurl?: () => void;
  onFocusFilter?: () => void;
  onCreateEndpoint?: () => void;
  onCopyActiveUrl?: () => void;
  onOpenShortcuts?: () => void;
  onCloseOverlay?: () => void;
  enabled?: boolean;
  /** Bir pencere açıkken yalnızca Esc çalışır (önceden r/c/oklar arkadaki listede iş yapıyordu). */
  modalOpen?: boolean;
};

export function useKeyboardNav({
  ids,
  selectedId,
  onSelect,
  onReplay,
  onCopyCurl,
  onFocusFilter,
  onCreateEndpoint,
  onCopyActiveUrl,
  onOpenShortcuts,
  onCloseOverlay,
  enabled = true,
  modalOpen = false,
}: Options) {
  const idsRef = useRef(ids);
  idsRef.current = ids;

  useEffect(() => {
    if (!enabled) return;

    function onKey(e: KeyboardEvent) {
      if (modalOpen) {
        if (e.key === "Escape") onCloseOverlay?.();
        return;
      }
      const tag = (e.target as HTMLElement)?.tagName;
      if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") {
        if (e.key === "Escape") onCloseOverlay?.();
        return;
      }

      const list = idsRef.current;
      const idx = selectedId ? list.indexOf(selectedId) : -1;

      if (e.key === "ArrowDown") {
        e.preventDefault();
        if (!list.length) return;
        onSelect(list[idx < list.length - 1 ? idx + 1 : 0]);
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        if (!list.length) return;
        onSelect(list[idx > 0 ? idx - 1 : list.length - 1]);
      } else if (e.key === "r" && !e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        onReplay?.();
      } else if (e.key === "c" && !e.ctrlKey && !e.metaKey) {
        e.preventDefault();
        onCopyCurl?.();
      } else if (e.key === "f" || e.key === "/") {
        e.preventDefault();
        onFocusFilter?.();
      } else if (e.key === "?") {
        e.preventDefault();
        onOpenShortcuts?.();
      } else if (e.key === "Escape") {
        onCloseOverlay?.();
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "n") {
        e.preventDefault();
        onCreateEndpoint?.();
      } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "l") {
        e.preventDefault();
        onCopyActiveUrl?.();
      }
    }

    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [
    enabled,
    modalOpen,
    selectedId,
    onSelect,
    onReplay,
    onCopyCurl,
    onFocusFilter,
    onCreateEndpoint,
    onCopyActiveUrl,
    onOpenShortcuts,
    onCloseOverlay,
  ]);
}
