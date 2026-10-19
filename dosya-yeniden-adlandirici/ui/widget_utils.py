from __future__ import annotations

from PySide6.QtWidgets import QFrame, QSizePolicy


def configure_overlay(frame: QFrame) -> None:
    frame.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Ignored)
