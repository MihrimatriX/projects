"""Testler gerçek kullanıcı klasörüne (ayarlar, geri alma geçmişi) dokunmasın."""
from __future__ import annotations

import os
import tempfile

_home = tempfile.mkdtemp(prefix="dyad-test-home-")
os.environ["USERPROFILE"] = _home
os.environ["HOME"] = _home
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

# Hoş geldin diyaloğu modal açılır; pytest-qt test sonunda olay döngüsünü çalıştırdığında
# testleri kilitlemesin.
_settings_dir = os.path.join(_home, ".local", "share", "DosyaYenidenAdlandirici")
os.makedirs(_settings_dir, exist_ok=True)
with open(os.path.join(_settings_dir, "settings.json"), "w", encoding="utf-8") as _fh:
    _fh.write('{"show_welcome": false}')
