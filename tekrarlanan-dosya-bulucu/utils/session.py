from __future__ import annotations

import json
from pathlib import Path

from utils.models import DuplicateFile, DuplicateGroup


def save_session(groups: list[DuplicateGroup], dest: Path) -> None:
    payload = [
        {
            "hash_hex": g.hash_hex,
            "size": g.size,
            "is_hardlink_group": g.is_hardlink_group,
            "files": [
                {
                    "path": f.path,
                    "size": f.size,
                    "mtime": f.mtime,
                    "inode": f.inode,
                    "device": f.device,
                    "marked_for_delete": f.marked_for_delete,
                    "is_keeper": f.is_keeper,
                    "preview": f.preview,
                }
                for f in g.files
            ],
        }
        for g in groups
    ]
    dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def load_session(path: Path) -> list[DuplicateGroup]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("Geçersiz oturum dosyası")
    groups: list[DuplicateGroup] = []
    for item in data:
        files = [DuplicateFile(**f) for f in item["files"]]
        groups.append(
            DuplicateGroup(
                hash_hex=item["hash_hex"],
                size=item["size"],
                files=files,
                is_hardlink_group=item.get("is_hardlink_group", False),
            )
        )
    return groups
