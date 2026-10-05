from pathlib import Path

import pytest

from utils import index_backend, index_db, search_history, tantivy_index
from utils.excludes import should_skip_dir, should_skip_file
from utils.file_search import parse_query, search_files
from utils.settings import load_settings, save_settings


def _names(results):
    return sorted(r.name for r in results)


def test_parse_query_modifiers():
    q = parse_query("rapor ext:TXT kod")
    assert (q.text, q.extension, q.code_only, q.content_only) == ("rapor", "txt", True, False)
    q = parse_query("gizli içerik")
    assert q.text == "gizli" and q.content_only


def test_settings_roundtrip_and_sanitizing(tmp_path):
    save_settings({"search_roots": [str(tmp_path)], "scheduled_reindex_hour": 27, "exclude_patterns": ["  "]})
    data = load_settings()
    assert data["search_roots"] == [str(tmp_path)]
    assert data["scheduled_reindex_hour"] == 3
    assert data["exclude_patterns"]  # boş liste varsayılanlara döner


def test_excludes():
    assert should_skip_dir("node_modules", [])
    assert should_skip_dir(".git", [])
    assert not should_skip_dir("src", [])
    assert should_skip_file(Path("a.tmp"), ["*.tmp"])


def test_fts_build_and_search(fts_only):
    assert index_db.build_index([fts_only]) == 4  # node_modules atlanır
    hits = index_db.search_index("rapor")
    assert [n for n, _ in hits] == ["rapor_2024.txt"]


def test_fts_extension_only_query_uses_index(fts_only):
    index_db.build_index([fts_only])
    assert [n for n, _ in index_db.search_index("", extension="py")] == ["main.py"]


def test_fts_query_with_quotes_does_not_crash(fts_only):
    index_db.build_index([fts_only])
    assert index_db.search_index('ra"por') == []


def test_build_cancel_stops_all_roots(fts_only, tmp_path):
    other = tmp_path / "other"
    other.mkdir()
    (other / "x.txt").write_text("x")
    assert index_db.build_index([fts_only, other], cancel_check=lambda: True) == 0


def test_delta_add_move_delete(fts_only):
    index_db.build_index([fts_only])
    new = fts_only / "yeni_dosya.txt"
    new.write_text("a")
    index_db.apply_delta_batch([("add", str(new))])
    assert index_db.search_index("yeni")
    moved = fts_only / "tasindi.txt"
    new.rename(moved)
    index_db.apply_delta_batch([("move", str(new), str(moved))])
    assert not index_db.search_index("yeni") and index_db.search_index("tasindi")
    index_db.apply_delta_batch([("del_tree", str(fts_only / "alt"))])
    assert not index_db.search_index("main")


def test_search_files_via_index(fts_only):
    index_backend.build_index([fts_only])
    results, _ms = search_files([fts_only], "rapor")
    assert "rapor_2024.txt" in _names(results)
    assert "rapor.js" not in _names(results)
    results, _ = search_files([fts_only], "ext:py")
    assert _names(results) == ["main.py"]


def test_search_files_walk_fallback_content_and_filter(fts_only):
    # İndeks yok -> os.walk yedeği; içerik eşleşmesi parça (snippet) döndürür.
    results, _ = search_files([fts_only], "gizli_kelime içerik")
    assert _names(results) == ["notlar.md"]
    assert results[0].match_kind == "content" and "gizli_kelime" in results[0].snippet
    results, _ = search_files([fts_only], "resim", file_type="images")
    assert _names(results) == ["resim.png"]
    results, _ = search_files([fts_only], "resim", file_type="code")
    assert results == []


def test_fuzzy_finds_typo(fts_only):
    from utils.fuzzy_search import fuzzy_search_index

    index_db.build_index([fts_only])
    names = [n for n, _, _ in fuzzy_search_index("raport")]
    assert "rapor_2024.txt" in names


def test_tantivy_build_and_search(tree):
    save_settings({"search_roots": [str(tree)], "tantivy_primary": True})
    assert tantivy_index.build_index([tree]) == 4
    assert [n for n, _ in tantivy_index.search_index("rapor")] == ["rapor_2024.txt"]


def test_search_history_recent_and_clear():
    search_history.record_search("a", 1, 1)  # çok kısa, kaydedilmez
    search_history.record_search("rapor", 3, 5)
    search_history.record_search("fatura", 1, 2)
    search_history.record_search("rapor", 4, 5)
    assert search_history.recent_queries() == ["rapor", "fatura"]
    search_history.clear_history()
    assert search_history.recent_queries() == []


def test_missing_root_raises(tmp_path):
    with pytest.raises(FileNotFoundError):
        search_files([tmp_path / "yok"], "x")
