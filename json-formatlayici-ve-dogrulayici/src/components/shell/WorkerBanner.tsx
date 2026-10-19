"use client";

import { useJsonStore } from "@/lib/store";

export default function WorkerBanner() {
  const { isParsing, isLargeFile } = useJsonStore();
  const visible = isParsing && isLargeFile;

  return (
    <div className={`banner-worker${visible ? " visible" : ""}`} aria-hidden={!visible}>
      <div className="spinner" />
      <span>Büyük dosya parse ediliyor…</span>
    </div>
  );
}
