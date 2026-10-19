from __future__ import annotations


def human_size(num: int | float) -> str:
    value = float(num)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024:
            if unit == "B":
                return f"{int(value)} B"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} PB"


def format_speed(files_per_sec: float) -> str:
    if files_per_sec < 1:
        return f"{files_per_sec:.2f} dosya/s"
    return f"{files_per_sec:,.0f} dosya/s"
