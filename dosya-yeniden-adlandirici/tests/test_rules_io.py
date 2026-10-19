from __future__ import annotations

from pathlib import Path

from core.models import Rule, RuleType
from core.rules_io import export_rules_json, import_rules_json


def test_rules_json_roundtrip(tmp_path: Path):
    rules = [
        Rule(rule_type=RuleType.NUMBERING, pad=2, condition_ext="jpg"),
        Rule(pattern="a", replacement="b", use_regex=True),
    ]
    path = tmp_path / "rules.json"
    export_rules_json(rules, path)
    loaded = import_rules_json(path)
    assert len(loaded) == 2
    assert loaded[0].rule_type == RuleType.NUMBERING
    assert loaded[0].condition_ext == "jpg"
    assert loaded[1].use_regex is True
