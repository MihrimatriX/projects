import { useMemo, useState, type ReactNode } from "react";
import type { FileEntry, FileStatus } from "../types";
import { filterEntries } from "../utils/entries";
import { IconChevron, IconFile, IconFolder } from "./icons";

const STATUS_LABEL: Record<FileStatus, string> = {
  different: "Farklı",
  left_only: "Yalnızca sol",
  right_only: "Yalnızca sağ",
  identical: "Aynı",
};

const STATUS_CLASS: Record<FileStatus, string> = {
  different: "tag-diff",
  left_only: "tag-left",
  right_only: "tag-right",
  identical: "tag-same",
};

type TreeNode = {
  name: string;
  path: string;
  children: TreeNode[];
  entry?: FileEntry;
};

type Props = {
  entries: FileEntry[];
  selected: string | null;
  open: boolean;
  onSelect: (relativePath: string) => void;
  onReveal?: (relativePath: string, side: "left" | "right") => void;
};

function buildTree(entries: FileEntry[]): TreeNode[] {
  const root: TreeNode[] = [];

  for (const entry of entries) {
    const parts = entry.relativePath.replace(/\\/g, "/").split("/");
    let level = root;

    for (let i = 0; i < parts.length; i++) {
      const name = parts[i];
      const isFile = i === parts.length - 1;
      const path = parts.slice(0, i + 1).join("/");
      let node = level.find((n) => n.path === path);

      if (!node) {
        node = { name, path, children: [], entry: isFile ? entry : undefined };
        level.push(node);
      } else if (isFile) {
        node.entry = entry;
      }

      level = node.children;
    }
  }

  const sortNodes = (nodes: TreeNode[]) => {
    nodes.sort((a, b) => {
      const aDir = a.children.length > 0 || !a.entry;
      const bDir = b.children.length > 0 || !b.entry;
      if (aDir !== bDir) return aDir ? -1 : 1;
      return a.name.localeCompare(b.name, "tr");
    });
    nodes.forEach((n) => sortNodes(n.children));
  };
  sortNodes(root);
  return root;
}

function folderStatus(children: TreeNode[]): FileStatus | null {
  const statuses = new Set<FileStatus>();
  const collect = (nodes: TreeNode[]) => {
    for (const n of nodes) {
      if (n.entry) statuses.add(n.entry.status);
      if (n.children.length) collect(n.children);
    }
  };
  collect(children);
  if (statuses.has("different")) return "different";
  if (statuses.has("left_only")) return "left_only";
  if (statuses.has("right_only")) return "right_only";
  return statuses.has("identical") ? "identical" : null;
}

export function FolderTree({ entries, selected, open, onSelect, onReveal }: Props) {
  // Kök düzey klasörler varsayılan açık, alt klasörler kapalı; `toggled` bu varsayılanı tersine çevirir.
  const [toggled, setToggled] = useState<Set<string>>(() => new Set());
  const [showOnlyDiff, setShowOnlyDiff] = useState(true);
  const [query, setQuery] = useState("");
  const searching = !!query.trim();

  const visible = useMemo(
    () => filterEntries(entries, showOnlyDiff, query),
    [entries, showOnlyDiff, query]
  );

  const tree = useMemo(() => buildTree(visible), [visible]);
  const diffCount = entries.filter((e) => e.status !== "identical").length;

  function toggleExpand(path: string) {
    setToggled((prev) => {
      const next = new Set(prev);
      if (next.has(path)) next.delete(path);
      else next.add(path);
      return next;
    });
  }

  function renderNode(node: TreeNode, depth = 0): ReactNode {
    const isFolder = node.children.length > 0;
    // Arama varken eşleşmeler kapalı klasörde gizli kalmasın.
    const isOpen = searching || (depth === 0) !== toggled.has(node.path);
    const entry = node.entry;
    const status = entry?.status ?? (isFolder ? folderStatus(node.children) : null);
    const isChildSelected =
      !!selected && (selected === node.path || selected.startsWith(`${node.path}/`));

    if (isFolder && !entry) {
      return (
        <div key={node.path} className="tree-group">
          <div
            className={`tree-item${isChildSelected ? " selected" : ""}`}
            style={{ paddingLeft: 8 + depth * 12 }}
            tabIndex={0}
            role="treeitem"
            aria-expanded={isOpen}
            onClick={() => toggleExpand(node.path)}
            onKeyDown={(e) => e.key === "Enter" && toggleExpand(node.path)}
          >
            <IconChevron open={isOpen} />
            <IconFolder className="tree-icon" />
            <span className="tree-name">{node.name}/</span>
            {status && status !== "identical" && (
              <span className={`tag ${STATUS_CLASS[status]}`}>{STATUS_LABEL[status]}</span>
            )}
          </div>
          {isOpen && (
            <div className="tree-children open">
              {node.children.map((child) => renderNode(child, depth + 1))}
            </div>
          )}
        </div>
      );
    }

    if (!entry) return null;

    return (
      <div
        key={node.path}
        className={`tree-item${selected === entry.relativePath ? " selected" : ""}${
          entry.status === "identical" && showOnlyDiff ? " filtered" : ""
        }`}
        style={{ paddingLeft: 8 + depth * 12 + (isFolder ? 0 : 22) }}
        tabIndex={0}
        role="treeitem"
        onClick={() => onSelect(entry.relativePath)}
        onKeyDown={(e) => e.key === "Enter" && onSelect(entry.relativePath)}
      >
        <IconFile className="tree-icon" />
        <span className="tree-name" title={entry.relativePath}>
          {node.name}
        </span>
        <span className={`tag ${STATUS_CLASS[entry.status]}`}>{STATUS_LABEL[entry.status]}</span>
        {onReveal && entry.status !== "right_only" && (
          <button
            type="button"
            className="tree-reveal"
            title="Dosyayı göster"
            aria-label={`${entry.relativePath} dosyasını klasörde göster`}
            onClick={(e) => {
              e.stopPropagation();
              onReveal(entry.relativePath, "left");
            }}
          >
            ↗
          </button>
        )}
      </div>
    );
  }

  return (
    <aside className={`sidebar${open ? " open" : ""}`}>
      <div className="sidebar-header">
        <span>Klasör Farkları</span>
        <span className="sidebar-count">{diffCount} fark</span>
      </div>
      <div className="tree-filter">
        <input
          type="search"
          className="tree-search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Dosya ara…"
          aria-label="Klasör ağacında dosya ara"
        />
        <label className="tree-toggle">
          <input
            type="checkbox"
            checked={!showOnlyDiff}
            onChange={(e) => setShowOnlyDiff(!e.target.checked)}
          />
          Aynı dosyaları da göster
        </label>
      </div>
      <nav className="tree" role="tree" aria-label="Klasör ağacı">
        {tree.length === 0 ? (
          <p className="tree-empty">{searching ? "Eşleşen dosya yok." : showOnlyDiff ? "Farklı dosya yok." : "Dosya bulunamadı."}</p>
        ) : (
          tree.map((node) => renderNode(node))
        )}
      </nav>
    </aside>
  );
}
