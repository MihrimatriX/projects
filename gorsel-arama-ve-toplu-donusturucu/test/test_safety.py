"""Veri kaybı, ad çakışması, EXIF yönü, şeffaflık ve metadata davranışı."""
from __future__ import annotations

from pathlib import Path

import pytest
from PIL import Image, ImageCms, features

from utils.convert_options import ConvertOptions
from utils.image_convert import convert_batch, convert_one

GPS_IFD = 0x8825
ORIENTATION = 0x0112


def _jpeg_with_exif(path: Path, size=(40, 20), orientation=6) -> None:
    img = Image.new("RGB", size, (200, 10, 10))
    exif = Image.Exif()
    exif[ORIENTATION] = orientation
    exif[0x010F] = "TestCam"
    exif.get_ifd(GPS_IFD)[2] = (41.0, 1.0, 0.0)  # GPSLatitude
    img.save(path, exif=exif.tobytes(), quality=95)


def test_name_collision_never_overwrites(tmp_path: Path) -> None:
    src = tmp_path / "src"
    src.mkdir()
    Image.new("RGB", (8, 8), "red").save(src / "a.png")
    Image.new("RGB", (8, 8), "blue").save(src / "a.jpg")
    out = tmp_path / "out"
    opts = ConvertOptions(fmt="webp", max_width=0)
    done, errors = convert_batch([str(src / "a.png"), str(src / "a.jpg")], str(out), opts)
    assert not errors
    assert [Path(p).name for p in done] == ["a.webp", "a (1).webp"]
    first = (out / "a.webp").read_bytes()
    done2, _ = convert_batch([str(src / "a.png")], str(out), opts)
    assert Path(done2[0]).name == "a (2).webp"
    assert (out / "a.webp").read_bytes() == first


def test_original_untouched_when_output_is_source_folder(tmp_path: Path) -> None:
    src = tmp_path / "foto.jpg"
    _jpeg_with_exif(src)
    before = src.read_bytes()
    dest = convert_one(str(src), str(tmp_path), ConvertOptions(fmt="jpeg", max_width=10))
    assert Path(dest).name == "foto (1).jpg"
    assert src.read_bytes() == before


def test_overwrite_is_explicit_and_batch_outputs_still_unique(tmp_path: Path) -> None:
    src = tmp_path / "src"
    src.mkdir()
    Image.new("RGB", (8, 8), "red").save(src / "a.png")
    Image.new("RGB", (8, 8), "blue").save(src / "a.bmp")
    out = tmp_path / "out"
    out.mkdir()
    (out / "a.webp").write_bytes(b"eski")
    opts = ConvertOptions(fmt="webp", max_width=0, overwrite=True)
    done, errors = convert_batch([str(src / "a.png"), str(src / "a.bmp")], str(out), opts)
    assert not errors
    assert [Path(p).name for p in done] == ["a.webp", "a (1).webp"]
    with Image.open(out / "a.webp") as img:
        assert img.convert("RGB").getpixel((0, 0))[0] > 200  # eski dosya kırmızı görselle değişti


def test_overwrite_original_in_place_when_chosen(tmp_path: Path) -> None:
    src = tmp_path / "foto.jpg"
    _jpeg_with_exif(src, size=(400, 200))
    dest = convert_one(str(src), str(tmp_path), ConvertOptions(fmt="jpeg", max_width=100, overwrite=True))
    assert Path(dest) == src
    with Image.open(src) as img:
        assert img.size == (100, 200)  # önce döndürüldü (200x400), sonra genişlik 100'e indi
    assert [p.name for p in tmp_path.iterdir()] == ["foto.jpg"]  # geçici dosya kalmadı


def test_failed_conversion_leaves_no_partial_file(tmp_path: Path) -> None:
    bad = tmp_path / "bozuk.png"
    bad.write_bytes(b"not an image")
    out = tmp_path / "out"
    done, errors = convert_batch([str(bad)], str(out), ConvertOptions(fmt="jpeg"))
    assert not done and len(errors) == 1
    assert list(out.iterdir()) == []


def test_exif_orientation_applied_and_tag_dropped(tmp_path: Path) -> None:
    src = tmp_path / "yan.jpg"
    _jpeg_with_exif(src, orientation=6)
    dest = convert_one(str(src), str(tmp_path / "o"), ConvertOptions(fmt="png", max_width=0))
    with Image.open(dest) as img:
        assert img.size == (20, 40)
        exif = img.getexif()
        assert ORIENTATION not in exif and exif.get(0x010F) == "TestCam"


def test_exif_orientation_kept_when_not_rotating(tmp_path: Path) -> None:
    src = tmp_path / "yan.jpg"
    _jpeg_with_exif(src, orientation=6)
    opts = ConvertOptions(fmt="webp", max_width=0, exif_rotate=False)
    with Image.open(convert_one(str(src), str(tmp_path / "o"), opts)) as img:
        assert img.size == (40, 20)
        assert img.getexif()[ORIENTATION] == 6  # görüntüleyici yine doğru döndürür


@pytest.mark.parametrize("fmt", ["jpeg", "webp", "png"])
def test_strip_metadata_removes_exif_and_gps(tmp_path: Path, fmt: str) -> None:
    src = tmp_path / "gps.jpg"
    _jpeg_with_exif(src, orientation=1)
    kept = convert_one(str(src), str(tmp_path / "k"), ConvertOptions(fmt=fmt, max_width=0))
    with Image.open(kept) as img:
        assert img.getexif().get_ifd(GPS_IFD)  # kapalıyken korunur
    clean = convert_one(str(src), str(tmp_path / "c"), ConvertOptions(fmt=fmt, max_width=0, strip_metadata=True))
    with Image.open(clean) as img:
        assert len(img.getexif()) == 0
        assert "exif" not in img.info
    assert b"TestCam" not in Path(clean).read_bytes()


def test_icc_profile_preserved(tmp_path: Path) -> None:
    icc = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
    src = tmp_path / "icc.png"
    Image.new("RGB", (8, 8), "red").save(src, icc_profile=icc)
    for fmt in ("jpeg", "webp"):
        dest = convert_one(str(src), str(tmp_path / fmt), ConvertOptions(fmt=fmt, strip_metadata=True))
        with Image.open(dest) as img:
            assert img.info.get("icc_profile") == icc
    gray = convert_one(str(src), str(tmp_path / "g"), ConvertOptions(fmt="jpeg", grayscale=True))
    with Image.open(gray) as img:
        assert img.mode == "L" and not img.info.get("icc_profile")  # RGB profili gri görsele yazılmaz


def _transparent_rgba() -> Image.Image:
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    img.paste((255, 0, 0, 255), (0, 0, 5, 10))
    return img


@pytest.mark.parametrize("mode", ["RGBA", "P", "LA"])
def test_transparency_flattened_on_white_for_jpeg(tmp_path: Path, mode: str) -> None:
    src = tmp_path / f"t_{mode}.png"
    img = _transparent_rgba()
    if mode == "P":
        pal = img.convert("RGB").quantize(colors=4)
        pal.save(src, transparency=pal.getpixel((9, 9)))
    else:
        img.convert(mode).save(src)
    dest = convert_one(str(src), str(tmp_path / "o"), ConvertOptions(fmt="jpeg", max_width=0, quality=95))
    with Image.open(dest) as out:
        right = out.convert("RGB").getpixel((8, 5))
        assert min(right) > 240, right  # şeffaf alan beyaz, siyah değil


def test_transparency_kept_for_png_and_webp(tmp_path: Path) -> None:
    src = tmp_path / "t.png"
    _transparent_rgba().save(src)
    for fmt in ("png", "webp"):
        dest = convert_one(str(src), str(tmp_path / fmt), ConvertOptions(fmt=fmt, max_width=0, webp_lossless=True))
        with Image.open(dest) as out:
            assert out.convert("RGBA").getpixel((8, 5))[3] == 0


def test_palette_resize_and_grayscale_alpha(tmp_path: Path) -> None:
    src = tmp_path / "p.png"
    _transparent_rgba().resize((100, 100)).save(src)
    dest = convert_one(str(src), str(tmp_path / "o"), ConvertOptions(fmt="png", max_width=50, grayscale=True))
    with Image.open(dest) as out:
        assert out.size == (50, 50) and out.mode == "LA"
        assert out.getpixel((45, 25))[1] == 0


def test_cmyk_and_16bit_inputs(tmp_path: Path) -> None:
    cmyk = tmp_path / "c.jpg"
    Image.new("CMYK", (8, 8), (0, 255, 255, 0)).save(cmyk)
    deep = tmp_path / "d.png"
    Image.new("I;16", (8, 8), 32768).save(deep)
    for fmt in ("png", "webp", "jpeg"):
        convert_one(str(cmyk), str(tmp_path / fmt), ConvertOptions(fmt=fmt))
    dest = convert_one(str(deep), str(tmp_path / "j"), ConvertOptions(fmt="jpeg"))
    with Image.open(dest) as out:
        assert 110 < out.getpixel((0, 0)) < 145  # beyaza kırpılmadı, 8 bite ölçeklendi


@pytest.mark.skipif(not features.check("avif"), reason="Pillow AVIF desteği yok")
def test_avif_output(tmp_path: Path) -> None:
    src = tmp_path / "a.png"
    _transparent_rgba().save(src)
    dest = convert_one(str(src), str(tmp_path / "o"), ConvertOptions(fmt="avif"))
    assert Path(dest).suffix == ".avif"
