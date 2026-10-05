from __future__ import annotations

import json
from pathlib import Path

from core.settings import rules_from_list, rules_to_list
from core.models import Rule


def export_rules_json(rules: list[Rule], path: Path) -> None:
    path.write_text(
        json.dumps(rules_to_list(rules), indent=2, ensure_ascii=False),
        encoding="utf-8",
    )


def import_rules_json(path: Path) -> list[Rule]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        raise ValueError("Geçersiz kural dosyası: kök dizi olmalı")
    return rules_from_list(data)
