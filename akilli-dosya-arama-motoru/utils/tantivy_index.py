"""Tantivy birincil dosya adı indeksi — Faz 3 tamamlama."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import threading
import time
from pathlib import Path

from utils.excludes import should_skip_dir, should_skip_file
from utils.config import DATA_DIR
from utils.settings import get_search_roots

_DB_DIR = DATA_DIR
_INDEX_DIR = _DB_DIR / "tantivy_index"
_META_PATH = _DB_DIR / "tantivy_meta.json"

DeltaEvent = tuple  # ('add'|'del'|'del_tree'|'move', path, ...)

_index_lock = threading.RLock()
_schema = None


def _tantivy():
    import tantivy  # noqa: PLC0415

    return tantivy


def _build_schema():
    global _schema
    if _schema is not None:
        return _schema
    tantivy = _tantivy()
    builder = tantivy.SchemaBuilder()
    builder.add_text_field("name", stored=True)
    builder.add_text_field("path", stored=True, tokenizer_name="raw")
    _schema = builder.build()
    return _schema


def _index_has_data() -> bool:
    if not _INDEX_DIR.is_dir():
        return False
    try:
        return any(_INDEX_DIR.iterdir())
    except OSError:
        return False


def _open_index(*, create: bool = False):
    tantivy = _tantivy()
    schema = _build_schema()
    _DB_DIR.mkdir(parents=True, exist_ok=True)
    if create and _INDEX_DIR.exists():
        shutil.rmtree(_INDEX_DIR, ignore_errors=True)
    _INDEX_DIR.mkdir(parents=True, exist_ok=True)
    return tantivy.Index(schema, path=str(_INDEX_DIR))


def _normalize_path(path: Path | str) -> str:
    return str(Path(path).expanduser().resolve())


def _roots_signature(roots: list[Path]) -> str:
    joined = "|".join(sorted(str(r.resolve()) for r in roots))
    return hashlib.sha256(joined.encode()).hexdigest()[:16]


def _load_meta() -> dict:
    if not _META_PATH.exists():
        return {}
    try:
        return json.loads(_META_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return {}


def _save_meta(*, count: int, roots: list[Path] | None = None) -> None:
    meta = _load_meta()
    meta["built_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
    meta["count"] = count
    if roots is not None:
        meta["roots_sig"] = _roots_signature(roots)
    _META_PATH.write_text(json.dumps(meta, indent=2, ensure_ascii=False), encoding="utf-8")


def index_ready() -> bool:
    if not _index_has_data():
        return False
    meta = _load_meta()
    return int(meta.get("count", 0)) > 0


def get_index_stats() -> dict:
    meta = _load_meta()
    return {
        "count": int(meta.get("count", 0)),
        "built_at": meta.get("built_at"),
    }


def _doc_for(name: str, path: str):
    tantivy = _tantivy()
    return tantivy.Document(name=[name], path=[path])


def _safe_delete_term(writer, path: str) -> None:
    try:
        writer.delete_documents_by_term("path", path)
    except AttributeError:
        try:
            writer.delete_documents("path", path)
        except Exception:
            pass
    except Exception:
        pass


def _paths_with_prefix(index, prefix: str) -> list[str]:
    """Writer açılmadan önce okuma — reload writer oturumu dışında."""
    root = _normalize_path(prefix)
    tree_prefix = root.rstrip(os.sep) + os.sep
    index.reload()
    try:
        searcher = index.searcher()
        total = int(searcher.num_docs)
    except (AttributeError, TypeError, ValueError):
        return []
    if total <= 0:
        return []
    try:
        query = index.parse_query("*", ["path"])
        hits = searcher.search(query, min(total, 500_000)).hits
    except Exception:
        return []

    matched: list[str] = []
    for _, addr in hits:
        try:
            doc = searcher.doc(addr)
            path = doc["path"][0]
        except Exception:
            continue
        if path == root or path.startswith(tree_prefix):
            matched.append(path)
    return matched


def _count_docs(index) -> int:
    index.reload()
    try:
        return int(index.searcher().num_docs)
    except (AttributeError, TypeError, ValueError):
        return get_index_stats()["count"]


def _finish_writer(writer, index) -> None:
    writer.commit()
    if hasattr(writer, "wait_merging_threads"):
        writer.wait_merging_threads()
    del writer
    index.reload()


def build_index(
    roots: list[Path] | None = None,
    *,
    on_progress=None,
    cancel_check=None,
) -> int:
    root_list = list(roots) if roots else get_search_roots()
    root_list = [r.resolve() for r in root_list if r.exists()]
    if not root_list:
        raise FileNotFoundError("İndeks için en az bir geçerli klasör gerekli.")

    total_added = 0
    scanned = 0

    with _index_lock:
        index = _open_index(create=True)
        writer = index.writer(heap_size=50_000_000, num_threads=1)
        batch: list = []

        try:
            for root_path in root_list:
                if cancel_check and cancel_check():
                    break
                for dirpath, dirnames, filenames in os.walk(root_path):
                    if cancel_check and cancel_check():
                        break
                    dirnames[:] = [d for d in dirnames if not should_skip_dir(d)]
                    for name in filenames:
                        if cancel_check and cancel_check():
                            break
                        path = Path(dirpath) / name
                        if should_skip_file(path):
                            continue
                        try:
                            key = str(path.resolve())
                        except OSError:
                            continue
                        batch.append(_doc_for(name, key))
                        scanned += 1
                        if len(batch) >= 500:
                            for doc in batch:
                                writer.add_document(doc)
                            total_added += len(batch)
                            batch.clear()
                            _finish_writer(writer, index)
                            writer = index.writer(heap_size=50_000_000, num_threads=1)
                        if on_progress and scanned % 200 == 0:
                            on_progress(scanned)
                    if cancel_check and cancel_check():
                        break

            if batch:
                for doc in batch:
                    writer.add_document(doc)
                total_added += len(batch)

            _finish_writer(writer, index)
        except Exception:
            try:
                del writer
            except Exception:
                pass
            raise

        _save_meta(count=_count_docs(index), roots=root_list)

    return total_added


def apply_delta_batch(events: list[DeltaEvent]) -> int:
    if not events:
        return get_index_stats()["count"]

    with _index_lock:
        index = _open_index()
        index.reload()

        tree_paths: list[str] = []
        normal_events: list[DeltaEvent] = []
        for ev in events:
            if ev[0] == "del_tree":
                tree_paths.extend(_paths_with_prefix(index, ev[1]))
            else:
                normal_events.append(ev)

        writer = index.writer(heap_size=15_000_000, num_threads=1)
        changed = False

        try:
            for path in tree_paths:
                _safe_delete_term(writer, path)
                changed = True

            for ev in normal_events:
                kind = ev[0]
                if kind == "add":
                    path = Path(ev[1])
                    if path.is_file() and not should_skip_file(path):
                        key = _normalize_path(path)
                        _safe_delete_term(writer, key)
                        writer.add_document(_doc_for(path.name, key))
                        changed = True
                elif kind == "del":
                    try:
                        _safe_delete_term(writer, _normalize_path(ev[1]))
                        changed = True
                    except OSError:
                        continue
                elif kind == "move":
                    try:
                        _safe_delete_term(writer, _normalize_path(ev[1]))
                    except OSError:
                        pass
                    dest = Path(ev[2])
                    if dest.is_file() and not should_skip_file(dest):
                        key = _normalize_path(dest)
                        writer.add_document(_doc_for(dest.name, key))
                        changed = True

            if changed:
                _finish_writer(writer, index)
                _save_meta(count=_count_docs(index))
            else:
                del writer
        except Exception:
            try:
                del writer
            except Exception:
                pass
            raise

    return get_index_stats()["count"]


def list_index_candidates(query: str, *, max_rows: int = 10000) -> list[tuple[str, str]]:
    if not index_ready():
        return []

    q = query.strip().lower()
    # Tam indeks kurulurken (build_index kilidi dakikalarca tutar) arama beklemesin;
    # boş dönünce file_search FTS5 katmanına düşer.
    if not _index_lock.acquire(blocking=False):
        return []
    try:
        index = _open_index()
        index.reload()
        try:
            searcher = index.searcher()
        except Exception:
            return []

        if len(q) >= 2:
            tantivy_q = f"name:{q[:2]}*"
        elif len(q) == 1:
            tantivy_q = f"name:{q}*"
        else:
            tantivy_q = "*"

        try:
            parsed = index.parse_query(tantivy_q, ["name"])
            hits = searcher.search(parsed, max_rows).hits
        except Exception:
            return []

        rows: list[tuple[str, str]] = []
        for _, addr in hits:
            try:
                doc = searcher.doc(addr)
                name = doc["name"][0]
                path = doc["path"][0]
            except Exception:
                continue
            if q and q not in name.lower() and not name.lower().startswith(q[: min(2, len(q))]):
                continue
            rows.append((name, path))
            if len(rows) >= max_rows:
                break
        return rows
    finally:
        _index_lock.release()


def search_index(
    query: str,
    *,
    extension: str | None = None,
    limit: int = 50,
) -> list[tuple[str, str]]:
    if not index_ready():
        return []

    needle = query.strip()
    if not needle and not extension:
        return []

    # Tam indeks kurulurken (build_index kilidi dakikalarca tutar) arama beklemesin;
    # boş dönünce file_search FTS5 katmanına düşer.
    if not _index_lock.acquire(blocking=False):
        return []
    try:
        index = _open_index()
        index.reload()
        try:
            searcher = index.searcher()
        except Exception:
            return []

        if needle:
            terms = [t for t in needle.split() if t]
            tantivy_q = " AND ".join(f"name:{t}*" for t in terms)
        else:
            tantivy_q = "*"

        try:
            parsed = index.parse_query(tantivy_q, ["name"])
            hits = searcher.search(parsed, limit * 3).hits
        except Exception:
            return []

        rows: list[tuple[str, str]] = []
        for _, addr in hits:
            try:
                doc = searcher.doc(addr)
                name = doc["name"][0]
                path = doc["path"][0]
            except Exception:
                continue
            if extension and not name.lower().endswith(f".{extension.lower()}"):
                continue
            rows.append((name, path))
            if len(rows) >= limit:
                break
        return rows
    finally:
        _index_lock.release()


def export_index(dest: Path) -> Path:
    if not index_ready():
        raise FileNotFoundError("Tantivy indeksi yok — önce yeniden indeksleyin.")
    dest = dest.expanduser().resolve()
    dest.parent.mkdir(parents=True, exist_ok=True)
    with _index_lock:
        if dest.suffix.lower() == ".zip":
            archive = dest.with_suffix("")
            if archive.exists():
                shutil.rmtree(archive, ignore_errors=True)
            shutil.copytree(_INDEX_DIR, archive / "tantivy_index")
            shutil.copy2(_META_PATH, archive / "tantivy_meta.json")
            shutil.make_archive(str(archive), "zip", archive)
            shutil.rmtree(archive, ignore_errors=True)
            return dest
        folder = dest
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / "tantivy_index"
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(_INDEX_DIR, target)
        shutil.copy2(_META_PATH, folder / "tantivy_meta.json")
        return folder


def import_index(src: Path) -> None:
    src = src.expanduser().resolve()
    with _index_lock:
        if src.suffix.lower() == ".zip":
            import tempfile

            with tempfile.TemporaryDirectory() as tmp:
                shutil.unpack_archive(str(src), tmp)
                root = Path(tmp)
                idx = root / "tantivy_index"
                meta = root / "tantivy_meta.json"
                if not idx.is_dir():
                    raise FileNotFoundError("Geçersiz Tantivy yedeği — tantivy_index klasörü yok.")
                _DB_DIR.mkdir(parents=True, exist_ok=True)
                if _INDEX_DIR.exists():
                    shutil.rmtree(_INDEX_DIR)
                shutil.copytree(idx, _INDEX_DIR)
                if meta.is_file():
                    shutil.copy2(meta, _META_PATH)
            return

        idx = src / "tantivy_index" if src.is_dir() else src
        meta = src / "tantivy_meta.json" if src.is_dir() else _META_PATH
        if not Path(idx).is_dir():
            raise FileNotFoundError(f"Tantivy indeks klasörü bulunamadı: {src}")
        _DB_DIR.mkdir(parents=True, exist_ok=True)
        if _INDEX_DIR.exists():
            shutil.rmtree(_INDEX_DIR)
        shutil.copytree(idx, _INDEX_DIR)
        if Path(meta).is_file():
            shutil.copy2(meta, _META_PATH)


def remove_file(path: Path | str) -> None:
    apply_delta_batch([("del", str(path))])


def remove_tree(dir_path: Path | str) -> None:
    apply_delta_batch([("del_tree", str(dir_path))])


def index_file(path: Path | str) -> bool:
    p = Path(path)
    if not p.is_file() or should_skip_file(p):
        return False
    apply_delta_batch([("add", str(p))])
    return True
