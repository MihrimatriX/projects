from __future__ import annotations

from pathlib import Path

TEXT_EXTENSIONS = frozenset(
    {
        ".txt",
        ".md",
        ".py",
        ".json",
        ".xml",
        ".html",
        ".css",
        ".js",
        ".ts",
        ".csv",
        ".log",
        ".ini",
        ".yaml",
        ".yml",
    }
)
MAX_PREVIEW_BYTES = 240
MAX_FILE_SIZE = 512 * 1024


def _pdf_preview(path: Path) -> str | None:
    try:
        from pypdf import PdfReader
    except ImportError:
        return None
    try:
        reader = PdfReader(str(path))
        if not reader.pages:
            return None
        text = (reader.pages[0].extract_text() or "").replace("\n", " ").strip()
        if not text:
            return "PDF (metin çıkarılamadı)"
        return text[:117] + ("…" if len(text) > 120 else "")
    except Exception:
        return None


def file_preview(path: str) -> str | None:
    p = Path(path)
    if p.suffix.lower() == ".pdf":
        return _pdf_preview(p)
    if p.suffix.lower() not in TEXT_EXTENSIONS:
        return None
    try:
        if p.stat().st_size > MAX_FILE_SIZE:
            return None
        raw = p.read_bytes()[:MAX_PREVIEW_BYTES]
        text = raw.decode("utf-8", errors="replace").replace("\n", " ").strip()
        if not text:
            return None
        if len(text) > 120:
            return text[:117] + "…"
        return text
    except OSError:
        return None
