import type { ViewMode } from "../types";

type Props = {
  mode: ViewMode;
  threeWayAvailable: boolean;
  hexAvailable: boolean;
  onChange: (mode: ViewMode) => void;
};

export function ViewTabs({ mode, threeWayAvailable, hexAvailable, onChange }: Props) {
  return (
    <div className="view-tabs" role="tablist">
      <button
        type="button"
        role="tab"
        className={`tab${mode === "side-by-side" ? " active" : ""}`}
        aria-selected={mode === "side-by-side"}
        onClick={() => onChange("side-by-side")}
      >
        Yan Yana
      </button>
      <button
        type="button"
        role="tab"
        className={`tab${mode === "inline" ? " active" : ""}`}
        aria-selected={mode === "inline"}
        onClick={() => onChange("inline")}
      >
        Satır İçi
      </button>
      <button
        type="button"
        role="tab"
        className={`tab${mode === "three-way" ? " active" : ""}`}
        aria-selected={mode === "three-way"}
        disabled={!threeWayAvailable}
        title={threeWayAvailable ? "Base + sol + sağ" : "Base yolu ayarlardan girin"}
        onClick={() => onChange("three-way")}
      >
        3-Yönlü Birleştir
      </button>
      <button
        type="button"
        role="tab"
        className={`tab tab-end${mode === "hex" ? " active" : ""}`}
        aria-selected={mode === "hex"}
        disabled={!hexAvailable}
        title={hexAvailable ? "Binary hex görünüm" : "Yalnızca binary dosyalarda"}
        onClick={() => onChange("hex")}
      >
        Hex Görünüm
      </button>
    </div>
  );
}
