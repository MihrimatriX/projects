"""Testler gerçek %LOCALAPPDATA%/DiskAlanGorsellestirici'ye (ayar/önbellek) dokunmasın."""
from __future__ import annotations

import os
import tempfile

os.environ["LOCALAPPDATA"] = tempfile.mkdtemp(prefix="disk-alan-test-")
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
