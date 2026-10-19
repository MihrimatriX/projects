"""Dönüştürme pipeline smoke test."""
from __future__ import annotations

import tempfile
from pathlib import Path

from PIL import Image

from utils.convert_options import ConvertOptions
from utils.image_convert import collect_images, convert_batch, convert_one, fit_dimensions, format_meta, is_image


def test_convert_png_to_webp() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "src"
        out = Path(tmp) / "out"
        src.mkdir()
        img_path = src / "test.png"
        Image.new("RGB", (100, 50), color=(255, 0, 0)).save(img_path)

        assert is_image(img_path)
        opts = ConvertOptions(fmt="webp", max_width=80, quality=90)
        meta = format_meta(img_path, opts)
        assert "100×50" in meta and "80×40" in meta

        converted, errors = convert_batch([str(img_path)], str(out), opts)
        assert not errors and len(converted) == 1
        assert Path(converted[0]).suffix == ".webp"


def test_strip_metadata_and_grayscale() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        src = Path(tmp) / "a.jpg"
        out = Path(tmp) / "out"
        Image.new("RGB", (32, 32), (0, 128, 255)).save(src, quality=95)
        opts = ConvertOptions(fmt="jpeg", quality=80, strip_metadata=True, grayscale=True)
        dest = convert_one(str(src), str(out), opts)
        with Image.open(dest) as img:
            assert img.mode == "L"  # gri ton JPEG tek kanal yazılır
            assert "exif" not in img.info


def test_fit_dimensions() -> None:
    assert fit_dimensions(2000, 1500, 1920, 1080) == (1440, 1080)
    assert collect_images([]) == []
