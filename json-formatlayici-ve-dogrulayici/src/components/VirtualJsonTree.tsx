"use client";

import { useRef, useMemo } from "react";
import { useVirtualizer } from "@tanstack/react-virtual";
import { useJsonStore } from "@/lib/store";
import { pointerToJsonPath } from "@/lib/json-utils";
import { buildFlatTree, type FlatTreeRow } from "@/lib/tree-flat";

function RowContent({
  row,
  isHighlighted,
  isExpanded,
  onToggle,
  onCopyPath,
  onCopyPointer,
  onCopyValue,
}: {
  row: FlatTreeRow;
  isHighlighted: boolean;
  isExpanded: boolean;
  onToggle: () => void;
  onCopyPath: () => void;
  onCopyPointer: () => void;
  onCopyValue: () => void;
}) {
  const pad = { paddingLeft: `${row.depth * 16 + 8}px` };

  if (row.kind === "close") {
    return (
      <div style={pad} className="py-0.5 text-[var(--text-muted)] text-xs">
        {row.isArray ? "]" : "}"}
      </div>
    );
  }

  if (row.kind === "branch") {
    return (
      <div
        style={pad}
        className={`group flex items-center py-1 rounded cursor-pointer select-none text-xs font-mono ${
          isHighlighted ? "bg-[var(--error)]/15 border border-[var(--border-focus)]/25" : "hover:bg-[var(--bg-hover)]/30"
        }`}
        role={row.childCount > 0 ? "button" : undefined}
        tabIndex={row.childCount > 0 ? 0 : undefined}
        aria-expanded={row.childCount > 0 ? isExpanded : undefined}
        onClick={() => row.childCount > 0 && onToggle()}
        onKeyDown={(e) => {
          if (row.childCount > 0 && e.target === e.currentTarget && (e.key === "Enter" || e.key === " ")) {
            e.preventDefault();
            onToggle();
          }
        }}
      >
        <span className={`mr-1 text-[9px] text-[var(--text-muted)] ${isExpanded ? "rotate-90 inline-block" : ""}`}>
          {row.childCount > 0 ? "▶" : " "}
        </span>
        {row.name && <span className="text-[var(--text-primary)] mr-1">{row.name}:</span>}
        <span className="text-[var(--text-muted)]">
          {row.isArray ? "[" : "{"}
          {!isExpanded && (
            <span className="text-[var(--error)]/80 font-semibold px-1 mx-1 bg-[var(--error-bg)] rounded text-[10px]">
              {row.childCount} {row.isArray ? "eleman" : "anahtar"}
            </span>
          )}
          {!isExpanded && (row.isArray ? "]" : "}")}
        </span>
        <span className="ml-2 inline-flex gap-1 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100">
          <button type="button" aria-label={`${row.name || "kök"}: JSONPath kopyala`} onClick={(e) => { e.stopPropagation(); onCopyPath(); }} className="text-[9px] text-[var(--error)]">Path</button>
          <button type="button" aria-label={`${row.name || "kök"}: JSON Pointer kopyala`} onClick={(e) => { e.stopPropagation(); onCopyPointer(); }} className="text-[9px] text-[var(--syntax-key)]">Ptr</button>
        </span>
      </div>
    );
  }

  const val = row.value;
  let valueNode: React.ReactNode;
  if (val === null) valueNode = <span className="italic text-[var(--text-muted)]">null</span>;
  else if (typeof val === "boolean")
    valueNode = <span className={val ? "text-[var(--success)]" : "text-[var(--error)]"}>{String(val)}</span>;
  else if (typeof val === "number") valueNode = <span className="text-[var(--warning)]">{val}</span>;
  else valueNode = <span className="text-[var(--syntax-key)] break-all">&quot;{String(val)}&quot;</span>;

  return (
    <div
      style={pad}
      className={`group flex items-center py-0.5 text-xs font-mono rounded ${
        isHighlighted ? "bg-[var(--error)]/15 border border-dashed border-[var(--border-focus)]/30" : ""
      }`}
    >
      {row.name && <span className="text-[var(--text-primary)] mr-1">{row.name}:</span>}
      {valueNode}
      <span className="ml-2 inline-flex gap-1 opacity-0 group-hover:opacity-100 group-focus-within:opacity-100">
        <button type="button" aria-label={`${row.name}: JSONPath kopyala`} onClick={onCopyPath} className="text-[9px] text-[var(--error)]">Path</button>
        <button type="button" aria-label={`${row.name}: JSON Pointer kopyala`} onClick={onCopyPointer} className="text-[9px] text-[var(--syntax-key)]">Ptr</button>
        <button type="button" aria-label={`${row.name}: değeri kopyala`} onClick={onCopyValue} className="text-[9px] text-[var(--warning)]">Kopyala</button>
      </span>
    </div>
  );
}

// Pano yazimi; izin yoksa sessizce yok sayilir.
const copyText = (s: string) => navigator.clipboard.writeText(s).catch(() => {});

export default function VirtualJsonTree() {
  const {
    parsedJson,
    isValid,
    expandedPaths,
    togglePath,
    searchQuery,
    setSearchQuery,
    expandAll,
    collapseAll,
    jsonPathHighlight,
  } = useJsonStore();

  const parentRef = useRef<HTMLDivElement>(null);

  const flatRows = useMemo(() => {
    if (parsedJson === null) return [];
    return buildFlatTree(parsedJson, expandedPaths, { highlightPaths: jsonPathHighlight });
  }, [parsedJson, expandedPaths, jsonPathHighlight]);

  const virtualizer = useVirtualizer({
    count: flatRows.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 28,
    overscan: 12,
  });

  const matchesSearch = (row: FlatTreeRow) => {
    if (!searchQuery) return false;
    const q = searchQuery.toLowerCase();
    if (row.name.toLowerCase().includes(q)) return true;
    if (row.kind === "primitive" && String(row.value).toLowerCase().includes(q)) return true;
    return false;
  };

  if (!isValid) {
    return (
      <div className="tree-scroll">
        <div className="tree-empty">Geçerli JSON gerekli</div>
      </div>
    );
  }

  if (parsedJson === null) {
    return (
      <div className="tree-scroll">
        <div className="tree-empty">JSON girin veya yapıştırın</div>
      </div>
    );
  }

  return (
    <div className="tree-scroll flex flex-col min-h-0 flex-1">
      <div className="flex items-center gap-2 px-3 py-2 border-b border-[var(--border)] shrink-0">
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Ağaçta ara…"
          aria-label="Ağaçta ara"
          className="flex-1 text-xs bg-[var(--bg-input)] border border-[var(--border)] rounded px-2 py-1 outline-none focus:shadow-[var(--focus-ring)]"
        />
        <button type="button" className="btn-ghost" style={{ height: 28, padding: "0 8px", fontSize: 11 }} onClick={expandAll} title="Tüm düğümleri genişlet">
          Genişlet
        </button>
        <button type="button" className="btn-ghost" style={{ height: 28, padding: "0 8px", fontSize: 11 }} onClick={collapseAll} title="Tüm düğümleri daralt">
          Daralt
        </button>
      </div>

      <div ref={parentRef} className="flex-1 overflow-auto min-h-0">
        <div style={{ height: `${virtualizer.getTotalSize()}px`, position: "relative" }}>
          {virtualizer.getVirtualItems().map((vi) => {
            const row = flatRows[vi.index];
            const highlighted = jsonPathHighlight.has(row.path) || matchesSearch(row);
            return (
              <div
                key={row.id}
                style={{
                  position: "absolute",
                  top: 0,
                  left: 0,
                  width: "100%",
                  height: `${vi.size}px`,
                  transform: `translateY(${vi.start}px)`,
                }}
              >
                <RowContent
                  row={row}
                  isHighlighted={highlighted}
                  isExpanded={expandedPaths.has(row.path)}
                  onToggle={() => togglePath(row.path)}
                  onCopyPath={() => void copyText(pointerToJsonPath(row.path))}
                  onCopyPointer={() => void copyText(row.path)}
                  onCopyValue={() => {
                    const s =
                      typeof row.value === "object"
                        ? JSON.stringify(row.value, null, 2)
                        : String(row.value);
                    void copyText(s);
                  }}
                />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
