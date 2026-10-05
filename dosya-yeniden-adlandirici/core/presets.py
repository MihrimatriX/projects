from __future__ import annotations

from core.models import CaseMode, ExifNamingMode, Rule, RuleType

PRESETS: dict[str, list[Rule]] = {
    "Sıra numarası": [
        Rule(
            rule_type=RuleType.NUMBERING,
            number_position="prefix",
            start=1,
            pad=3,
            separator="_",
        ),
    ],
    "Fotoğraf tarihi (EXIF)": [
        Rule(
            rule_type=RuleType.EXIF_DATE,
            condition_ext="jpg,jpeg,tiff",
            exif_format="%Y%m%d_%H%M%S",
        ),
        Rule(
            rule_type=RuleType.NUMBERING,
            number_position="prefix",
            start=1,
            pad=3,
            separator="_",
        ),
    ],
    "Türkçe karakter düzelt": [
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="ı", replacement="i"),
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="ğ", replacement="g"),
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="ü", replacement="u"),
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="ş", replacement="s"),
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="ö", replacement="o"),
        Rule(rule_type=RuleType.FIND_REPLACE, pattern="ç", replacement="c"),
    ],
    "Boşluk → alt çizgi": [
        Rule(rule_type=RuleType.FIND_REPLACE, pattern=" ", replacement="_"),
    ],
    "Küçük harf": [
        Rule(rule_type=RuleType.CASE, case_mode=CaseMode.LOWER),
    ],
    "EXIF + mtime birleşik": [
        Rule(
            rule_type=RuleType.EXIF_DATE,
            condition_ext="jpg,jpeg,tiff",
            exif_naming_mode=ExifNamingMode.EXIF_AND_MTIME,
            exif_format="%Y%m%d_%H%M%S",
            mtime_format="%Y%m%d",
            exif_mtime_separator="_",
        ),
        Rule(
            rule_type=RuleType.NUMBERING,
            number_position="prefix",
            start=1,
            pad=3,
            separator="_",
        ),
    ],
    "JPG → EXIF (koşullu)": [
        Rule(
            rule_type=RuleType.EXIF_DATE,
            condition_ext="jpg,jpeg",
            exif_format="%Y-%m-%d_%H%M",
        ),
    ],
    "Fotoğraf (IMG regex)": [
        Rule(
            rule_type=RuleType.FIND_REPLACE,
            pattern=r"IMG_(\d+)",
            replacement=r"Foto_\1",
            use_regex=True,
        ),
        Rule(
            rule_type=RuleType.NUMBERING,
            number_position="prefix",
            start=1,
            pad=3,
            separator="_",
        ),
    ],
}
