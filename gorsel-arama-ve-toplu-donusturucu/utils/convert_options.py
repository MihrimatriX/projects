"""Dönüştürme ve sıkıştırma ayarları."""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ConvertOptions:
    fmt: str = "webp"
    max_width: int = 1920
    max_height: int = 0
    quality: int = 85
    exif_rotate: bool = True
    strip_metadata: bool = False
    grayscale: bool = False
    # JPEG
    jpeg_progressive: bool = True
    jpeg_optimize: bool = True
    jpeg_subsampling: int = -1  # -1=auto, 0=4:4:4, 2=4:2:0
    # WebP
    webp_method: int = 4
    webp_lossless: bool = False
    # PNG
    png_compress: int = 6
    png_optimize: bool = True
    # çıktı
    preserve_tree: bool = False
    source_root: str = ""
    # False: aynı adlı dosya varsa "ad (1).uzanti" üretilir; orijinaller asla ezilmez
    overwrite: bool = False

    def lossy(self) -> bool:
        if self.fmt == "webp" and self.webp_lossless:
            return False
        return self.fmt in ("jpeg", "webp", "avif")
