from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QBrush, QFont
from PySide6.QtWidgets import (
    QAbstractItemView,
    QHeaderView,
    QTableWidget,
    QTableWidgetItem,
)

from core.models import PreviewRow, PreviewStatus
from ui.theme import DARK, FONT_MONO, LIGHT, ROW_HEIGHT


class PreviewTable(QTableWidget):
    def __init__(self) -> None:
        super().__init__(0, 4)
        self._theme = "dark"
        self.setHorizontalHeaderLabels(["ESKİ AD", "", "YENİ AD", "DURUM"])
        header = self.horizontalHeader()
        header.setStretchLastSection(False)
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        header.setDefaultAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter)
        self.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        # Çoklu seçim: Delete ile birden fazla dosya listeden çıkarılabilsin.
        self.setSelectionMode(QAbstractItemView.SelectionMode.ExtendedSelection)
        self.setAccessibleName("Önizleme tablosu")
        self.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.setAlternatingRowColors(False)
        self.setShowGrid(False)
        self.setWordWrap(False)
        self.verticalHeader().setVisible(False)
        self.verticalHeader().setDefaultSectionSize(ROW_HEIGHT)
        self.setColumnWidth(1, 32)
        self.setColumnWidth(3, 120)

    def set_theme(self, theme: str) -> None:
        self._theme = theme

    def _palette(self) -> dict[str, str]:
        return LIGHT if self._theme == "light" else DARK

    def set_rows(self, rows: list[PreviewRow]) -> None:
        p = self._palette()
        mono = QFont(FONT_MONO, 10)

        self.setRowCount(len(rows))
        for i, row in enumerate(rows):
            old_item = QTableWidgetItem(row.original_name)
            arrow_item = QTableWidgetItem("→")
            arrow_item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            new_item = QTableWidgetItem(row.new_name)
            status_item = QTableWidgetItem(self._status_text(row))

            for item in (old_item, new_item, arrow_item, status_item):
                item.setToolTip(item.text())

            old_fg = QColor(p["preview_old"])
            new_fg = QColor(p["preview_new"])
            muted = QColor(p["text_muted"])
            danger_bg = QColor(p["danger"])
            danger_bg.setAlpha(30 if self._theme == "dark" else 25)

            if row.status == PreviewStatus.UNCHANGED:
                old_item.setForeground(QBrush(muted))
                new_item.setForeground(QBrush(muted))
                italic = QFont(mono)
                italic.setItalic(True)
                old_item.setFont(italic)
                new_item.setFont(italic)
            else:
                old_item.setForeground(QBrush(old_fg))
                old_item.setFont(mono)
                if row.status == PreviewStatus.OK and row.changed:
                    old_item.setFont(self._strike_font(mono))
                new_item.setForeground(QBrush(new_fg))
                new_item.setFont(mono)

            arrow_item.setForeground(QBrush(QColor(p["text_muted"])))

            if row.status in (
                PreviewStatus.CONFLICT,
                PreviewStatus.ERROR,
                PreviewStatus.RESERVED,
            ):
                for item in (old_item, arrow_item, new_item, status_item):
                    item.setBackground(QBrush(danger_bg))
                status_item.setForeground(QBrush(QColor(p["danger"])))
            elif row.status == PreviewStatus.OK and row.changed:
                status_item.setForeground(QBrush(QColor(p["success"])))
            elif row.status == PreviewStatus.UNCHANGED:
                status_item.setForeground(QBrush(muted))

            self.setItem(i, 0, old_item)
            self.setItem(i, 1, arrow_item)
            self.setItem(i, 2, new_item)
            self.setItem(i, 3, status_item)

    @staticmethod
    def _strike_font(font: QFont) -> QFont:
        struck = QFont(font)
        struck.setStrikeOut(True)
        return struck

    @staticmethod
    def _status_text(row: PreviewRow) -> str:
        if row.status == PreviewStatus.OK:
            return "Geçerli" if row.changed else "Değişmedi"
        if row.status == PreviewStatus.UNCHANGED:
            return "Değişmedi"
        if row.status == PreviewStatus.CONFLICT:
            return "Çakışma"
        if row.message:
            return row.message
        return "Hata"
