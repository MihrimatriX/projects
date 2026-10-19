"use client";

import { AstTreeNode, useRegexStore } from "@/lib/store";

const typeColors: Record<string, string> = {
  Alternative: "border-[var(--border)] text-[var(--text-primary)]",
  Assertion: "border-amber-500/40 text-[var(--warning)]",
  Char: "border-[var(--border)] text-[var(--text-primary)]",
  CharacterClass: "border-cyan-500/40 text-[var(--syntax-quant)]",
  ClassRange: "border-cyan-500/30 text-cyan-200",
  Quantifier: "border-emerald-500/40 text-emerald-300",
  Group: "border-[var(--border-focus)]/40 text-[var(--accent)]",
  Disjunction: "border-pink-500/40 text-pink-300",
};

function TreeNode({ node, depth = 0 }: { node: AstTreeNode; depth?: number }) {
  const color = typeColors[node.type] || "border-[var(--border)] text-[var(--text-primary)]";

  return (
    <li className="relative">
      <div
        className={`flex items-start gap-2 py-1.5 px-2 rounded-md border bg-[var(--bg-editor)] ${color}`}
        style={{ marginLeft: depth * 16 }}
      >
        <span className="text-[9px] uppercase tracking-wide opacity-60 shrink-0 mt-0.5">
          {node.type}
        </span>
        <div className="flex-1 min-w-0">
          <span className="text-xs font-semibold block">{node.label}</span>
          {node.snippet && (
            <code className="text-[10px] font-mono opacity-70">{node.snippet}</code>
          )}
        </div>
      </div>
      {node.children.length > 0 && (
        <ul className="mt-1 space-y-1 border-l border-[var(--border)] ml-4 pl-2">
          {node.children.map((child) => (
            <TreeNode key={child.id} node={child} depth={depth + 1} />
          ))}
        </ul>
      )}
    </li>
  );
}

export default function AstTreeView() {
  const { astTree, isValid, pattern } = useRegexStore();

  if (!isValid) {
    return (
      <div className="flex flex-col items-center justify-center p-8 bg-[var(--bg-editor)] border border-[var(--border)] rounded-lg h-full min-h-[250px]">
        <span className="text-4xl mb-3">⚠️</span>
        <span className="text-sm font-semibold text-[var(--text-primary)] mb-1">Ağaç Oluşturulamadı</span>
        <p className="text-xs text-[var(--text-muted)] text-center max-w-[280px]">
          Geçerli bir regex yazın; AST ağacı burada görselleştirilecek.
        </p>
      </div>
    );
  }

  if (!pattern) {
    return (
      <div className="flex flex-col items-center justify-center p-8 bg-[var(--bg-editor)] border border-[var(--border)] rounded-lg h-full min-h-[250px]">
        <span className="text-4xl mb-3">🌳</span>
        <span className="text-sm font-semibold text-[var(--text-primary)] mb-1">Regex Ağacı</span>
        <p className="text-xs text-[var(--text-muted)] text-center max-w-[280px]">
          Kalıbınızın sözdizim ağacını burada görün.
        </p>
      </div>
    );
  }

  return (
    <div className="w-full h-full border border-[var(--border)] rounded-lg overflow-hidden bg-[var(--bg-editor)] flex flex-col shadow-inner">
      <div className="flex items-center justify-between px-4 py-2.5 bg-[var(--bg-toolbar)] border-b border-[var(--border)] text-xs font-semibold text-[var(--text-secondary)] select-none">
        <span>🌳 Görsel Regex Ağacı (AST)</span>
        <span className="text-[10px] text-[var(--text-muted)]">{astTree.length} kök düğüm</span>
      </div>
      <div className="flex-1 overflow-auto p-4">
        {astTree.length === 0 ? (
          <p className="text-xs text-[var(--text-muted)] text-center py-8">
            AST ağacı üretilemedi.
          </p>
        ) : (
          <ul className="space-y-2">
            {astTree.map((node) => (
              <TreeNode key={node.id} node={node} />
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
