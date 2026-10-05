"""Yerel motor: metadata gerçekten silindi mi? Çıktı dosyaları yeniden okunarak (Pillow, pypdf
ve ham bayt araması) doğrulanır. exiftool / ffmpeg kurulu değilken çalışır."""
from __future__ import annotations

import io
import struct
from pathlib import Path

import pytest
from PIL import Image, ImageCms
from pypdf import PdfReader, PdfWriter

from utils.hash_check import pixel_hash
from utils.metadata import (
    EXIFTOOL_REQUIRED_MESSAGE,
    collect_files,
    count_needing_exiftool,
    is_supported,
    read_metadata_tags,
    strip_metadata,
)
from utils.presets import StripMode
from utils.restore import restore_backup

GPS_IFD, EXIF_IFD = 0x8825, 0x8769
SECRETS = (b"GizliKamera", b"SER-123456", b"Ahmet Yazar", b"xmp-gizli", b"iptc-gizli", b"yorum-gizli")
XMP = b'<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF><rdf:Description>xmp-gizli</rdf:Description></rdf:RDF></x:xmpmeta>'
ICC = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()


def _exif(orientation: int = 1) -> Image.Exif:
    exif = Image.Exif()
    exif[0x010F] = "GizliKamera"  # Make
    exif[0x013B] = "Ahmet Yazar"  # Artist
    exif[0x0112] = orientation
    exif[EXIF_IFD] = {0xA431: "SER-123456", 0x9003: "2024:01:02 03:04:05"}  # BodySerialNumber, DateTimeOriginal
    exif[GPS_IFD] = {1: "N", 2: (41.0, 1.0, 30.0)}
    return exif


def _photo() -> Image.Image:
    img = Image.new("RGB", (64, 48))
    for x in range(64):
        for y in range(48):
            img.putpixel((x, y), (x * 4, y * 5, (x + y) * 2))
    return img


def _iptc_app13() -> bytes:
    record = b"\x1c\x02\x50" + struct.pack(">H", 10) + b"iptc-gizli"  # 2:80 By-line
    block = b"8BIM\x04\x04\x00\x00" + struct.pack(">I", len(record)) + record
    body = b"Photoshop 3.0\x00" + block
    return b"\xff\xed" + struct.pack(">H", len(body) + 2) + body


def _make_jpeg(path: Path, *, progressive: bool = False, orientation: int = 1) -> None:
    buf = io.BytesIO()
    _photo().save(buf, "JPEG", exif=_exif(orientation).tobytes(), xmp=XMP, icc_profile=ICC,
                  comment=b"yorum-gizli", progressive=progressive, quality=90)
    data = buf.getvalue()
    # SOI'den hemen sonra IPTC (APP13), dosya sonuna da EOI sonrası ek veri (ör. telefon trailer'ı)
    path.write_bytes(data[:2] + _iptc_app13() + data[2:] + b"TRAILER-GizliKamera")


def _assert_clean_bytes(path: Path) -> None:
    raw = path.read_bytes()
    for secret in SECRETS:
        assert secret not in raw, secret


@pytest.mark.parametrize("progressive", [False, True])
def test_jpeg_all_lossless_and_really_clean(tmp_path: Path, progressive: bool) -> None:
    src = tmp_path / "foto.jpg"
    _make_jpeg(src, progressive=progressive)
    before_tags = {t.name for t in read_metadata_tags(src)}
    assert {"Make", "BodySerialNumber", "GPSLatitude", "XMP", "IPTC"} <= before_tags
    before_pixels = pixel_hash(src)

    result = strip_metadata(src, backup=True, mode=StripMode.ALL)

    _assert_clean_bytes(src)
    assert read_metadata_tags(src) == []
    with Image.open(src) as img:
        assert img.info.get("icc_profile") == ICC  # renk profili korunur
        assert "exif" not in img.info and "xmp" not in img.info and "photoshop" not in img.info
    assert pixel_hash(src) == before_pixels and not result.hash_changed  # yeniden kodlama yok
    assert result.tags_removed >= 7 and result.backup and result.backup.is_file()
    assert b"GizliKamera" in result.backup.read_bytes()  # yedek dokunulmamış orijinal


def test_jpeg_all_keeps_only_orientation(tmp_path: Path) -> None:
    src = tmp_path / "dik.jpg"
    _make_jpeg(src, orientation=6)
    strip_metadata(src, backup=False, mode=StripMode.ALL)
    _assert_clean_bytes(src)
    with Image.open(src) as img:
        assert dict(img.getexif()) == {0x0112: 6}  # yön etiketi kalmazsa fotoğraf yan görünür


def test_jpeg_gps_only_keeps_other_exif(tmp_path: Path) -> None:
    src = tmp_path / "gps.jpg"
    _make_jpeg(src)
    strip_metadata(src, backup=False, mode=StripMode.GPS_ONLY)
    with Image.open(src) as img:
        exif = img.getexif()
        assert not exif.get_ifd(GPS_IFD)
        assert exif[0x010F] == "GizliKamera"
        assert exif.get_ifd(EXIF_IFD)[0x9003] == "2024:01:02 03:04:05"  # Exif alt IFD kaybolmaz


def test_jpeg_camera_only_removes_serial_in_exif_subifd(tmp_path: Path) -> None:
    src = tmp_path / "cam.jpg"
    _make_jpeg(src)
    strip_metadata(src, backup=False, mode=StripMode.CAMERA_ONLY)
    names = {t.name for t in read_metadata_tags(src)}
    assert "Make" not in names and "BodySerialNumber" not in names
    assert {"GPSLatitude", "DateTimeOriginal", "Artist"} <= names
    assert b"SER-123456" not in src.read_bytes()


def test_png_text_xmp_exif_removed_transparency_kept(tmp_path: Path) -> None:
    from PIL.PngImagePlugin import PngInfo

    src = tmp_path / "a.png"
    img = Image.new("RGBA", (10, 10), (255, 0, 0, 0))
    info = PngInfo()
    info.add_text("Author", "Ahmet Yazar")
    info.add_itxt("XML:com.adobe.xmp", XMP.decode())
    info.add_text("Comment", "yorum-gizli", zip=True)
    img.save(src, pnginfo=info, exif=_exif().tobytes(), icc_profile=ICC)
    before = pixel_hash(src)

    strip_metadata(src, backup=False, mode=StripMode.ALL)

    _assert_clean_bytes(src)
    assert read_metadata_tags(src) == []
    with Image.open(src) as out:
        assert out.mode == "RGBA" and out.getpixel((0, 0))[3] == 0
        assert out.info.get("icc_profile") == ICC
    assert pixel_hash(src) == before


def test_webp_exif_xmp_removed(tmp_path: Path) -> None:
    src = tmp_path / "a.webp"
    _photo().save(src, "WEBP", lossless=True, exif=_exif().tobytes(), xmp=XMP, icc_profile=ICC)
    before = pixel_hash(src)
    strip_metadata(src, backup=False, mode=StripMode.ALL)
    _assert_clean_bytes(src)
    with Image.open(src) as out:
        out.load()
        assert "exif" not in out.info and "xmp" not in out.info
        assert out.info.get("icc_profile") == ICC
    assert pixel_hash(src) == before
    assert read_metadata_tags(src) == []


def test_webp_gps_only_rewrites_exif_chunk(tmp_path: Path) -> None:
    src = tmp_path / "g.webp"
    _photo().save(src, "WEBP", lossless=True, exif=_exif().tobytes())
    strip_metadata(src, backup=False, mode=StripMode.GPS_ONLY)
    with Image.open(src) as out:
        exif = out.getexif()
        assert exif[0x010F] == "GizliKamera" and not exif.get_ifd(GPS_IFD)


def test_tiff_multipage_tags_removed(tmp_path: Path) -> None:
    src = tmp_path / "scan.tif"
    pages = [_photo(), Image.new("RGB", (20, 20), "blue")]
    pages[0].save(src, save_all=True, append_images=pages[1:], compression="tiff_lzw",
                  exif=_exif().tobytes(), tiffinfo={270: "Ahmet Yazar", 700: XMP})
    strip_metadata(src, backup=False, mode=StripMode.ALL)
    _assert_clean_bytes(src)
    with Image.open(src) as out:
        assert out.n_frames == 2  # sayfa kaybı yok
        assert 270 not in out.tag_v2 and 700 not in out.tag_v2
    assert not [t for t in read_metadata_tags(src) if t.risk == "high"]


def test_heic_exif_removed(tmp_path: Path) -> None:
    src = tmp_path / "telefon.heic"
    _photo().save(src, "HEIF", exif=_exif().tobytes(), quality=90)
    assert "Make" in {t.name for t in read_metadata_tags(src)}
    strip_metadata(src, backup=False, mode=StripMode.ALL)
    _assert_clean_bytes(src)
    assert not [t for t in read_metadata_tags(src) if t.name in ("Make", "Artist", "GPSLatitude")]


def _make_pdf(path: Path) -> None:
    writer = PdfWriter()
    writer.add_blank_page(200, 200)
    writer.add_blank_page(200, 200)
    writer.add_metadata({"/Author": "Ahmet Yazar", "/Creator": "GizliKamera", "/Title": "yorum-gizli"})
    from pypdf.generic import DecodedStreamObject, NameObject

    xmp = DecodedStreamObject()
    xmp.set_data(XMP)
    xmp.update({NameObject("/Type"): NameObject("/Metadata"), NameObject("/Subtype"): NameObject("/XML")})
    writer._root_object[NameObject("/Metadata")] = writer._add_object(xmp)
    with open(path, "wb") as fh:
        writer.write(fh)


def test_pdf_info_and_xmp_really_removed(tmp_path: Path) -> None:
    src = tmp_path / "belge.pdf"
    _make_pdf(src)
    assert is_supported(src)  # exiftool olmadan da desteklenir
    names = {t.name for t in read_metadata_tags(src)}
    assert {"PDF:Author", "XMP"} <= names

    result = strip_metadata(src, backup=True, mode=StripMode.ALL)

    _assert_clean_bytes(src)  # eski nesneler dosyada kalmamalı (artımlı güncelleme değil)
    reader = PdfReader(src)
    assert len(reader.pages) == 2
    assert not reader.metadata or not any(k in reader.metadata for k in ("/Author", "/Creator", "/Title"))
    assert "/Metadata" not in reader.trailer["/Root"]
    assert read_metadata_tags(src) == [] or all(t.risk != "high" for t in read_metadata_tags(src))
    assert result.backup and b"Ahmet Yazar" in result.backup.read_bytes()


def test_pdf_selective_mode_is_refused(tmp_path: Path) -> None:
    src = tmp_path / "belge.pdf"
    _make_pdf(src)
    before = src.read_bytes()
    with pytest.raises(RuntimeError):
        strip_metadata(src, backup=False, mode=StripMode.GPS_ONLY)
    assert src.read_bytes() == before


def test_video_without_exiftool_degrades_gracefully(tmp_path: Path) -> None:
    video = tmp_path / "klip.mp4"
    video.write_bytes(b"\x00\x00\x00\x18ftypmp42")
    assert not is_supported(video)
    assert collect_files([tmp_path]) == []
    assert count_needing_exiftool([tmp_path]) == 1
    with pytest.raises(RuntimeError, match="exiftool"):
        strip_metadata(video, backup=False)
    assert "exiftool" in EXIFTOOL_REQUIRED_MESSAGE


def test_failed_strip_keeps_original_and_leaves_no_temp(tmp_path: Path) -> None:
    src = tmp_path / "bozuk.jpg"
    _make_jpeg(src)
    data = src.read_bytes()
    src.write_bytes(data[:2] + b"\x00garbage")  # SOI sonrası bozuk yapı
    broken = src.read_bytes()
    with pytest.raises(Exception):
        strip_metadata(src, backup=False, mode=StripMode.ALL)
    assert src.read_bytes() == broken
    assert sorted(p.name for p in tmp_path.iterdir()) == ["bozuk.jpg"]


def test_copy_mode_never_overwrites(tmp_path: Path) -> None:
    src = tmp_path / "a.jpg"
    _make_jpeg(src)
    original = src.read_bytes()
    r1 = strip_metadata(src, backup=False, overwrite=False)
    r2 = strip_metadata(src, backup=False, overwrite=False)
    assert (r1.output.name, r2.output.name) == ("a_clean.jpg", "a_clean2.jpg")
    assert src.read_bytes() == original
    _assert_clean_bytes(r1.output)


def test_backup_restore_roundtrip(tmp_path: Path) -> None:
    src = tmp_path / "a.jpg"
    _make_jpeg(src)
    original = src.read_bytes()
    strip_metadata(src, backup=True)
    strip_metadata(src, backup=True)  # ikinci temizlik ilk (metadata'lı) yedeği ezmez
    restore_backup(src)
    assert src.read_bytes() == original
