"use client";

import { formatFileSize } from "@/lib/json-utils";
import { useJsonStore } from "@/lib/store";

type StatusBarProps = {
  left?: React.ReactNode;
  right?: React.ReactNode;
};

export default function StatusBar({ left, right }: StatusBarProps) {
  const {
    rawJson,
    nodeCount,
    fileSize,
    parseTime,
    inputMode,
    watchedFilePath,
    watchEnabled,
    indentSize,
    setIndentSize,
    setInputMode,
    allowJsonc,
    setAllowJsonc,
  } = useJsonStore();

  const defaultLeft = rawJson.trim() ? (
    <>
      <span className="statusbar-item mono">{nodeCount} node</span>
      <span className="statusbar-item mono">{formatFileSize(fileSize)}</span>
      <span className="statusbar-item mono">
        {parseTime === 0 ? "<0.01 ms" : `${parseTime} ms`}
      </span>
    </>
  ) : (
    <span className="statusbar-item mono">- node</span>
  );

  // Laboratuvar ayarlari (VS Code durum cubugu gibi): girinti, giris modu, JSONC; localStorage'da kalici.
  const defaultRight = (
    <>
      <select
        className="statusbar-control"
        aria-label="Format girintisi"
        value={indentSize}
        onChange={(e) => setIndentSize(e.target.value === "4" ? 4 : 2)}
      >
        <option value="2">Boşluk: 2</option>
        <option value="4">Boşluk: 4</option>
      </select>
      <select
        className="statusbar-control"
        aria-label="Giriş modu"
        value={inputMode}
        onChange={(e) => setInputMode(e.target.value === "ndjson" ? "ndjson" : "json")}
      >
        <option value="json">JSON</option>
        <option value="ndjson">NDJSON</option>
      </select>
      <label className="statusbar-control" title="Yorumlu JSON: // ve /* */ yorumlarını parse öncesi soy">
        <input type="checkbox" checked={allowJsonc} onChange={(e) => setAllowJsonc(e.target.checked)} />
        JSONC
      </label>
      <span className="statusbar-item">UTF-8</span>
      {watchedFilePath && watchEnabled && (
        <span className="statusbar-item watch-indicator">
          <span className="dot" aria-hidden />
          izleniyor
        </span>
      )}
    </>
  );

  return (
    <footer className="statusbar">
      {left ?? defaultLeft}
      <span className="statusbar-spacer" />
      {right ?? defaultRight}
    </footer>
  );
}
