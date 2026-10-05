"""Ayar kalıcılığı + pencere açılış duman testi (offscreen)."""
from __future__ import annotations

from utils import config


def test_settings_roundtrip_and_corrupt_file() -> None:
    config.save_settings({"fmt": "png", "quality": 50})
    assert config.load_settings() == {"fmt": "png", "quality": 50}
    (config.data_dir() / "settings.json").write_text("{bozuk", encoding="utf-8")
    assert config.load_settings() == {}


def test_main_window_opens_and_persists_settings(tmp_path) -> None:
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    app = QApplication.instance() or QApplication([])
    config.save_settings({"fmt": "jpeg", "quality": 70, "overwrite": True, "max_width": 1280,
                          "output_dir": str(tmp_path), "jpeg_subsampling": "x"})
    win = MainWindow()
    opts = win._current_options()
    assert (opts.fmt, opts.quality, opts.overwrite, opts.max_width) == ("jpeg", 70, True, 1280)
    assert win._output_dir == str(tmp_path)
    win._quality.setValue(42)
    win.close()
    app.processEvents()
    assert config.load_settings()["quality"] == 42
