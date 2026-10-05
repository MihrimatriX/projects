import type { RefObject } from "react";
import type { RequestFilters } from "../types";

const CHIPS = ["POST", "GET", "PUT", "PATCH", "DELETE"] as const;

type Props = {
  filters: RequestFilters;
  onChange: (f: RequestFilters) => void;
  inputRef?: RefObject<HTMLInputElement | null>;
};

export function FilterBar({ filters, onChange, inputRef }: Props) {
  function toggleMethod(method: string) {
    const methods = filters.methods.includes(method)
      ? filters.methods.filter((m) => m !== method)
      : [...filters.methods, method];
    onChange({ ...filters, methods });
  }

  function clear() {
    onChange({ methods: [], path: "" });
  }

  const hasFilter = filters.methods.length > 0 || filters.path.trim().length > 0;

  return (
    <div className="filter-bar" role="search">
      <input
        ref={inputRef}
        type="search"
        className="filter-input"
        placeholder="Path, gövde veya başlık ara… (/)"
        aria-label="İstek filtresi"
        value={filters.path}
        onChange={(e) => onChange({ ...filters, path: e.target.value })}
      />
      {CHIPS.map((m) => (
        <button
          key={m}
          type="button"
          className={`filter-chip ${filters.methods.includes(m) ? "active" : ""}`}
          aria-pressed={filters.methods.includes(m)}
          onClick={() => toggleMethod(m)}
        >
          {m}
        </button>
      ))}
      {hasFilter && (
        <button type="button" className="filter-clear" onClick={clear}>
          Filtreyi temizle
        </button>
      )}
    </div>
  );
}
