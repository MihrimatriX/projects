from __future__ import annotations

import html
import os
import re
import time
from dataclasses import dataclass
from pathlib import Path

from utils.config import (
    BINARY_SKIP_EXTENSIONS,
    CODE_EXTENSIONS,
    CONTENT_SEARCH_MAX_BYTES,
    DOCS_EXTENSIONS,
    IMAGE_EXTENSIONS,
    MAX_RESULTS,
    SNIPPET_MAX_BYTES,
    TEXT_EXTENSIONS,
)
from utils.excludes import should_skip_dir, should_skip_file


@dataclass
class SearchResult:
    path: Path
    name: str
    snippet: str | None = None
    match_kind: str = "name"  # name | content
    score: int = 0

    @property
    def display_path(self) -> str:
        try:
            rel = self.path.expanduser().resolve().relative_to(Path.home())
            return "~/" + rel.as_posix().replace("\\", "/")
        except ValueError:
            return str(self.path)

    @property
    def is_image(self) -> bool:
        return self.path.suffix.lower() in IMAGE_EXTENSIONS


@dataclass
class ParsedQuery:
    text: str
    extension: str | None = None
    code_only: bool = False
    content_only: bool = False
    file_type: str | None = None


def parse_query(raw: str) -> ParsedQuery:
    q = raw.strip()
    ext_match = re.search(r"\bext:(\w+)\b", q, re.IGNORECASE)
    extension = ext_match.group(1).lower() if ext_match else None
    if ext_match:
        q = (q[: ext_match.start()] + q[ext_match.end() :]).strip()
    tokens = raw.lower().split()
    code_only = "kod" in tokens
    content_only = "içerik" in tokens or "icerik" in tokens
    # Anahtar kelimeler aranan metnin parçası değil; kalırsa "foo içerik" birebir aranır.
    q = " ".join(t for t in q.split() if t.lower() not in ("kod", "içerik", "icerik"))
    return ParsedQuery(
        text=q,
        extension=extension,
        code_only=code_only,
        content_only=content_only,
    )


def highlight_name(name: str, query: str) -> str:
    # Sonuç etiketi RichText: dosya adındaki <, & HTML olarak yorumlanmasın.
    idx = name.lower().find(query.lower()) if query else -1
    if idx < 0:
        return html.escape(name)
    before, match, after = (
        html.escape(name[:idx]),
        html.escape(name[idx : idx + len(query)]),
        html.escape(name[idx + len(query) :]),
    )
    return (
        f'{before}<span style="background:rgba(69,184,106,0.15);color:#f2f4f7;'
        f'border-radius:2px;padding:0 1px;">'
        f"{match}</span>{after}"
    )


def _matches_file_type(path: Path, file_type: str | None) -> bool:
    if not file_type or file_type == "all":
        return True
    ext = path.suffix.lower()
    if file_type == "code":
        return ext in CODE_EXTENSIONS
    if file_type == "images":
        return ext in IMAGE_EXTENSIONS
    if file_type == "docs":
        return ext in DOCS_EXTENSIONS
    return True


def _should_skip_dir(name: str) -> bool:
    return should_skip_dir(name)


def count_files(roots: list[Path] | Path | None = None) -> int:
    if roots is None:
        from utils.settings import get_search_roots
        root_list = get_search_roots()
    elif isinstance(roots, Path):
        root_list = [roots]
    else:
        root_list = list(roots)

    total = 0
    seen_dirs: set[Path] = set()
    for root_path in root_list:
        if not root_path.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(root_path):
            real = Path(dirpath).resolve()
            if real in seen_dirs:
                dirnames.clear()
                continue
            seen_dirs.add(real)
            dirnames[:] = [d for d in dirnames if not _should_skip_dir(d)]
            total += len(filenames)
            if total > 500_000:
                return total
    return total


def _read_content_snippet(path: Path, needle: str) -> str | None:
    if path.suffix.lower() in BINARY_SKIP_EXTENSIONS:
        return None
    if path.suffix.lower() not in TEXT_EXTENSIONS and path.suffix.lower() not in IMAGE_EXTENSIONS:
        if path.suffix:
            return None
    try:
        size = path.stat().st_size
        if size > CONTENT_SEARCH_MAX_BYTES:
            return None
        text = path.read_text(encoding="utf-8", errors="ignore")[:SNIPPET_MAX_BYTES]
    except OSError:
        return None
    lower = text.lower()
    pos = lower.find(needle.lower())
    if pos < 0:
        return None
    start = max(0, pos - 24)
    excerpt = text[start : start + 90].replace("\n", " ").replace("\r", " ")
    if start > 0:
        excerpt = "…" + excerpt
    if start + 90 < len(text):
        excerpt += "…"
    return excerpt


def _score_match(name_hit: bool, content_hit: bool, kind: str) -> int:
    if name_hit and kind == "name":
        return 100
    if name_hit:
        return 90
    if content_hit:
        return 50
    return 0


def _search_root(
    root_path: Path,
    parsed: ParsedQuery,
    needle: str,
    *,
    search_content: bool,
    limit: int,
    seen_paths: set[str],
    matches: list[SearchResult],
) -> None:
    ext_suffix = f".{parsed.extension}" if parsed.extension else None

    for dirpath, dirnames, filenames in os.walk(root_path):
        if len(matches) >= limit:
            return
        dirnames[:] = [d for d in dirnames if not _should_skip_dir(d)]
        for name in filenames:
            if len(matches) >= limit:
                return
            path = Path(dirpath) / name
            key = str(path.resolve())
            if key in seen_paths:
                continue
            if should_skip_file(path):
                continue
            if not _matches_file_type(path, parsed.file_type):
                continue

            if ext_suffix and not name.lower().endswith(ext_suffix):
                continue
            if parsed.code_only and path.suffix.lower() not in CODE_EXTENSIONS:
                continue

            name_hit = bool(needle and needle in name.lower())
            content_hit = False
            snippet = None
            kind = "name"

            if parsed.content_only and needle:
                snippet = _read_content_snippet(path, needle)
                if not snippet:
                    continue
                content_hit = True
                kind = "content"
            elif needle:
                if name_hit:
                    kind = "name"
                elif search_content:
                    snippet = _read_content_snippet(path, needle)
                    if snippet:
                        content_hit = True
                        kind = "content"
                    else:
                        continue
                else:
                    continue
            elif parsed.extension:
                kind = "name"
            else:
                continue

            seen_paths.add(key)
            matches.append(
                SearchResult(
                    path=path,
                    name=name,
                    snippet=snippet,
                    match_kind=kind,
                    score=_score_match(name_hit, content_hit, kind),
                )
            )


def _merge_results(
    primary: list[SearchResult],
    secondary: list[SearchResult],
    limit: int,
) -> list[SearchResult]:
    seen = {str(r.path.resolve()) for r in primary}
    merged = list(primary)
    for item in secondary:
        key = str(item.path.resolve())
        if key in seen:
            continue
        merged.append(item)
        seen.add(key)
        if len(merged) >= limit:
            break
    merged.sort(key=lambda r: (-r.score, r.name.lower()))
    return merged[:limit]


def _search_via_fuzzy(
    parsed: ParsedQuery,
    *,
    search_content: bool,
    limit: int,
) -> list[SearchResult]:
    from utils.fuzzy_search import fuzzy_search_index
    from utils.settings import fuzzy_search_enabled

    if not fuzzy_search_enabled() or parsed.content_only or not parsed.text.strip():
        return []

    hits = fuzzy_search_index(parsed.text, limit=limit)
    if not hits:
        return []

    needle = parsed.text.lower()
    matches: list[SearchResult] = []
    for name, path_str, fscore in hits:
        path = Path(path_str)
        if not path.exists():
            continue
        if parsed.code_only and path.suffix.lower() not in CODE_EXTENSIONS:
            continue
        if not _matches_file_type(path, parsed.file_type):
            continue
        if parsed.extension and not name.lower().endswith(f".{parsed.extension}"):
            continue

        snippet = None
        kind = "fuzzy"
        if search_content and needle not in name.lower():
            snippet = _read_content_snippet(path, needle)

        matches.append(
            SearchResult(
                path=path,
                name=name,
                snippet=snippet,
                match_kind=kind,
                score=min(88, 35 + fscore // 2),
            )
        )
    matches.sort(key=lambda r: (-r.score, r.name.lower()))
    return matches[:limit]


def _search_via_everything(
    parsed: ParsedQuery,
    roots: list[Path],
    *,
    search_content: bool,
    limit: int,
) -> list[SearchResult]:
    import sys

    from utils.settings import everything_bridge_enabled, everything_filter_to_roots

    if sys.platform != "win32" or not everything_bridge_enabled():
        return []
    if parsed.content_only or not parsed.text.strip():
        return []

    from utils.everything_bridge import search_everything

    paths = search_everything(
        parsed.text,
        roots=roots,
        filter_to_roots=everything_filter_to_roots(),
        max_results=limit,
    )
    matches: list[SearchResult] = []
    needle = parsed.text.lower()
    for path in paths:
        if parsed.code_only and path.suffix.lower() not in CODE_EXTENSIONS:
            continue
        if not _matches_file_type(path, parsed.file_type):
            continue
        if parsed.extension and not path.name.lower().endswith(f".{parsed.extension}"):
            continue
        name_hit = needle in path.name.lower()
        snippet = None
        if search_content and not name_hit:
            snippet = _read_content_snippet(path, needle)
        matches.append(
            SearchResult(
                path=path,
                name=path.name,
                snippet=snippet,
                match_kind="everything",
                score=96 if name_hit else 85,
            )
        )
    matches.sort(key=lambda r: (-r.score, r.name.lower()))
    return matches[:limit]


def _search_via_fts(
    parsed: ParsedQuery,
    needle: str,
    *,
    search_content: bool,
    limit: int,
) -> list[SearchResult] | None:
    from utils.index_backend import index_ready, search_index

    if not index_ready():
        return None
    if parsed.content_only:
        return None

    hits = search_index(
        parsed.text,
        extension=parsed.extension,
        limit=limit * 2,
    )
    if not hits and (parsed.text or parsed.extension):
        return None

    matches: list[SearchResult] = []
    for name, path_str in hits:
        path = Path(path_str)
        if not path.exists():
            continue
        if parsed.code_only and path.suffix.lower() not in CODE_EXTENSIONS:
            continue
        if not _matches_file_type(path, parsed.file_type):
            continue

        name_hit = bool(needle and needle in name.lower())
        content_hit = False
        snippet = None
        kind = "name"

        if needle and search_content and not name_hit:
            snippet = _read_content_snippet(path, needle)
            if snippet:
                content_hit = True
                kind = "content"
            elif parsed.text and not parsed.extension:
                continue
        elif not needle and parsed.extension:
            kind = "name"
        elif not needle:
            continue

        matches.append(
            SearchResult(
                path=path,
                name=name,
                snippet=snippet,
                match_kind=kind,
                score=_score_match(name_hit, content_hit, kind),
            )
        )
        if len(matches) >= limit:
            break

    matches.sort(key=lambda r: (-r.score, r.name.lower()))
    return matches[:limit]


def filter_results_by_type(
    results: list[SearchResult], file_type: str | None
) -> list[SearchResult]:
    if not file_type or file_type == "all":
        return results
    return [r for r in results if _matches_file_type(r.path, file_type)]


def search_files(
    roots: list[Path] | Path | str,
    raw_query: str,
    *,
    search_content: bool = True,
    file_type: str | None = None,
    limit: int = MAX_RESULTS,
) -> tuple[list[SearchResult], int]:
    if isinstance(roots, (str, Path)):
        root_list = [Path(roots).expanduser()]
    else:
        root_list = [Path(r).expanduser() for r in roots]

    root_list = [r for r in root_list if r.exists()]
    if not root_list:
        raise FileNotFoundError("Arama klasörü tanımlı değil. Ayarlardan klasör ekleyin.")

    parsed = parse_query(raw_query)
    if file_type and file_type != "all":
        parsed.file_type = file_type
    needle = parsed.text.lower()
    if not needle and not parsed.extension:
        return [], 0

    # Katmanlı arama: Everything (ops.) → indeks (Tantivy/FTS5) → bulanık (rapidfuzz).
    # Sonuçlar skora göre birleştirilir; hiçbir katman sonuç vermezse diskte
    # os.walk ile yavaş tarama (_search_root) yedek olarak çalışır.
    t0 = time.perf_counter()
    everything_matches = _search_via_everything(
        parsed, root_list, search_content=search_content, limit=limit
    )
    fts_matches = _search_via_fts(
        parsed, needle, search_content=search_content, limit=limit
    )
    fuzzy_matches = _search_via_fuzzy(
        parsed, search_content=search_content, limit=limit
    )

    layers: list[SearchResult] = []
    if everything_matches:
        layers = _merge_results(layers, everything_matches, limit)
    if fts_matches is not None:
        layers = _merge_results(layers, fts_matches, limit)
    if fuzzy_matches:
        layers = _merge_results(layers, fuzzy_matches, limit)

    if layers:
        elapsed = int((time.perf_counter() - t0) * 1000)
        return layers, elapsed

    matches: list[SearchResult] = []
    seen: set[str] = set()

    for root in root_list:
        _search_root(
            root.resolve(),
            parsed,
            needle,
            search_content=search_content,
            limit=limit,
            seen_paths=seen,
            matches=matches,
        )
        if len(matches) >= limit:
            break

    matches.sort(key=lambda r: (-r.score, r.name.lower()))
    elapsed = int((time.perf_counter() - t0) * 1000)
    return matches[:limit], elapsed
