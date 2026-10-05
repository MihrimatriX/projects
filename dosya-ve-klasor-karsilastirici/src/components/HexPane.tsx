type Props = {
  leftHex: string;
  rightHex: string;
  leftSize: number;
  rightSize: number;
  truncated: boolean;
  leftLabel?: string;
  rightLabel?: string;
};

export function HexPane({
  leftHex,
  rightHex,
  leftSize,
  rightSize,
  truncated,
  leftLabel,
  rightLabel,
}: Props) {
  return (
    <>
      {truncated && (
        <div className="warn-banner show">Önizleme 256 KB ile sınırlıdır.</div>
      )}
      <div className="hex-panes">
        <div className="hex-pane">
          <div className="hex-pane-header">
            Sol{leftLabel ? ` — ${shortName(leftLabel)}` : ""} ({leftSize.toLocaleString("tr")} bayt)
          </div>
          <pre className="hex-content">{leftHex || "(boş)"}</pre>
        </div>
        <div className="hex-pane">
          <div className="hex-pane-header">
            Sağ{rightLabel ? ` — ${shortName(rightLabel)}` : ""} ({rightSize.toLocaleString("tr")} bayt)
          </div>
          <pre className="hex-content">{rightHex || "(boş)"}</pre>
        </div>
      </div>
    </>
  );
}

function shortName(p: string): string {
  const parts = p.replace(/\\/g, "/").split("/");
  return parts[parts.length - 1] || p;
}
