import json
import os
from pathlib import Path

APP_NAME = "Görsel Arama ve Toplu Dönüştürücü"
APP_VERSION = "1.1.0"
APP_ID = "gorsel-arama-ve-toplu-donusturucu"

MIN_WIDTH = 720
MIN_HEIGHT = 520
DEFAULT_WIDTH = 980
DEFAULT_HEIGHT = 680
SIDEBAR_WIDTH = 300

DEFAULT_OUTPUT = Path.home() / "Pictures" / "converted"
FORMATS = ("webp", "jpeg", "png", "avif")
WIDTH_PRESETS = ((0, "Orijinal"), (800, "800"), (1280, "1280"), (1920, "1920"))
HEIGHT_PRESETS = ((0, "Orijinal"), (1080, "1080"), (1440, "1440"), (2160, "2160"))
DEFAULT_MAX_WIDTH = 1920
DEFAULT_MAX_HEIGHT = 0
DEFAULT_QUALITY = 85
WEBP_METHODS = tuple(range(7))


def data_dir() -> Path:
    """Yazılabilir uygulama verisi klasörü (exe yanına değil)."""
    base = os.environ.get("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
    return Path(base) / APP_ID


def load_settings() -> dict:
    try:
        data = json.loads((data_dir() / "settings.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def save_settings(data: dict) -> None:
    path = data_dir() / "settings.json"
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(tmp, path)
    except OSError:
        pass  # ayar kaydedilemezse uygulama kapanışı engellenmemeli
