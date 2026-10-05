from __future__ import annotations

import csv
import json
import subprocess
from datetime import datetime
from html import escape
from pathlib import Path

from core.formatters import human_size, percent
from core.models import ScanNode


def export_json(node: ScanNode, dest: Path) -> None:
    payload = {
        "exported_at": datetime.now().isoformat(),
        "root": node.to_dict(),
    }
    dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def export_csv(node: ScanNode, dest: Path) -> None:
    rows = [
        ("path", "name", "size_bytes", "size_human", "file_count", "is_dir", "category", "percent_of_root")
    ]
    root_size = max(node.size, 1)
    for item in node.iter_flat():
        rows.append(
            (
                item.path,
                item.name,
                str(item.size),
                human_size(item.size),
                str(item.file_count),
                "yes" if item.is_dir else "no",
                item.category,
                f"{percent(item.size, root_size):.2f}",
            )
        )
    with dest.open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerows(rows)


def export_html(node: ScanNode, dest: Path, *, chart_png_path: str | None = None) -> None:
    rows = []
    root_size = max(node.size, 1)
    for child in node.sorted_children()[:50]:
        rows.append(
            f"<tr><td>{escape(child.name)}</td>"
            f"<td>{human_size(child.size)}</td>"
            f"<td>{percent(child.size, root_size):.1f}%</td>"
            f"<td class='path'>{escape(child.path)}</td></tr>"
        )

    img = ""
    if chart_png_path:
        img = f'<img src="{escape(Path(chart_png_path).name)}" alt="chart" class="chart"/>'

    html = f"""<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8"/>
<title>Disk Raporu — {escape(node.name)}</title>
<style>
body {{ font-family: Inter, Segoe UI, sans-serif; background:#0d1117; color:#8b949e; padding:32px; }}
h1 {{ color:#f0f6fc; }}
.summary {{ font-size:28px; color:#58a6ff; font-weight:700; }}
table {{ width:100%; border-collapse:collapse; margin-top:24px; }}
th, td {{ text-align:left; padding:10px; border-bottom:1px solid #30363d; }}
th {{ color:#f0f6fc; }}
.path {{ font-family: JetBrains Mono, monospace; font-size:11px; color:#484f58; }}
.chart {{ max-width:640px; border-radius:12px; border:1px solid #30363d; margin:24px 0; }}
</style>
</head>
<body>
<h1>Disk Alan Raporu</h1>
<p class="summary">{human_size(node.size)} — {escape(node.path)}</p>
<p>Dışa aktarma: {datetime.now().strftime("%Y-%m-%d %H:%M")}</p>
{img}
<table>
<thead><tr><th>Ad</th><th>Boyut</th><th>%</th><th>Yol</th></tr></thead>
<tbody>{''.join(rows)}</tbody>
</table>
</body>
</html>"""
    dest.write_text(html, encoding="utf-8")


def reveal_in_explorer(path: str) -> None:
    p = Path(path)
    if p.is_file():
        subprocess.run(["explorer", "/select,", str(p.resolve())], check=False)
    else:
        subprocess.run(["explorer", str(p.resolve())], check=False)


def move_to_trash(path: str) -> None:
    from send2trash import send2trash

    send2trash(path)
