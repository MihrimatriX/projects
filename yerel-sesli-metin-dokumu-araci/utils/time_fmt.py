"""Zaman biçimlendirme yardımcıları."""

from __future__ import annotations


def format_duration(seconds: float | None) -> str:
    if seconds is None or seconds < 0:
        return "?:??"
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    if h:
        return f"{h}:{m:02d}:{s:02d}"
    return f"{m:02d}:{s:02d}"


def format_job_date(iso: str) -> str:
    """ISO UTC → kısa Türkçe tarih."""
    try:
        from datetime import datetime

        dt = datetime.fromisoformat(iso.replace("Z", "+00:00"))
        months = "Oca Şub Mar Nis May Haz Tem Ağu Eyl Eki Kas Ara".split()
        return f"{dt.day} {months[dt.month - 1]} · {dt.strftime('%H:%M')}"
    except ValueError:
        return iso[:16] if len(iso) >= 16 else iso
