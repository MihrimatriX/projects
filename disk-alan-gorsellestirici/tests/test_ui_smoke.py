from __future__ import annotations

import os

import pytest

pytest.importorskip("PySide6")


def test_main_window_smoke():
    os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
    from PySide6.QtWidgets import QApplication

    from ui.main_window import MainWindow

    app = QApplication.instance() or QApplication([])
    window = MainWindow()
    assert window.centralWidget() is not None
    assert window.sidebar is not None
