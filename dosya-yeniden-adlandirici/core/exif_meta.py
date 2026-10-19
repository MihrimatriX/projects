from __future__ import annotations

from datetime import datetime
from pathlib import Path

from core.models import ExifNamingMode


def pillow_available() -> bool:
    try:
        import PIL  # noqa: F401

        return True
    except ImportError:
        return False


def get_capture_datetime(path: Path) -> datetime | None:
    if not pillow_available():
        return None
    try:
        from PIL import Image
        from PIL.ExifTags import TAGS
    except ImportError:
        return None

    try:
        with Image.open(path) as img:
            exif = img.getexif()
            if not exif:
                return None
            tag_map = {TAGS.get(k, str(k)): v for k, v in exif.items()}
            for key in ("DateTimeOriginal", "DateTimeDigitized", "DateTime"):
                raw = tag_map.get(key)
                if raw:
                    parsed = _parse_exif_datetime(str(raw))
                    if parsed:
                        return parsed
    except OSError:
        return None
    return None


def get_mtime_datetime(path: Path) -> datetime | None:
    try:
        return datetime.fromtimestamp(path.stat().st_mtime)
    except OSError:
        return None


def _parse_exif_datetime(value: str) -> datetime | None:
    for fmt in ("%Y:%m:%d %H:%M:%S", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(value.strip(), fmt)
        except ValueError:
            continue
    return None


def _with_extension(stem: str, current_name: str, *, keep_ext: bool) -> str:
    if not keep_ext:
        return stem
    suffix = Path(current_name).suffix
    return f"{stem}{suffix}" if suffix else stem


def format_exif_name(
    path: Path,
    exif_format: str,
    current_name: str,
    *,
    keep_ext: bool,
    use_mtime_fallback: bool,
    naming_mode: ExifNamingMode = ExifNamingMode.EXIF_OR_MTIME,
    mtime_format: str = "%Y%m%d",
    separator: str = "_",
) -> str:
    exif_dt = get_capture_datetime(path)
    mtime_dt = get_mtime_datetime(path)

    if naming_mode == ExifNamingMode.MTIME_ONLY:
        if mtime_dt is None:
            raise ValueError("Dosya tarihi (mtime) okunamadı")
        stem = mtime_dt.strftime(exif_format or "%Y%m%d_%H%M%S")
        return _with_extension(stem, current_name, keep_ext=keep_ext)

    if naming_mode == ExifNamingMode.EXIF_ONLY:
        if exif_dt is None:
            raise ValueError("EXIF tarihi okunamadı (Pillow gerekli olabilir)")
        stem = exif_dt.strftime(exif_format or "%Y%m%d_%H%M%S")
        return _with_extension(stem, current_name, keep_ext=keep_ext)

    if naming_mode == ExifNamingMode.EXIF_AND_MTIME:
        if mtime_dt is None:
            raise ValueError("Dosya tarihi (mtime) okunamadı")
        if exif_dt is None:
            if use_mtime_fallback:
                exif_dt = mtime_dt
            else:
                raise ValueError("EXIF tarihi yok; birleşik ad için mtime yedeğini açın")
        sep = separator or "_"
        stem = (
            exif_dt.strftime(exif_format or "%Y%m%d_%H%M%S")
            + sep
            + mtime_dt.strftime(mtime_format or "%Y%m%d")
        )
        return _with_extension(stem, current_name, keep_ext=keep_ext)

    # EXIF_OR_MTIME — EXIF öncelikli, yoksa mtime
    dt = exif_dt
    if dt is None and use_mtime_fallback:
        dt = mtime_dt
    if dt is None:
        if not pillow_available() and not use_mtime_fallback:
            raise ValueError("EXIF için Pillow gerekli veya mtime yedeğini açın")
        raise ValueError("Tarih okunamadı (EXIF yok; mtime yedeği kapalı olabilir)")
    stem = dt.strftime(exif_format or "%Y%m%d_%H%M%S")
    return _with_extension(stem, current_name, keep_ext=keep_ext)


def exif_rules_need_pillow(rules: list, *, default_mtime_fallback: bool) -> bool:
    from core.models import RuleType

    if pillow_available():
        return False
    for rule in rules:
        if not rule.enabled or rule.rule_type != RuleType.EXIF_DATE:
            continue
        mode = rule.exif_naming_mode
        if mode in (ExifNamingMode.MTIME_ONLY, ExifNamingMode.EXIF_OR_MTIME):
            if mode == ExifNamingMode.EXIF_OR_MTIME and (
                rule.exif_use_mtime_fallback or default_mtime_fallback
            ):
                continue
        if mode == ExifNamingMode.EXIF_AND_MTIME and (
            rule.exif_use_mtime_fallback or default_mtime_fallback
        ):
            continue
        return True
    return False
