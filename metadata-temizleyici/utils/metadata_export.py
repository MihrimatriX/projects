from __future__ import annotations

import json
from pathlib import Path

from utils.metadata import read_metadata_tags


def export_tags_json(path: Path, dest: Path) -> None:
    tags = read_metadata_tags(path)
    payload = {
        "file": str(path.resolve()),
        "tag_count": len(tags),
        "high_risk_count": sum(1 for t in tags if t.risk == "high"),
        "tags": [
            {"name": t.name, "label": t.label, "value": t.value, "risk": t.risk}
            for t in tags
        ],
    }
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
