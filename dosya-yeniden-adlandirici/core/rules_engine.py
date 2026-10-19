from __future__ import annotations

import os
import re
from collections.abc import Callable
from pathlib import Path

from core.exif_meta import exif_rules_need_pillow, format_exif_name
from core.models import CaseMode, PreviewRow, PreviewStatus, Rule, RuleType, path_key

INVALID_NAME_CHARS = set('<>:"/\\|?*')

WINDOWS_RESERVED = {
    "CON",
    "PRN",
    "AUX",
    "NUL",
    *(f"COM{i}" for i in range(1, 10)),
    *(f"LPT{i}" for i in range(1, 10)),
}


def validate_regex(pattern: str) -> str | None:
    if not pattern:
        return "Regex deseni boş olamaz."
    try:
        re.compile(pattern)
    except re.error as exc:
        return f"Geçersiz regex: {exc}"
    return None


def rule_matches_file(rule: Rule, path: Path) -> bool:
    raw = rule.condition_ext.strip()
    if not raw:
        return True
    ext = path.suffix.lstrip(".").lower()
    allowed = {e.strip().lower().lstrip(".") for e in raw.split(",") if e.strip()}
    return ext in allowed


def apply_find_replace(name: str, rule: Rule) -> str:
    if rule.use_regex:
        err = validate_regex(rule.pattern)
        if err:
            raise ValueError(err)
        flags = re.IGNORECASE if rule.ignore_case else 0
        return re.sub(rule.pattern, rule.replacement, name, flags=flags)

    if rule.ignore_case:
        # Tüm eşleşmeler değişmeli (str.replace gibi); yalnızca ilki değil.
        # lambda: değiştirme metnindeki "\" regex kaçışı olarak yorumlanmasın.
        return re.sub(
            re.escape(rule.pattern), lambda _m: rule.replacement, name, flags=re.IGNORECASE
        )
    return name.replace(rule.pattern, rule.replacement)


def apply_case(name: str, rule: Rule) -> str:
    stem, dot, ext = _split_name(name)
    target = stem
    if rule.case_mode == CaseMode.LOWER:
        target = stem.lower()
    elif rule.case_mode == CaseMode.UPPER:
        target = stem.upper()
    elif rule.case_mode == CaseMode.TITLE:
        target = stem.title()
    elif rule.case_mode == CaseMode.CAPITALIZE:
        target = stem[:1].upper() + stem[1:].lower() if stem else stem
    return f"{target}{dot}{ext}" if dot else target


def apply_extension(name: str, rule: Rule) -> str:
    stem, dot, ext = _split_name(name)
    old = rule.old_ext.lstrip(".").lower()
    new = rule.new_ext.lstrip(".")
    if not old:
        return name
    if ext.lower() != old:
        return name
    return f"{stem}.{new}" if new else stem


def apply_numbering(name: str, index: int, rule: Rule) -> str:
    num = str(rule.start + index).zfill(max(1, rule.pad))
    sep = rule.separator
    if rule.number_position == "suffix":
        return f"{name}{sep}{num}"
    return f"{num}{sep}{name}"


def apply_rule_to_name(
    name: str,
    rule: Rule,
    *,
    index: int = 0,
    file_path: Path | None = None,
) -> str:
    if not rule.enabled:
        return name
    if file_path is not None and not rule_matches_file(rule, file_path):
        return name
    if rule.rule_type == RuleType.FIND_REPLACE:
        if not rule.pattern and not rule.use_regex:
            return name
        return apply_find_replace(name, rule)
    if rule.rule_type == RuleType.CASE:
        return apply_case(name, rule)
    if rule.rule_type == RuleType.EXTENSION:
        return apply_extension(name, rule)
    if rule.rule_type == RuleType.NUMBERING:
        return apply_numbering(name, index, rule)
    if rule.rule_type == RuleType.EXIF_DATE:
        if file_path is None:
            raise ValueError("EXIF kuralı dosya yolu gerektirir")
        return format_exif_name(
            file_path,
            rule.exif_format,
            name,
            keep_ext=rule.keep_original_ext,
            use_mtime_fallback=rule.exif_use_mtime_fallback,
            naming_mode=rule.exif_naming_mode,
            mtime_format=rule.mtime_format,
            separator=rule.exif_mtime_separator,
        )
    return name


def apply_rules_chain(
    name: str,
    rules: list[Rule],
    *,
    index: int = 0,
    file_path: Path | None = None,
) -> str:
    current = name
    for rule in rules:
        if rule.rule_type == RuleType.NUMBERING:
            current = apply_rule_to_name(current, rule, index=index, file_path=file_path)
        else:
            current = apply_rule_to_name(current, rule, file_path=file_path)
    return current


def _split_name(name: str) -> tuple[str, str, str]:
    path = Path(name)
    if path.suffix and path.name != path.suffix:
        return path.stem, ".", path.suffix[1:]
    return name, "", ""


def _reserved_name_issue(name: str) -> str | None:
    if not name.strip():
        return "Ad boş olamaz"
    bad = sorted({ch for ch in name if ch in INVALID_NAME_CHARS or ord(ch) < 32})
    if bad:
        # "/" veya ters bölü dosyayı başka klasöre taşır; diğerleri Windows'ta geçersiz.
        shown = " ".join(repr(ch)[1:-1] for ch in bad)
        return f"Geçersiz karakter: {shown}"
    stem = Path(name).stem.upper()
    if stem in WINDOWS_RESERVED:
        return f"Windows ayırt edilemez ad: {stem}"
    if name.endswith(" ") or name.endswith("."):
        return "Ad boşluk veya nokta ile bitemez."
    if len(name) > 240:
        return "Dosya adı çok uzun"
    return None


def compute_preview(
    files: list[Path],
    rules: list[Rule],
    *,
    exif_mtime_fallback_default: bool = True,
    should_cancel: Callable[[], bool] | None = None,
    on_progress: Callable[[int, int], None] | None = None,
) -> tuple[list[PreviewRow], str | None]:
    active = [r for r in rules if r.enabled]
    for rule in active:
        if rule.rule_type == RuleType.FIND_REPLACE and rule.use_regex and rule.pattern:
            err = validate_regex(rule.pattern)
            if err:
                return [], err
    if exif_rules_need_pillow(active, default_mtime_fallback=exif_mtime_fallback_default):
        return [], "EXIF kuralları için Pillow gerekli: pip install Pillow (veya mtime yedeğini açın)"

    # Her dosya ada göre sıralanır, kurallar sırayla zincirlenir (numaralandırma bu
    # sıradaki indeksi kullanır). Sonra Windows'a yasak adlar ve çakışmalar işaretlenir;
    # diske hiçbir şey yazılmaz.
    rows: list[PreviewRow] = []
    sorted_files = sorted(files, key=lambda p: p.name.lower())
    total = len(sorted_files)

    for idx, path in enumerate(sorted_files):
        if should_cancel and should_cancel():
            return rows, "Önizleme iptal edildi"
        if on_progress and (idx % 5 == 0 or idx == total - 1):
            on_progress(idx + 1, total)
        original = path.name
        try:
            new_name = apply_rules_chain(original, active, index=idx, file_path=path)
        except ValueError as exc:
            rows.append(
                PreviewRow(
                    path=path,
                    original_name=original,
                    new_name=original,
                    status=PreviewStatus.ERROR,
                    message=str(exc),
                )
            )
            continue

        reserved = _reserved_name_issue(new_name)
        if reserved:
            rows.append(
                PreviewRow(
                    path=path,
                    original_name=original,
                    new_name=new_name,
                    status=PreviewStatus.RESERVED,
                    message=reserved,
                )
            )
            continue

        if new_name == original:
            rows.append(
                PreviewRow(
                    path=path,
                    original_name=original,
                    new_name=new_name,
                    status=PreviewStatus.UNCHANGED,
                )
            )
        else:
            rows.append(
                PreviewRow(
                    path=path,
                    original_name=original,
                    new_name=new_name,
                    status=PreviewStatus.OK,
                )
            )

    _mark_conflicts(rows)
    return rows, None


def _mark_conflicts(rows: list[PreviewRow]) -> None:
    # Aynı klasörde aynı hedefe giden satırlar (özyinelemeli modda farklı klasörlerdeki
    # aynı adlar çakışma değildir). Windows'ta ad karşılaştırması harf duyarsız.
    targets: dict[str, list[PreviewRow]] = {}
    for row in rows:
        if row.status in (PreviewStatus.ERROR, PreviewStatus.RESERVED):
            continue
        targets.setdefault(path_key(row.path.parent / row.new_name), []).append(row)

    for group in targets.values():
        if len(group) > 1:
            for row in group:
                row.status = PreviewStatus.CONFLICT
                row.message = "Aynı hedef ada çakışma"

    # Hedef diskte varsa ancak gerçekten yerinden taşınacak (OK) bir kaynaksa sorun
    # değildir. Bir satır çakışmaya düşünce kaynağı yerinde kalır; zincirdeki diğer
    # satırlar da etkilenebileceği için sabitlenene kadar tekrarla.
    changed = True
    while changed:
        changed = False
        moving = {path_key(r.path) for r in rows if r.status == PreviewStatus.OK}
        for row in rows:
            if row.status != PreviewStatus.OK:
                continue
            dest = row.path.parent / row.new_name
            if path_key(dest) not in moving and os.path.lexists(dest):
                row.status = PreviewStatus.CONFLICT
                row.message = "Hedef dosya zaten var"
                changed = True


def preview_stats(rows: list[PreviewRow]) -> tuple[int, int, int, int]:
    valid = sum(1 for r in rows if r.status == PreviewStatus.OK)
    conflicts = sum(
        1
        for r in rows
        if r.status in (PreviewStatus.CONFLICT, PreviewStatus.RESERVED, PreviewStatus.ERROR)
    )
    unchanged = sum(1 for r in rows if r.status == PreviewStatus.UNCHANGED)
    return valid, conflicts, unchanged, len(rows)


def can_apply(rows: list[PreviewRow]) -> bool:
    if not any(r.status == PreviewStatus.OK for r in rows):
        return False
    for row in rows:
        if row.original_name == row.new_name:
            continue
        if row.status != PreviewStatus.OK:
            return False
    return True


def filter_rows(
    rows: list[PreviewRow],
    *,
    changed_only: bool = False,
    conflicts_only: bool = False,
    search_text: str = "",
) -> list[PreviewRow]:
    result = rows
    if conflicts_only:
        bad = {PreviewStatus.CONFLICT, PreviewStatus.ERROR, PreviewStatus.RESERVED}
        result = [r for r in result if r.status in bad]
    elif changed_only:
        result = [
            r
            for r in result
            if r.status != PreviewStatus.UNCHANGED or r.original_name != r.new_name
        ]
    query = search_text.strip().lower()
    if query:
        result = [
            r
            for r in result
            if query in r.original_name.lower() or query in r.new_name.lower()
        ]
    return result
