def human_size(num: int) -> str:
    if num < 0:
        num = 0
    value = float(num)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if value < 1024:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024
    return f"{value:.1f} PB"


def percent(part: int, whole: int) -> float:
    if whole <= 0:
        return 0.0
    return part / whole * 100
