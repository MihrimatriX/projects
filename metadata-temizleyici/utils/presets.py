from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class StripMode(str, Enum):
    ALL = "all"
    GPS_ONLY = "gps_only"
    CAMERA_ONLY = "camera_only"
    PRESET = "preset"
    CUSTOM = "custom"
    SELECTED = "selected"


@dataclass(frozen=True)
class StripPreset:
    id: str
    label: str
    exiftool_args: tuple[str, ...]
    pillow_tag_names: frozenset[str]


CAMERA_TAG_NAMES = frozenset(
    {
        "Make",
        "Model",
        "LensModel",
        "LensMake",
        "SerialNumber",
        "BodySerialNumber",
        "LensSerialNumber",
        "CameraSerialNumber",
        "InternalSerialNumber",
    }
)

# MakerNote: üreticiye özel blok; seri numaraları çoğunlukla buradadır.
CAMERA_PILLOW_TAGS = CAMERA_TAG_NAMES | {"MakerNote"}

GPS_EXIFTOOL_ARGS = ("-GPS:all=",)

GPS_PILLOW_TAGS = frozenset(
    {
        "GPSLatitude",
        "GPSLongitude",
        "GPSAltitude",
        "GPSPosition",
        "GPSDateStamp",
        "GPSTimeStamp",
        "GPSLatitudeRef",
        "GPSLongitudeRef",
        "GPSAltitudeRef",
    }
)

PRESETS: dict[str, StripPreset] = {
    "social_media": StripPreset(
        id="social_media",
        label="Sosyal medya paylaşım",
        exiftool_args=(
            "-GPS:all=",
            "-SerialNumber=",
            "-BodySerialNumber=",
            "-LensSerialNumber=",
            "-OwnerName=",
            "-Artist=",
            "-Copyright=",
            "-UserComment=",
            "-MakerNotes:all=",
        ),
        pillow_tag_names=frozenset(
            {
                *CAMERA_PILLOW_TAGS,
                *GPS_PILLOW_TAGS,
                "OwnerName",
                "Artist",
                "Copyright",
                "UserComment",
            }
        ),
    ),
    "gps_only": StripPreset(
        id="gps_only",
        label="Yalnızca GPS",
        exiftool_args=GPS_EXIFTOOL_ARGS,
        pillow_tag_names=GPS_PILLOW_TAGS,
    ),
    "camera_only": StripPreset(
        id="camera_only",
        label="Yalnızca kamera bilgisi",
        exiftool_args=(*(f"-{name}=" for name in sorted(CAMERA_TAG_NAMES)), "-MakerNotes:all="),
        pillow_tag_names=CAMERA_PILLOW_TAGS,
    ),
}


def preset_choices() -> list[tuple[str, str]]:
    return [(p.id, p.label) for p in PRESETS.values()]


def resolve_exiftool_args(
    mode: StripMode,
    *,
    preset_id: str | None = None,
    custom_tags: list[str] | None = None,
) -> list[str]:
    if mode == StripMode.ALL:
        return ["-all="]
    if mode == StripMode.GPS_ONLY:
        return list(GPS_EXIFTOOL_ARGS)
    if mode == StripMode.CAMERA_ONLY:
        return list(PRESETS["camera_only"].exiftool_args)
    if mode == StripMode.PRESET:
        preset = PRESETS.get(preset_id or "social_media")
        if not preset:
            raise ValueError(f"Bilinmeyen preset: {preset_id}")
        return list(preset.exiftool_args)
    if mode in (StripMode.CUSTOM, StripMode.SELECTED):
        tags = custom_tags or []
        args: list[str] = []
        for tag in tags:
            if tag.startswith("GPS:") or tag.split(":")[-1].startswith("GPS"):
                args.append("-GPS:all=")
                continue
            name = tag.split(":", 1)[-1] if ":" in tag else tag
            args.append(f"-{name}=")
        return list(dict.fromkeys(args))
    raise ValueError(f"Bilinmeyen mod: {mode}")
