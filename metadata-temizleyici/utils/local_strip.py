"""exiftool olmadan yerel metadata temizliği.

JPEG / PNG / WebP: dosya kapsayıcısı (segment / chunk) yeniden yazılır, piksel verisi
bayt bayt aynı kalır (kalite kaybı yok). EXIF, XMP, IPTC (APP13), yorumlar, metin
chunk'ları ve JPEG sonundaki ek veriler (MPF önizlemeleri vb.) atılır; renk profili
(ICC), Adobe renk dönüşümü ve şeffaflık korunur.
TIFF / HEIC / BMP: Pillow ile yalnızca piksel + ICC yeniden kaydedilir.
PDF: pypdf ile /Info sözlüğü ve XMP akışları silinip dosya yeniden yazılır (exiftool'un
PDF düzenlemesi geri alınabilir olduğu için eski metadata dosyada kalırdı).
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

from PIL import Image, ImageSequence

EXIF_HEADER = b"Exif\x00\x00"


class StripError(RuntimeError):
    pass


# --- JPEG -------------------------------------------------------------------

def _jpeg_keep(marker: int, payload: bytes) -> bool:
    if marker == 0xFE:  # COM
        return False
    if 0xE1 <= marker <= 0xEF:  # APP1..APP15: EXIF, XMP, ICC, IPTC, MPF, üretici blokları
        if marker == 0xE2:
            return payload.startswith(b"ICC_PROFILE\x00")
        return marker == 0xEE and payload.startswith(b"Adobe")  # renk dönüşümü için gerekli
    return True


def strip_jpeg(data: bytes, exif: bytes | None = None) -> bytes:
    if data[:2] != b"\xff\xd8":
        raise StripError("Geçersiz JPEG")
    out = bytearray(b"\xff\xd8")
    pending_exif = exif
    i, n = 2, len(data)
    while i + 1 < n:
        if data[i] != 0xFF:
            raise StripError("Bozuk JPEG yapısı")
        marker = data[i + 1]
        if marker == 0xFF:  # dolgu baytı
            i += 1
            continue
        if marker == 0xD9:  # EOI: sonrasındaki ek veriler (MPF görselleri, üretici trailer) atılır
            break
        if marker == 0x01 or 0xD0 <= marker <= 0xD7:
            out += data[i:i + 2]
            i += 2
            continue
        if i + 4 > n:
            raise StripError("Bozuk JPEG yapısı")
        length = struct.unpack(">H", data[i + 2:i + 4])[0]
        end = i + 2 + length
        if pending_exif is not None and marker != 0xE0:  # yeni EXIF, JFIF APP0'dan hemen sonra
            body = pending_exif if pending_exif.startswith(EXIF_HEADER) else EXIF_HEADER + pending_exif
            if len(body) + 2 > 0xFFFF:
                raise StripError("EXIF bloğu çok büyük")
            out += b"\xff\xe1" + struct.pack(">H", len(body) + 2) + body
            pending_exif = None
        if _jpeg_keep(marker, data[i + 4:end]):
            out += data[i:end]
        i = end
        if marker == 0xDA:  # SOS: entropi verisi bir sonraki gerçek işarete kadar kopyalanır
            j = i
            while True:
                j = data.find(b"\xff", j)
                if j < 0 or j + 1 >= n:
                    j = n
                    break
                nxt = data[j + 1]
                if nxt == 0x00 or 0xD0 <= nxt <= 0xD7 or nxt == 0xFF:
                    j += 1 if nxt == 0xFF else 2
                    continue
                break
            out += data[i:j]
            i = j
    out += b"\xff\xd9"
    return bytes(out)


# --- PNG --------------------------------------------------------------------

PNG_SIG = b"\x89PNG\r\n\x1a\n"
_PNG_DROP = {b"tEXt", b"zTXt", b"iTXt", b"eXIf", b"tIME"}


def _png_chunk(ctype: bytes, body: bytes) -> bytes:
    return struct.pack(">I", len(body)) + ctype + body + struct.pack(">I", zlib.crc32(ctype + body))


def strip_png(data: bytes, exif: bytes | None = None) -> bytes:
    if not data.startswith(PNG_SIG):
        raise StripError("Geçersiz PNG")
    out = bytearray(PNG_SIG)
    i = len(PNG_SIG)
    while i + 8 <= len(data):
        length = struct.unpack(">I", data[i:i + 4])[0]
        ctype = data[i + 4:i + 8]
        end = i + 12 + length
        if ctype == b"IDAT" and exif:
            out += _png_chunk(b"eXIf", exif.removeprefix(EXIF_HEADER))
            exif = None
        if ctype not in _PNG_DROP:
            out += data[i:end]
        i = end
        if ctype == b"IEND":
            break
    return bytes(out)


# --- WebP -------------------------------------------------------------------

def strip_webp(data: bytes, exif: bytes | None = None) -> bytes:
    if data[:4] != b"RIFF" or data[8:12] != b"WEBP":
        raise StripError("Geçersiz WebP")
    chunks: list[list] = []
    i = 12
    while i + 8 <= len(data):
        fourcc = data[i:i + 4]
        size = struct.unpack("<I", data[i + 4:i + 8])[0]
        chunks.append([fourcc, data[i + 8:i + 8 + size]])
        i += 8 + size + (size & 1)
    chunks = [c for c in chunks if c[0] not in (b"EXIF", b"XMP ")]
    for c in chunks:
        if c[0] == b"VP8X":  # bayraklar: 0x08 EXIF, 0x04 XMP
            flags = c[1][0] & ~0x0C
            if exif:
                flags |= 0x08
            c[1] = bytes([flags]) + c[1][1:]
    if exif and any(c[0] == b"VP8X" for c in chunks):
        chunks.append([b"EXIF", exif.removeprefix(EXIF_HEADER)])
    body = bytearray(b"WEBP")
    for fourcc, payload in chunks:
        body += fourcc + struct.pack("<I", len(payload)) + payload + (b"\x00" if len(payload) & 1 else b"")
    return b"RIFF" + struct.pack("<I", len(body)) + bytes(body)


LOSSLESS = {".jpg": strip_jpeg, ".jpeg": strip_jpeg, ".png": strip_png, ".webp": strip_webp}


# --- Diğer görseller (yeniden kodlama) -----------------------------------------

_TIFF_LOSSLESS = {"raw", "tiff_lzw", "tiff_adobe_deflate", "tiff_deflate", "packbits"}


def resave_image(src: Path, dest: Path, exif: bytes | None = None) -> None:
    with Image.open(src) as img:
        fmt = img.format or "PNG"
        frames = []
        for frame in ImageSequence.Iterator(img):
            clean = frame.copy()  # düz Image: TIFF tag'leri (XMP/IPTC) ve info taşınmaz
            clean.info = {k: frame.info[k] for k in ("transparency",) if k in frame.info}
            frames.append(clean)
        kw: dict = {}
        if icc := img.info.get("icc_profile"):
            kw["icc_profile"] = icc
        if exif:
            kw["exif"] = exif
        if fmt == "TIFF":
            comp = img.info.get("compression")
            kw["compression"] = comp if comp in _TIFF_LOSSLESS else "tiff_lzw"
        elif fmt == "HEIF":
            kw["quality"] = 95
        if len(frames) > 1:
            if fmt not in ("TIFF", "HEIF"):
                raise StripError(f"Çok kareli {fmt} desteklenmiyor")
            kw.update(save_all=True, append_images=frames[1:])
        frames[0].save(dest, format=fmt, **kw)


# --- PDF --------------------------------------------------------------------

def read_pdf_metadata(src: Path) -> dict[str, str]:
    from pypdf import PdfReader

    reader = PdfReader(src)
    if reader.is_encrypted:
        raise StripError("Şifreli PDF okunamıyor")
    out = {str(k).lstrip("/"): str(v) for k, v in (reader.metadata or {}).items()}
    if "/Metadata" in reader.trailer["/Root"]:
        out["XMP"] = "(XMP metadata akışı)"
    return out


def strip_pdf(src: Path, dest: Path) -> None:
    from pypdf import PdfReader, PdfWriter
    from pypdf.generic import NameObject

    reader = PdfReader(src)
    if reader.is_encrypted:
        raise StripError("Şifreli PDF temizlenemez")
    writer = PdfWriter(clone_from=reader)
    drop = (NameObject("/Metadata"), NameObject("/PieceInfo"))
    for obj in (writer._root_object, *writer.pages):
        for key in drop:
            obj.pop(key, None)
    writer.metadata = None
    writer.compress_identical_objects(remove_duplicates=False, remove_unreferenced=True)
    with open(dest, "wb") as fh:
        writer.write(fh)
