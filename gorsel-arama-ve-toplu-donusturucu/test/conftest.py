"""Testler gerçek %LOCALAPPDATA% / kullanıcı klasörüne (ayarlar, ~/Pictures) dokunmasın."""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

_tmp = tempfile.mkdtemp(prefix="gorsel-test-")
os.environ["LOCALAPPDATA"] = _tmp
os.environ["USERPROFILE"] = _tmp
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
