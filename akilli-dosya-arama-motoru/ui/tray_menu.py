"""Sistem tepsisi bağlam menüsü — design/tray.html."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QAction
from PySide6.QtWidgets import QHBoxLayout, QLabel, QMenu, QVBoxLayout, QWidget, QWidgetAction

from ui import theme as T
from utils.index_backend import active_backend_name, get_index_stats
from utils.tray_icon import create_tray_header_icon


class TrayMenu(QMenu):
    """Tasarım sistemine uygun tepsi menüsü; indeks durumu güncellenebilir."""

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setMinimumWidth(240)
        self.setStyleSheet(T.TRAY_MENU_STYLESHEET)
        self._status_label: QLabel | None = None
        self._index_info_label: QLabel | None = None
        self._build_header()
        self._build_actions()
        self.update_index_status("Hazır", scanning=False)

    def _build_header(self) -> None:
        header = QWidget()
        header.setStyleSheet(
            f"background: {T.BG_PANEL}; border-bottom: 1px solid {T.BORDER};"
        )
        lay = QHBoxLayout(header)
        lay.setContentsMargins(14, 12, 14, 12)
        lay.setSpacing(10)

        icon = QLabel()
        icon.setPixmap(create_tray_header_icon(24))
        icon.setFixedSize(24, 24)
        icon.setStyleSheet("background: transparent;")

        text_col = QVBoxLayout()
        text_col.setSpacing(2)
        name = QLabel("Akıllı Dosya Arama")
        name.setStyleSheet(
            f"color: {T.TEXT_PRIMARY}; font-size: 13px; font-weight: 600; background: transparent;"
        )
        self._status_label = QLabel()
        self._status_label.setTextFormat(Qt.TextFormat.RichText)
        self._status_label.setStyleSheet(
            f"color: {T.TEXT_MUTED}; font-family: {T.FONT_MONO}; font-size: 10px; "
            f"background: transparent;"
        )
        text_col.addWidget(name)
        text_col.addWidget(self._status_label)

        lay.addWidget(icon)
        lay.addLayout(text_col, stretch=1)

        action = QWidgetAction(self)
        action.setDefaultWidget(header)
        self.addAction(action)

    def _build_actions(self) -> None:
        open_search = QAction("Aramayı aç", self)
        open_search.setShortcut("Ctrl+Space")
        self.addAction(open_search)
        self._open_search = open_search

        info = QWidget()
        info_lay = QVBoxLayout(info)
        info_lay.setContentsMargins(14, 8, 14, 10)
        self._index_info_label = QLabel()
        self._index_info_label.setStyleSheet(
            f"color: {T.TEXT_MUTED}; font-family: {T.FONT_MONO}; font-size: 10px; "
            f"background: transparent;"
        )
        info_lay.addWidget(self._index_info_label)
        info_action = QWidgetAction(self)
        info_action.setDefaultWidget(info)
        self.addAction(info_action)

        self.addSeparator()

        open_settings = QAction("İndeks ayarları", self)
        self.addAction(open_settings)
        self._open_settings = open_settings

        reindex = QAction("Yeniden indeksle", self)
        self.addAction(reindex)
        self._reindex = reindex

        self.addSeparator()

        quit_action = QAction("Çıkış", self)
        self.addAction(quit_action)
        self._quit = quit_action

    def update_index_status(self, label: str, *, scanning: bool = False, error: bool = False) -> None:
        if not self._status_label:
            return
        if error:
            dot_color = T.DANGER
        elif scanning:
            dot_color = T.WARNING
        else:
            dot_color = T.SUCCESS
        self._status_label.setText(f'<span style="color:{dot_color};">●</span> {label}')
        self._refresh_index_info()

    def _refresh_index_info(self) -> None:
        if not self._index_info_label:
            return
        stats = get_index_stats()
        backend = active_backend_name().upper()
        built = stats.get("built_at") or "henüz yok"
        self._index_info_label.setText(f"{backend} indeks · Son güncelleme {built}")

    @property
    def open_search_action(self) -> QAction:
        return self._open_search

    @property
    def open_settings_action(self) -> QAction:
        return self._open_settings

    @property
    def reindex_action(self) -> QAction:
        return self._reindex

    @property
    def quit_action(self) -> QAction:
        return self._quit
