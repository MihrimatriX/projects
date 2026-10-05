"""Bulanık dosya adı araması — rapidfuzz (Faz 2)."""

from __future__ import annotations

from pathlib import Path

from rapidfuzz import fuzz, process

from utils.config import FUZZY_CANDIDATE_LIMIT, FUZZY_MIN_SCORE
from utils.index_backend import index_ready, list_index_candidates


def fuzzy_search_index(
    query: str,
    *,
    limit: int = 50,
    min_score: int = FUZZY_MIN_SCORE,
) -> list[tuple[str, str, int]]:
    """(name, path, score 0–100) — indeks üzerinde WRatio skoru."""
    needle = query.strip()
    if len(needle) < 2 or not index_ready():
        return []

    candidates = list_index_candidates(needle, max_rows=FUZZY_CANDIDATE_LIMIT)
    if not candidates:
        return []

    labels = [name for name, _ in candidates]
    extracted = process.extract(
        needle,
        labels,
        scorer=fuzz.WRatio,
        limit=limit,
        score_cutoff=min_score,
    )

    results: list[tuple[str, str, int]] = []
    seen_paths: set[str] = set()
    for _label, score, idx in extracted:
        name, path_str = candidates[idx]
        if path_str in seen_paths:
            continue
        seen_paths.add(path_str)
        if not Path(path_str).exists():
            continue
        results.append((name, path_str, int(score)))
    return results
