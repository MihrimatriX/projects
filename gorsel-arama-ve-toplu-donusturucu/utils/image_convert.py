"""Görsel listeleme ve toplu dönüştürme — Pillow."""
from __future__ import annotations

import os
from collections.abc import Callable
from pathlib import Path

from PIL import Image, ImageOps

from utils.convert_options import ConvertOptions

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".tif", ".avif", ".heic"}


def is_image(path: str | Path) -> bool:
    return Path(path).suffix.lower() in IMAGE_EXTS


def list_images(folder: str | Path) -> list[str]:
    root = Path(folder)
    return sorted(str(p) for p in root.rglob("*") if p.is_file() and p.suffix.lower() in IMAGE_EXTS)


def collect_images(paths: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            for img in (str(Path(i).resolve()) for i in list_images(p)):
                if img not in seen:
                    seen.add(img)
                    out.append(img)
        elif p.is_file() and is_image(p):
            resolved = str(p.resolve())
            if resolved not in seen:
                seen.add(resolved)
                out.append(resolved)
    return out


def common_root(paths: list[str]) -> str:
    if not paths:
        return ""
    parts = [Path(p).parent.parts for p in paths]
    common: list[str] = []
    for seg in zip(*parts, strict=False):
        if len(set(seg)) == 1:
            common.append(seg[0])
        else:
            break
    return str(Path(*common)) if common else ""


def image_dimensions(path: str | Path) -> tuple[int, int]:
    with Image.open(path) as img:
        return img.size


def fit_dimensions(w: int, h: int, max_w: int, max_h: int) -> tuple[int, int]:
    limit_w = max_w if max_w > 0 else w
    limit_h = max_h if max_h > 0 else h
    if max_w <= 0 and max_h <= 0:
        return w, h
    ratio = min(limit_w / w, limit_h / h, 1.0)
    if ratio >= 1.0:
        return w, h
    return max(1, int(w * ratio)), max(1, int(h * ratio))


def format_meta(path: str, opts: ConvertOptions) -> str:
    w, h = image_dimensions(path)
    nw, nh = fit_dimensions(w, h, opts.max_width, opts.max_height)
    ext = opts.fmt.upper()
    if (nw, nh) != (w, h):
        return f"{w}×{h} → {nw}×{nh} · {ext}"
    return f"{w}×{h} · {ext}"


ORIENTATION_TAG = 0x0112
_GRAY_MODES = {"1", "L", "LA", "La", "I", "I;16", "I;16B", "I;16L", "F"}


def target_path(src: Path, out_root: Path, opts: ConvertOptions) -> Path:
    ext = "jpg" if opts.fmt == "jpeg" else opts.fmt
    dest_dir = out_root
    if opts.preserve_tree and opts.source_root:
        try:
            dest_dir = out_root / src.parent.relative_to(Path(opts.source_root))
        except ValueError:
            pass
    return dest_dir / f"{src.stem}.{ext}"


def _path_key(path: Path) -> str:
    return os.path.normcase(os.path.abspath(path))


def unique_path(dest: Path, taken: set[str] | None = None, *, allow_existing: bool = False) -> Path:
    """Çakışmayan çıktı yolu: ``ad.webp`` doluysa ``ad (1).webp``, ``ad (2).webp``…

    ``allow_existing`` yalnızca diskteki dosyanın üzerine yazmaya izin verir; aynı
    toplu işte başka bir kaynağın ürettiği çıktı (``taken``) asla ezilmez.
    """
    taken = taken or set()
    candidate, n = dest, 0
    while _path_key(candidate) in taken or (not allow_existing and candidate.exists()):
        n += 1
        candidate = dest.with_name(f"{dest.stem} ({n}){dest.suffix}")
    return candidate


def _color_space(mode: str) -> str:
    if mode in _GRAY_MODES:
        return "L"
    return "CMYK" if mode == "CMYK" else "RGB"


def _prepare_image(img: Image.Image, opts: ConvertOptions) -> Image.Image:
    # Sıra önemli: önce EXIF'e göre döndür (boyutlar yer değiştirebilir), sonra
    # oranı koruyarak küçült (asla büyütmez), en son renk işlemleri.
    if opts.exif_rotate:
        img = ImageOps.exif_transpose(img)
    nw, nh = fit_dimensions(img.width, img.height, opts.max_width, opts.max_height)
    if (nw, nh) != (img.width, img.height):
        if img.mode in ("1", "P"):  # paletli görsellerde LANCZOS yok sayılır (NEAREST'e düşer)
            img = img.convert("RGBA" if img.has_transparency_data else "RGB")
        img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    if opts.grayscale:
        img = img.convert("LA" if img.has_transparency_data else "L")
    return img


def _fit_mode(img: Image.Image, fmt: str) -> Image.Image:
    """Görseli hedef formatın yazabileceği moda getirir; şeffaflık korunur ya da beyaza düzleştirilir."""
    if fmt == "png" and img.mode in ("1", "L", "LA", "P", "RGB", "RGBA", "I", "I;16"):
        return img
    if img.mode.startswith("I"):  # 16 bit (ör. PNG/TIFF taraması): kırpmak yerine 8 bite ölçekle
        img = img.point(lambda v: v * (1 / 256)).convert("L")
    alpha = img.has_transparency_data
    if fmt == "jpeg":
        if alpha:  # JPEG'de alfa yok: siyah zemin yerine beyaz zemine bindir
            rgba = img.convert("RGBA")
            flat = Image.new("RGB", rgba.size, (255, 255, 255))
            flat.paste(rgba, mask=rgba.getchannel("A"))
            return flat.convert("L") if _color_space(img.mode) == "L" else flat
        return img if img.mode in ("L", "RGB", "CMYK") else img.convert("RGB")
    if img.mode in ("RGB", "RGBA"):
        return img
    return img.convert("RGBA" if alpha else "RGB")


def _save_image(img: Image.Image, dest: Path, opts: ConvertOptions, meta: dict) -> None:
    fmt = opts.fmt.lower()
    save_kw: dict = dict(meta)

    if fmt == "jpeg":
        save_kw.update(
            quality=opts.quality,
            progressive=opts.jpeg_progressive,
            optimize=opts.jpeg_optimize,
        )
        if opts.jpeg_subsampling >= 0:
            save_kw["subsampling"] = opts.jpeg_subsampling
        img.save(dest, format="JPEG", **save_kw)
        return

    if fmt == "webp":
        save_kw["method"] = opts.webp_method
        if opts.webp_lossless:
            save_kw["lossless"] = True
        else:
            save_kw["quality"] = opts.quality
        img.save(dest, format="WEBP", **save_kw)
        return

    if fmt == "png":
        save_kw["compress_level"] = opts.png_compress
        save_kw["optimize"] = opts.png_optimize
        img.save(dest, format="PNG", **save_kw)
        return

    if fmt == "avif":
        save_kw["quality"] = opts.quality
        img.save(dest, format="AVIF", **save_kw)
        return

    raise ValueError(f"Desteklenmeyen format: {fmt}")


def _output_metadata(src: Image.Image, out: Image.Image, opts: ConvertOptions) -> dict:
    """Pillow EXIF'i kendiliğinden yazmaz; korunacak olanı açıkça veririz.

    Renk profili (ICC) renk verisidir, kişisel bilgi değildir: renk uzayı değişmediyse
    hep korunur. EXIF (GPS dahil) yalnızca "Metadata temizle" kapalıyken yazılır;
    döndürme uygulandıysa Orientation etiketi düşülür ki görüntüleyici tekrar döndürmesin.
    """
    icc = src.info.get("icc_profile")
    meta: dict = {"icc_profile": icc if icc and _color_space(src.mode) == _color_space(out.mode) else None}
    if not opts.strip_metadata:
        exif = src.getexif()
        if opts.exif_rotate:
            exif.pop(ORIENTATION_TAG, None)
        if len(exif):
            meta["exif"] = exif.tobytes()
    return meta


def convert_one(
    src: str, output_dir: str, opts: ConvertOptions, *, taken: set[str] | None = None
) -> str:
    src_path = Path(src)
    dest = unique_path(target_path(src_path, Path(output_dir), opts), taken, allow_existing=opts.overwrite)
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Önce geçici dosyaya yaz, sonra yerine taşı: yarım kalan kayıt var olan dosyayı
    # (seçildiyse orijinali) bozmaz, kaynak okunurken üzerine yazılmaz.
    tmp = dest.with_name(f".{dest.name}.{os.getpid()}.tmp")
    try:
        with Image.open(src_path) as img:
            out = _fit_mode(_prepare_image(img, opts), opts.fmt)
            _save_image(out, tmp, opts, _output_metadata(img, out, opts))
        os.replace(tmp, dest)
    finally:
        tmp.unlink(missing_ok=True)
    if taken is not None:
        taken.add(_path_key(dest))
    return str(dest)


def convert_batch(
    sources: list[str],
    output_dir: str,
    opts: ConvertOptions,
    *,
    on_file: Callable[[int, str | None, str | None], None] | None = None,
    on_progress: Callable[[int, int], None] | None = None,
    cancel_check: Callable[[], bool] | None = None,
) -> tuple[list[str], list[tuple[str, str]]]:
    batch_opts = ConvertOptions(**{**opts.__dict__})
    if batch_opts.preserve_tree and not batch_opts.source_root:
        batch_opts.source_root = common_root(sources)

    out_root = Path(output_dir)
    out_root.mkdir(parents=True, exist_ok=True)
    converted: list[str] = []
    errors: list[tuple[str, str]] = []
    total = len(sources)
    taken: set[str] = set()  # bu toplu işte üretilen çıktılar; ad çakışmasında ezilmez

    for idx, src in enumerate(sources, start=1):
        if cancel_check and cancel_check():
            break
        try:
            dest = convert_one(src, output_dir, batch_opts, taken=taken)
            converted.append(dest)
            if on_file:
                on_file(idx - 1, dest, None)
        except Exception as exc:
            errors.append((src, str(exc)))
            if on_file:
                on_file(idx - 1, None, str(exc))
        if on_progress:
            on_progress(idx, total)

    return converted, errors


if __name__ == "__main__":
    assert is_image("photo.webp") and not is_image("readme.txt")
    assert fit_dimensions(4000, 3000, 1920, 0) == (1920, 1440)
    assert fit_dimensions(800, 600, 1920, 1080) == (800, 600)
    print("image_convert self-check ok")
