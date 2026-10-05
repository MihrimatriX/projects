from __future__ import annotations

import os
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
# Gerçek %LOCALAPPDATA%\TekrarlananDosyaBulucu ve çalışan uygulamanın IPC kanalı testlerden etkilenmesin.
os.environ.setdefault("TEKRARLANAN_DATA_DIR", tempfile.mkdtemp(prefix="tekrarlanan-test-"))
os.environ.setdefault("TEKRARLANAN_IPC_NAME", f"tekdosya_test_{os.getpid()}")

# Tek bir QApplication: QCoreApplication testleri onu paylaşır, pencere testleri çökmez.
from PySide6.QtWidgets import QApplication  # noqa: E402

_APP = QApplication.instance() or QApplication([])
