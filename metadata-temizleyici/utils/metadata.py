from __future__ import annotations

import os
import shutil
import threading
from pathlib import Path

from PIL import Image
from PIL.ExifTags import GPSTAGS, TAGS

from utils import exiftool_engine, local_strip
from utils.hash_check import pixel_hash
from utils.models import MetadataTag, StripResult
from utils.presets import PRESETS, StripMode, resolve_exiftool_args
from utils.tag_labels import risk_level, tag_label

IMAGE_EXTENSIONS = frozenset({".jpg", ".jpeg", ".png", ".webp", ".tiff", ".tif", ".bmp", ".heic", ".heif"})
DOCUMENT_EXTENSIONS = frozenset({".pdf"})
VIDEO_EXTENSIONS = frozenset({".mp4", ".mov", ".avi", ".mkv", ".m4v", ".webm", ".wmv", ".3gp"})
SUPPORTED_EXTENSIONS = IMAGE_EXTENSIONS | DOCUMENT_EXTENSIONS | VIDEO_EXTENSIONS
EXIFTOOL_REQUIRED_MESSAGE = (
    "Video metadata'sı için exiftool gerekli (scripts\\install-exiftool.ps1 ile kurulabilir)"
)

ORIENTATION_TAG = 0x0112
EXIF_IFD = 0x8769
GPS_IFD = 0x8825
INTEROP_IFD = 0xA005


def is_supported(path: str | Path) -> bool:
    suffix = Path(path).suffix.lower()
    if suffix in IMAGE_EXTENSIONS | DOCUMENT_EXTENSIONS:
        return True
    if suffix in VIDEO_EXTENSIONS:
        return exiftool_engine.is_available()
    return False


def count_needing_exiftool(paths: list[str | Path], *, recursive: bool = True) -> int:
    """exiftool yokken atlanan (video) dosya sayısı — kullanıcıya nedenini söylemek için."""
    if exiftool_engine.is_available():
        return 0
    count = 0
    for raw in paths:
        path = Path(raw)
        items = [path] if path.is_file() else (path.rglob("*") if recursive else path.glob("*"))
        count += sum(1 for p in items if p.suffix.lower() in VIDEO_EXTENSIONS and p.is_file())
    return count


def collect_files(paths: list[str | Path], *, recursive: bool = True) -> list[Path]:
    found: list[Path] = []
    seen: set[Path] = set()

    for raw in paths:
        path = Path(raw)
        if path.is_file() and is_supported(path):
            resolved = path.resolve()
            if resolved not in seen:
                seen.add(resolved)
                found.append(resolved)
            continue
        if not path.is_dir():
            continue
        iterator = path.rglob("*") if recursive else path.glob("*")
        for candidate in iterator:
            if candidate.is_file() and is_supported(candidate):
                resolved = candidate.resolve()
                if resolved not in seen:
                    seen.add(resolved)
                    found.append(resolved)
    return sorted(found)


def read_metadata_tags(path: str | Path) -> list[MetadataTag]:
    src = Path(path).resolve()
    if src.suffix.lower() in DOCUMENT_EXTENSIONS:
        return _read_tags_pdf(src)
    if src.suffix.lower() in VIDEO_EXTENSIONS and not exiftool_engine.is_available():
        raise RuntimeError(EXIFTOOL_REQUIRED_MESSAGE)
    if exiftool_engine.is_available():
        try:
            return exiftool_engine.read_tags(src)
        except RuntimeError:
            if src.suffix.lower() not in IMAGE_EXTENSIONS:
                raise
    return _read_tags_pillow(src)


def read_metadata_summary(path: str | Path) -> dict[str, str]:
    src = Path(path)
    tags = read_metadata_tags(src)
    high_risk = sum(1 for t in tags if t.risk == "high")
    summary = {
        "format": src.suffix.lstrip(".").upper(),
        "tag_count": str(len(tags)),
        "high_risk_count": str(high_risk),
        "engine": "exiftool" if exiftool_engine.is_available() and src.suffix.lower() not in DOCUMENT_EXTENSIONS
        else "yerel",
    }
    if src.suffix.lower() in IMAGE_EXTENSIONS:
        with Image.open(src) as img:
            summary["mode"] = img.mode
            summary["size"] = f"{img.width}x{img.height}"
    return summary


def _resolve_remove_name_set(
    mode: StripMode,
    preset_id: str | None,
    custom_tags: list[str] | None,
) -> set[str] | None:
    if mode == StripMode.ALL:
        return None
    if mode == StripMode.GPS_ONLY:
        return set(PRESETS["gps_only"].pillow_tag_names)
    if mode == StripMode.CAMERA_ONLY:
        return set(PRESETS["camera_only"].pillow_tag_names)
    if mode == StripMode.PRESET:
        preset = PRESETS.get(preset_id or "social_media", PRESETS["social_media"])
        return set(preset.pillow_tag_names)
    if mode in (StripMode.CUSTOM, StripMode.SELECTED):
        return {_short_name(t) for t in (custom_tags or [])}
    return None


def predict_removed_tag_names(
    before_tags: tuple[MetadataTag, ...],
    mode: StripMode,
    preset_id: str | None = None,
    custom_tags: list[str] | None = None,
) -> tuple[str, ...]:
    remove_names = _resolve_remove_name_set(mode, preset_id, custom_tags)
    if remove_names is None:
        return tuple(t.name for t in before_tags)

    gps_strip = any(name.startswith("GPS") for name in remove_names)
    removed: list[str] = []
    for tag in before_tags:
        short = _short_name(tag.name)
        if short in remove_names:
            removed.append(tag.name)
        elif gps_strip and (short.startswith("GPS") or "GPS" in tag.name):
            removed.append(tag.name)
    return tuple(removed)


def strip_metadata(
    src: str | Path,
    *,
    dest: str | Path | None = None,
    backup: bool = True,
    overwrite: bool = True,
    mode: StripMode = StripMode.ALL,
    preset_id: str | None = None,
    custom_tags: list[str] | None = None,
    dry_run: bool = False,
) -> StripResult:
    src_path = Path(src).resolve()
    if not src_path.is_file():
        raise FileNotFoundError(src_path)

    before_tags = tuple(read_metadata_tags(src_path))

    if dry_run:
        removed = predict_removed_tag_names(before_tags, mode, preset_id, custom_tags)
        remaining = tuple(t for t in before_tags if t.name not in set(removed))
        return StripResult(
            source=src_path,
            output=src_path,
            backup=None,
            tags_removed=len(removed),
            removed_tag_names=removed,
            overwritten=False,
            engine="simülasyon",
            hash_changed=False,
            dry_run=True,
            before_tags=before_tags,
            after_tags=remaining,
        )

    before_hash = pixel_hash(src_path)

    # Motor seçimi: exiftool varsa her tür dosya onunla yerinde temizlenir (-overwrite_original);
    # yoksa yalnızca görseller Pillow ile yeniden kaydedilerek temizlenir. Piksel hash'i
    # önce/sonra karşılaştırılarak yeniden kodlama (kalite kaybı) tespit edilir.
    # PDF her zaman yerel motorla: exiftool PDF'te eski metadata'yı dosyada bırakır.
    suffix = src_path.suffix.lower()
    use_exiftool = exiftool_engine.is_available() and suffix not in DOCUMENT_EXTENSIONS
    if use_exiftool:
        result = _strip_exiftool(
            src_path,
            backup=backup,
            mode=mode,
            preset_id=preset_id,
            custom_tags=custom_tags,
        )
    elif suffix in VIDEO_EXTENSIONS:
        raise RuntimeError(EXIFTOOL_REQUIRED_MESSAGE)
    else:
        result = _strip_pillow(
            src_path,
            dest=dest,
            backup=backup,
            overwrite=overwrite,
            mode=mode,
            preset_id=preset_id,
            custom_tags=custom_tags,
            before_tags=before_tags,
        )

    after_hash = pixel_hash(result.output)
    changed = bool(before_hash and after_hash and before_hash != after_hash)
    return StripResult(
        source=result.source,
        output=result.output,
        backup=result.backup,
        tags_removed=result.tags_removed,
        removed_tag_names=result.removed_tag_names,
        overwritten=result.overwritten,
        engine=result.engine,
        hash_changed=changed,
        before_tags=result.before_tags,
        after_tags=result.after_tags,
    )


def _strip_exiftool(
    src_path: Path,
    *,
    backup: bool,
    mode: StripMode,
    preset_id: str | None,
    custom_tags: list[str] | None,
) -> StripResult:
    args = resolve_exiftool_args(mode, preset_id=preset_id, custom_tags=custom_tags)
    before, after, backup_path = exiftool_engine.strip_tags(src_path, args, backup=backup)
    before_names = {t.name for t in before}
    after_names = {t.name for t in after}
    removed = tuple(t.name for t in before if t.name not in after_names)
    count = len(removed)
    return StripResult(
        source=src_path,
        output=src_path,
        backup=backup_path,
        tags_removed=count,
        removed_tag_names=removed,
        overwritten=True,
        engine="exiftool",
        before_tags=tuple(before),
        after_tags=tuple(after),
    )


def _unique_clean_path(src_path: Path) -> Path:
    candidate = src_path.with_stem(f"{src_path.stem}_clean")
    n = 1
    while candidate.exists():
        n += 1
        candidate = src_path.with_stem(f"{src_path.stem}_clean{n}")
    return candidate


def _filtered_exif(src_path: Path, remove_names: set[str] | None) -> bytes | None:
    """Korunacak EXIF'i üretir. ``None`` (tümünü sil) modunda yalnızca yön etiketi kalır;
    yoksa döndürülmüş fotoğraflar yan görünür. Kişisel veri içermez."""
    try:
        with Image.open(src_path) as img:
            exif = img.getexif()
    except Exception:
        return None
    out = Image.Exif()
    if remove_names is None:
        orientation = exif.get(ORIENTATION_TAG)
        if orientation and orientation != 1:
            out[ORIENTATION_TAG] = orientation
        return out.tobytes() if len(out) else None
    for tag_id, value in exif.items():
        if tag_id in (EXIF_IFD, GPS_IFD, INTEROP_IFD):
            continue
        if TAGS.get(tag_id, str(tag_id)) not in remove_names:
            out[tag_id] = value
    sub = {k: v for k, v in exif.get_ifd(EXIF_IFD).items()
           if k != INTEROP_IFD and TAGS.get(k, str(k)) not in remove_names}
    if sub:
        out[EXIF_IFD] = sub
    if not any(name.startswith("GPS") for name in remove_names):
        gps = exif.get_ifd(GPS_IFD)
        if gps:
            out[GPS_IFD] = dict(gps)
    return out.tobytes() if len(out) else None


def _write_clean(src_path: Path, dest: Path, remove_names: set[str] | None) -> None:
    """Temiz kopyayı önce geçici dosyaya yazar, sonra hedefe taşır: hata olursa
    orijinal (yedek kapalıyken tek kopya) bozulmaz."""
    tmp = dest.with_name(f".{dest.name}.{os.getpid()}.{threading.get_ident()}.tmp")
    suffix = src_path.suffix.lower()
    try:
        if suffix in DOCUMENT_EXTENSIONS:
            local_strip.strip_pdf(src_path, tmp)
        elif suffix in local_strip.LOSSLESS:
            data = local_strip.LOSSLESS[suffix](src_path.read_bytes(), _filtered_exif(src_path, remove_names))
            tmp.write_bytes(data)
        else:
            local_strip.resave_image(src_path, tmp, _filtered_exif(src_path, remove_names))
        os.replace(tmp, dest)
    finally:
        tmp.unlink(missing_ok=True)


def _strip_pillow(
    src_path: Path,
    *,
    dest: Path | None,
    backup: bool,
    overwrite: bool,
    mode: StripMode,
    preset_id: str | None,
    custom_tags: list[str] | None,
    before_tags: tuple[MetadataTag, ...],
) -> StripResult:
    if src_path.suffix.lower() in DOCUMENT_EXTENSIONS and mode != StripMode.ALL:
        raise RuntimeError("PDF için yalnızca 'tümünü temizle' modu desteklenir")
    remove_names = _resolve_remove_name_set(mode, preset_id, custom_tags)

    if not overwrite:
        out_path = _unique_clean_path(src_path)
    else:
        out_path = Path(dest).resolve() if dest else src_path
    backup_path: Path | None = None

    if backup and out_path == src_path:
        backup_path = src_path.with_suffix(src_path.suffix + ".bak")
        # Var olan yedek ilk (metadata'lı) orijinaldir; tekrar temizlemede ezilmez.
        if not backup_path.exists():
            shutil.copy2(src_path, backup_path)

    _write_clean(src_path, out_path, remove_names)
    after_tags = tuple(read_metadata_tags(out_path))
    after_names = {t.name for t in after_tags}
    removed = tuple(t.name for t in before_tags if t.name not in after_names)

    return StripResult(
        source=src_path,
        output=out_path,
        backup=backup_path,
        tags_removed=len(removed),
        removed_tag_names=removed,
        overwritten=out_path == src_path,
        engine="yerel",
        before_tags=before_tags,
        after_tags=after_tags,
    )


def _short_name(name: str) -> str:
    return name.split(":", 1)[-1] if ":" in name else name


def _format_exif_value(value: object) -> str:
    if isinstance(value, bytes):
        try:
            return value.decode("utf-8", errors="replace").strip() or "(binary)"
        except Exception:
            return "(binary)"
    if isinstance(value, tuple):
        return ", ".join(_format_exif_value(v) for v in value)
    return str(value)


def _read_gps_tags(exif: Image.Exif) -> list[MetadataTag]:
    tags: list[MetadataTag] = []
    try:
        gps_ifd = exif.get_ifd(0x8825)
    except (KeyError, TypeError):
        return tags

    for tag_id, value in gps_ifd.items():
        name = GPSTAGS.get(tag_id, f"GPS{tag_id}")
        tags.append(
            MetadataTag(
                name=name,
                label=tag_label(name),
                value=_format_exif_value(value),
                risk=risk_level(name),
            )
        )
    return tags


def _tag(name: str, value: object, risk: str | None = None, label: str | None = None) -> MetadataTag:
    short = _short_name(name)
    return MetadataTag(
        name=name,
        label=label or tag_label(short),
        value=_format_exif_value(value),
        risk=risk or risk_level(short),
    )


# Pillow info sözlüğündeki yapısal (metadata olmayan) anahtarlar: temizlikten sonra da kalır.
_STRUCTURAL_INFO = {
    "exif", "icc_profile", "jfif", "jfif_version", "jfif_unit", "jfif_density", "dpi", "adobe",
    "adobe_transform", "progressive", "progression", "transparency", "gamma", "chromaticity", "srgb",
    "compression", "aspect", "loop", "duration", "background", "timestamp", "lossless", "bitmap_format",
    "original_orientation", "primary", "bit_depth", "depth_images", "heif", "thumbnails", "resolution",
    "interlace", "default_image", "blend", "disposal", "mode", "aux", "chroma", "nclx_profile",
}


def _read_tags_pillow(path: Path) -> list[MetadataTag]:
    with Image.open(path) as img:
        exif = img.getexif()
        info = dict(img.info)

    tags: list[MetadataTag] = []
    for tag_id, value in exif.items():
        if tag_id in (EXIF_IFD, GPS_IFD, INTEROP_IFD):
            continue
        tags.append(_tag(TAGS.get(tag_id, str(tag_id)), value))
    for tag_id, value in exif.get_ifd(EXIF_IFD).items():
        if tag_id == INTEROP_IFD:
            continue
        tags.append(_tag(TAGS.get(tag_id, str(tag_id)), value))
    tags.extend(_read_gps_tags(exif))

    for key, value in info.items():
        low = str(key).lower()
        if low in _STRUCTURAL_INFO or not value:
            continue
        if low == "photoshop" or "iptc" in low:
            tags.append(_tag("IPTC", "(IPTC/Photoshop bloğu)", "high", "IPTC / Photoshop"))
        elif "xmp" in low:
            tags.append(_tag("XMP", "(XMP paketi)", "high", "XMP"))
        else:
            tags.append(_tag(f"Info:{key}", value, "low", str(key)))

    tags.sort(key=lambda t: (0 if t.risk == "high" else 1, t.name))
    return tags


def _read_tags_pdf(path: Path) -> list[MetadataTag]:
    tags = [
        _tag("XMP", v, "high", "XMP") if k == "XMP" else _tag(f"PDF:{k}", v)
        for k, v in local_strip.read_pdf_metadata(path).items()
    ]
    tags.sort(key=lambda t: (0 if t.risk == "high" else 1, t.name))
    return tags


# Geriye dönük import uyumu
__all__ = [
    "MetadataTag",
    "StripResult",
    "SUPPORTED_EXTENSIONS",
    "collect_files",
    "count_needing_exiftool",
    "is_supported",
    "read_metadata_tags",
    "read_metadata_summary",
    "strip_metadata",
]
