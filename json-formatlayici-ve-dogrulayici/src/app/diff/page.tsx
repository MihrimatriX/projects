"use client";

import { useMemo } from "react";
import BrandIcon from "@/components/shell/BrandIcon";
import StatusBar from "@/components/shell/StatusBar";
import ToolbarNav from "@/components/shell/ToolbarNav";
import { lineDiff, summarizeDiff } from "@/lib/json-diff";
import { useJsonStore } from "@/lib/store";

function formatSide(text: string): string[] {
  if (!text.trim()) return [];
  try {
    return JSON.stringify(JSON.parse(text), null, 2).split("\n");
  } catch {
    return text.split("\n");
  }
}

const KIND_SIGN = { added: "+", removed: "−", changed: "~", unchanged: " " } as const;

function DiffSide({ label, lines, marked, kind }: { label: string; lines: string[]; marked: Set<number>; kind: "add" | "remove" }) {
  return (
    <div className="diff-editor" role="region" aria-label={label}>
      <div className="diff-label">{label}</div>
      <div className="diff-content">
        {lines.length === 0 ? (
          <div className="diff-line">
            <span className="diff-line-num" />
            <span className="sign" />
            <span className="query-hint">Boş</span>
          </div>
        ) : (
          lines.map((line, i) => {
            const on = marked.has(i);
            return (
              <div key={i} className={`diff-line${on ? ` ${kind}` : ""}`}>
                <span className="diff-line-num">{i + 1}</span>
                <span className="sign">{on ? (kind === "add" ? "+" : "−") : " "}</span>
                <span>{line || " "}</span>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

export default function DiffPage() {
  const { diffLeft, diffRight, setDiffLeft, setDiffRight, runDiff, diffEntries, diffError, diffRan, rawJson } =
    useJsonStore();

  const summary = summarizeDiff(diffEntries);
  const leftLines = useMemo(() => formatSide(diffLeft), [diffLeft]);
  const rightLines = useMemo(() => formatSide(diffRight), [diffRight]);
  // Satir vurgulari formatli metinlerin gercek LCS farkidir (canli guncellenir).
  const lines = useMemo(() => lineDiff(leftLines, rightLines), [leftLines, rightLines]);
  const changes = diffEntries.filter((d) => d.kind !== "unchanged");

  return (
    <div className="app-shell">
      <header className="toolbar">
        <div className="toolbar-brand">
          <BrandIcon />
          Diff
        </div>
        <div className="toolbar-actions">
          <button type="button" className="btn-primary" data-testid="btn-diff" onClick={runDiff} disabled={!diffLeft.trim() && !diffRight.trim()}>
            Karşılaştır
          </button>
          <button type="button" className="btn-ghost" onClick={() => setDiffLeft(rawJson)} disabled={!rawJson.trim()} title="Laboratuvar editöründeki JSON'u sola koy">
            Sol = editör
          </button>
          <button type="button" className="btn-ghost" onClick={() => setDiffRight(rawJson)} disabled={!rawJson.trim()} title="Laboratuvar editöründeki JSON'u sağa koy">
            Sağ = editör
          </button>
          <button
            type="button"
            className="btn-ghost"
            onClick={() => {
              setDiffLeft(diffRight);
              setDiffRight(diffLeft);
            }}
            disabled={!diffLeft && !diffRight}
            title="Sol ve sağı yer değiştir"
          >
            Değiştir ⇄
          </button>
        </div>
        <div className="toolbar-spacer" />
        {diffRan && !diffError && (
          <span className={`valid-badge badge-inline ${summary.total ? "warning" : "valid"}`} role="status" data-testid="diff-summary">
            <span className="dot" aria-hidden />
            {summary.total ? `+${summary.added} −${summary.removed} ~${summary.changed}` : "Fark yok"}
          </span>
        )}
        <ToolbarNav active="/diff" />
      </header>

      <main className="secondary-main" id="diff-root">
        <div className="split-2">
          <div className="input-panel diff-input-row">
            <label htmlFor="diff-left">Sol JSON</label>
            <textarea id="diff-left" spellCheck={false} value={diffLeft} onChange={(e) => setDiffLeft(e.target.value)} placeholder='{ "a": 1 }' />
          </div>
          <div className="input-panel diff-input-row diff-input-right">
            <label htmlFor="diff-right">Sağ JSON</label>
            <textarea id="diff-right" spellCheck={false} value={diffRight} onChange={(e) => setDiffRight(e.target.value)} placeholder='{ "a": 2 }' />
          </div>
        </div>
        {diffError && (
          <p className="diff-error" role="alert">
            {diffError}
          </p>
        )}
        <div className="split-grow">
          <div className="split-2" style={{ flex: 1, minHeight: 0 }}>
            <DiffSide label="Sol (formatlı)" lines={leftLines} marked={lines.removed} kind="remove" />
            <DiffSide label="Sağ (formatlı)" lines={rightLines} marked={lines.added} kind="add" />
          </div>
          {changes.length > 0 && (
            <ul className="result-list diff-paths" aria-label="Değişen yollar">
              {changes.slice(0, 200).map((d) => (
                <li key={d.path} className={d.kind === "added" ? "pass" : d.kind === "removed" ? "fail" : undefined}>
                  {KIND_SIGN[d.kind]} {d.path}
                </li>
              ))}
            </ul>
          )}
        </div>
      </main>

      <StatusBar
        left={
          <span className="statusbar-item mono">
            {diffRan && !diffError ? `${summary.total} değişiklik` : "- diff"}
          </span>
        }
        right={
          <>
            <span className="statusbar-item status-legend-add">+ ekleme</span>
            <span className="statusbar-item status-legend-remove">− silme</span>
          </>
        }
      />
    </div>
  );
}
