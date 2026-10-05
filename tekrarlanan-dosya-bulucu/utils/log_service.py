from __future__ import annotations

from datetime import datetime, timezone

from utils.settings import APP_DIR

LOG_PATH = APP_DIR / "app.log"
_MAX_BYTES = 512 * 1024


def log(message: str) -> None:
    try:
        APP_DIR.mkdir(parents=True, exist_ok=True)
        if LOG_PATH.exists() and LOG_PATH.stat().st_size > _MAX_BYTES:
            LOG_PATH.write_text("", encoding="utf-8")
        stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        with LOG_PATH.open("a", encoding="utf-8") as handle:
            handle.write(f"[{stamp}] {message}\n")
    except OSError:
        pass
