from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QMenu,
    QPushButton,
    QSizePolicy,
    QToolButton,
    QWidget,
)

from core.app_info import APP_NAME


class AppToolbar(QFrame):
    add_files = Signal()
    undo = Signal()
    redo = Signal()
    macro_save = Signal()
    macro_run = Signal()
    theme_toggle = Signal()
    apply = Signal()
    open_menu = Signal()

    def __init__(self, theme_icon: str = "🌙") -> None:
        super().__init__()
        self.setObjectName("AppToolbar")
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)

        row = QHBoxLayout(self)
        row.setContentsMargins(12, 8, 12, 8)
        row.setSpacing(8)

        title = QLabel(APP_NAME)
        title.setObjectName("AppTitle")
        row.addWidget(title, stretch=1)

        self._add_btn = QPushButton("Dosya Ekle…")
        self._add_btn.setObjectName("ToolbarButton")
        self._add_btn.setToolTip("Ctrl+O")
        self._add_btn.clicked.connect(self.add_files.emit)
        row.addWidget(self._add_btn)

        self._undo_btn = QPushButton("Geri Al")
        self._undo_btn.setObjectName("ToolbarButton")
        self._undo_btn.setEnabled(False)
        self._undo_btn.setToolTip("Ctrl+Z")
        self._undo_btn.clicked.connect(self.undo.emit)
        row.addWidget(self._undo_btn)

        self._redo_btn = QPushButton("Yinele")
        self._redo_btn.setObjectName("ToolbarButton")
        self._redo_btn.setEnabled(False)
        self._redo_btn.setToolTip("Ctrl+Y")
        self._redo_btn.clicked.connect(self.redo.emit)
        row.addWidget(self._redo_btn)

        macro_save = QPushButton("Makro Kaydet")
        macro_save.setObjectName("ToolbarGhostButton")
        macro_save.setToolTip("Ctrl+Shift+S")
        macro_save.clicked.connect(self.macro_save.emit)
        row.addWidget(macro_save)

        macro_run = QPushButton("Makro Çalıştır")
        macro_run.setObjectName("ToolbarGhostButton")
        macro_run.setToolTip("Ctrl+Shift+R")
        macro_run.clicked.connect(self.macro_run.emit)
        row.addWidget(macro_run)

        self._theme_btn = QPushButton(theme_icon)
        self._theme_btn.setObjectName("IconButton")
        self._theme_btn.setToolTip("Tema değiştir (Ctrl+T)")
        self._theme_btn.setAccessibleName("Tema değiştir")
        self._theme_btn.clicked.connect(self.theme_toggle.emit)
        row.addWidget(self._theme_btn)

        menu_btn = QToolButton()
        menu_btn.setObjectName("IconButton")
        menu_btn.setText("☰")
        menu_btn.setToolTip("Menü")
        menu_btn.setAccessibleName("Menü")
        menu_btn.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        self._menu_btn = menu_btn
        row.addWidget(menu_btn)

        sep = QFrame()
        sep.setObjectName("ToolbarSeparator")
        sep.setFixedWidth(1)
        sep.setFixedHeight(24)
        row.addWidget(sep)

        self._apply_btn = QPushButton("Dosya Yok")
        self._apply_btn.setObjectName("PrimaryButton")
        self._apply_btn.setEnabled(False)
        self._apply_btn.setToolTip("Ctrl+Enter (onaylı) · Ctrl+Shift+Enter (onaysız)")
        self._apply_btn.clicked.connect(self.apply.emit)
        row.addWidget(self._apply_btn)

    def set_menu(self, menu: QMenu) -> None:
        self._menu_btn.setMenu(menu)

    @property
    def apply_button(self) -> QPushButton:
        return self._apply_btn

    @property
    def undo_button(self) -> QPushButton:
        return self._undo_btn

    @property
    def redo_button(self) -> QPushButton:
        return self._redo_btn

    @property
    def menu_button(self) -> QToolButton:
        return self._menu_btn

    @property
    def theme_button(self) -> QPushButton:
        return self._theme_btn

    def set_theme_icon(self, icon: str) -> None:
        self._theme_btn.setText(icon)

    def set_undo_enabled(self, enabled: bool) -> None:
        self._undo_btn.setEnabled(enabled)

    def set_redo_enabled(self, enabled: bool) -> None:
        self._redo_btn.setEnabled(enabled)
