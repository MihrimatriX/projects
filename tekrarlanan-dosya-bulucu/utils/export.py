from __future__ import annotations

import csv
import json
from datetime import datetime
from pathlib import Path

from utils.duplicates import total_wasted_bytes
from utils.models import DuplicateGroup


def export_groups_json(groups: list[DuplicateGroup], dest: Path) -> None:
    payload = {
        "exported_at": datetime.now().isoformat(),
        "group_count": len(groups),
        "wasted_bytes": total_wasted_bytes(groups),
        "groups": [
            {
                "hash": g.hash_hex,
                "size": g.size,
                "is_hardlink_group": g.is_hardlink_group,
                "files": [
                    {
                        "path": f.path,
                        "marked_for_delete": f.marked_for_delete,
                        "is_keeper": f.is_keeper,
                        "preview": f.preview,
                    }
                    for f in g.files
                ],
            }
            for g in groups
        ],
    }
    dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def export_groups_csv(groups: list[DuplicateGroup], dest: Path) -> None:
    rows = [
        (
            "group_hash",
            "file_size",
            "path",
            "is_keeper",
            "marked_for_delete",
            "is_hardlink_group",
            "preview",
        )
    ]
    for g in groups:
        for f in g.files:
            rows.append(
                (
                    g.hash_hex,
                    str(g.size),
                    f.path,
                    "yes" if f.is_keeper else "no",
                    "yes" if f.marked_for_delete else "no",
                    "yes" if g.is_hardlink_group else "no",
                    f.preview or "",
                )
            )
    with dest.open("w", newline="", encoding="utf-8-sig") as handle:
        csv.writer(handle).writerows(rows)


def export_groups_html(groups: list[DuplicateGroup], dest: Path) -> None:
    from html import escape
    from utils.formatters import human_size

    rows = []
    for g in groups:
        for f in g.files:
            mark = "sil" if f.marked_for_delete else ("tut" if f.is_keeper else "")
            rows.append(
                f"<tr><td>{escape(g.hash_short)}</td>"
                f"<td>{human_size(g.size)}</td>"
                f"<td class='path'>{escape(f.path)}</td>"
                f"<td>{mark}</td></tr>"
            )
    wasted = human_size(total_wasted_bytes(groups))
    html = f"""<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="utf-8"/>
<title>Tekrarlanan Dosya Raporu</title>
<style>
body {{ font-family: Inter, Segoe UI, sans-serif; background:#0f1419; color:#e7ecf3; padding:24px; }}
h1 {{ font-size:20px; }}
.summary {{ color:#00ba7c; font-weight:600; margin:12px 0 24px; }}
table {{ width:100%; border-collapse:collapse; }}
th, td {{ text-align:left; padding:8px; border-bottom:1px solid #2f3b4a; font-size:13px; }}
th {{ color:#8899a6; }}
.path {{ font-family: JetBrains Mono, monospace; font-size:11px; word-break:break-all; }}
</style>
</head>
<body>
<h1>Tekrarlanan Dosya Bulucu — Rapor</h1>
<p class="summary">{len(groups)} grup · Tahmini kazanç: {wasted}</p>
<p>Oluşturulma: {datetime.now().strftime("%Y-%m-%d %H:%M")}</p>
<table>
<thead><tr><th>Hash</th><th>Boyut</th><th>Yol</th><th>Durum</th></tr></thead>
<tbody>{''.join(rows)}</tbody>
</table>
</body>
</html>"""
    dest.write_text(html, encoding="utf-8")
