from __future__ import annotations

from datetime import datetime, timezone


def scheduled_scan_due(
    *,
    enabled: bool,
    last_scan_utc: str,
    interval_days: int,
) -> bool:
    if not enabled or interval_days < 1:
        return False
    if not last_scan_utc:
        return True
    try:
        prev = datetime.fromisoformat(last_scan_utc.replace("Z", "+00:00"))
        if prev.tzinfo is None:
            prev = prev.replace(tzinfo=timezone.utc)
    except ValueError:
        return True
    now = datetime.now(timezone.utc)
    return (now - prev).days >= interval_days


def stamp_scheduled_scan() -> str:
    return datetime.now(timezone.utc).isoformat()
