"use client";

import { useCallback, useEffect, useRef } from "react";

export function useSplitResize(
  handleRef: React.RefObject<HTMLElement | null>,
  leftRef: React.RefObject<HTMLElement | null>,
  rightRef: React.RefObject<HTMLElement | null>
) {
  const dragging = useRef(false);

  const onMove = useCallback((clientX: number) => {
    const left = leftRef.current;
    const right = rightRef.current;
    const handle = handleRef.current;
    if (!left || !right || !handle) return;

    const workspace = left.parentElement;
    if (!workspace) return;

    const rect = workspace.getBoundingClientRect();
    const min = 320;
    let w = clientX - rect.left;
    w = Math.max(min, Math.min(rect.width - min - handle.offsetWidth, w));
    left.style.flex = "none";
    right.style.flex = "none";
    left.style.width = `${w}px`;
    right.style.width = `${rect.width - w - handle.offsetWidth}px`;
  }, [handleRef, leftRef, rightRef]);

  useEffect(() => {
    const handle = handleRef.current;
    if (!handle) return;

    const start = (e: PointerEvent) => {
      dragging.current = true;
      handle.classList.add("dragging");
      handle.setPointerCapture(e.pointerId);
    };

    const move = (e: PointerEvent) => {
      if (!dragging.current) return;
      onMove(e.clientX);
    };

    const end = (e: PointerEvent) => {
      if (!dragging.current) return;
      dragging.current = false;
      handle.classList.remove("dragging");
      handle.releasePointerCapture(e.pointerId);
    };

    // Klavye: odaklanmis ayiricida sol/sag ok tuslari paneli 32 px kaydirir.
    const key = (e: KeyboardEvent) => {
      if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return;
      const left = leftRef.current;
      if (!left) return;
      e.preventDefault();
      onMove(left.getBoundingClientRect().right + (e.key === "ArrowLeft" ? -32 : 32));
    };

    handle.addEventListener("keydown", key);
    handle.addEventListener("pointerdown", start);
    handle.addEventListener("pointermove", move);
    handle.addEventListener("pointerup", end);
    handle.addEventListener("pointercancel", end);

    return () => {
      handle.removeEventListener("keydown", key);
      handle.removeEventListener("pointerdown", start);
      handle.removeEventListener("pointermove", move);
      handle.removeEventListener("pointerup", end);
      handle.removeEventListener("pointercancel", end);
    };
  }, [handleRef, leftRef, onMove]);
}
