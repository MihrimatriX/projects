import os
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")


@pytest.fixture(autouse=True)
def isolated_home(tmp_path, monkeypatch):
    """Ayar, indeks ve geçmiş dosyalarını gerçek ~/.akilli-dosya-arama yerine tmp'ye yönlendir."""
    from utils import index_db, search_history, settings, tantivy_index

    data = tmp_path / "appdata"
    monkeypatch.setattr(settings, "_SETTINGS_DIR", data)
    monkeypatch.setattr(settings, "_SETTINGS_FILE", data / "settings.json")
    monkeypatch.setattr(index_db, "_DB_DIR", data)
    monkeypatch.setattr(index_db, "_DB_PATH", data / "fts_index.db")
    monkeypatch.setattr(search_history, "_HISTORY_FILE", data / "search_history.json")
    monkeypatch.setattr(tantivy_index, "_DB_DIR", data)
    monkeypatch.setattr(tantivy_index, "_INDEX_DIR", data / "tantivy_index")
    monkeypatch.setattr(tantivy_index, "_META_PATH", data / "tantivy_meta.json")
    return data


@pytest.fixture
def tree(tmp_path):
    root = tmp_path / "docs"
    (root / "alt").mkdir(parents=True)
    (root / "node_modules").mkdir()
    (root / "rapor_2024.txt").write_text("yillik butce ozeti", encoding="utf-8")
    (root / "alt" / "main.py").write_text("print('merhaba dunya')", encoding="utf-8")
    (root / "alt" / "notlar.md").write_text("toplanti gizli_kelime notu", encoding="utf-8")
    (root / "resim.png").write_bytes(b"\x89PNG")
    (root / "node_modules" / "rapor.js").write_text("x", encoding="utf-8")
    return root


@pytest.fixture
def fts_only(tree):
    from utils.settings import save_settings

    save_settings({"search_roots": [str(tree)], "tantivy_primary": False})
    return tree
