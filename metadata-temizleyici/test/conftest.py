"""Testler gerçek kullanıcı klasörüne (~/.metadata-temizleyici, %LOCALAPPDATA%) dokunmasın ve
exiftool kurulu olsa bile yerel motoru sınasın."""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

_tmp = tempfile.mkdtemp(prefix="metadata-test-")
os.environ["USERPROFILE"] = _tmp
os.environ["HOME"] = _tmp
os.environ["LOCALAPPDATA"] = _tmp
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import pillow_heif  # noqa: E402

from utils import exiftool_engine  # noqa: E402

pillow_heif.register_heif_opener()
exiftool_engine._EXIFTOOL = False
