from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import QHeaderView, QTableWidget, QTableWidgetItem

from utils.models import MetadataTag
from utils.tag_labels import risk_label
from ui.theme import DANGER, SUCCESS, TEXT_MUTED


class MetadataTable(QTableWidget):
    COLUMNS = ("Tag", "Değer", "Risk")

    def __init__(self, parent=None) -> None:
        super().__init__(0, len(self.COLUMNS), parent)
        self.setObjectName("MetadataTable")
        self.setHorizontalHeaderLabels(self.COLUMNS)
        self.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.setSelectionBehavior(QTableWidget.SelectionBehavior.SelectRows)
        self.setSelectionMode(QTableWidget.SelectionMode.ExtendedSelection)
        self.setAlternatingRowColors(True)
        self.verticalHeader().setVisible(False)
        self.horizontalHeader().setStretchLastSection(False)
        self.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        self.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)

    def set_tags(self, tags: list[MetadataTag]) -> None:
        self.clearSpans()
        self.setRowCount(len(tags))
        for row, tag in enumerate(tags):
            name_item = QTableWidgetItem(tag.name)
            name_item.setData(Qt.ItemDataRole.UserRole, tag.name)
            if tag.risk == "high":
                name_item.setForeground(QColor(DANGER))

            value_item = QTableWidgetItem(tag.value)
            if tag.risk == "high":
                value_item.setForeground(QColor(DANGER))

            risk_item = QTableWidgetItem(risk_label(tag.risk))
            if tag.risk == "high":
                risk_item.setForeground(QColor(DANGER))

            self.setItem(row, 0, name_item)
            self.setItem(row, 1, value_item)
            self.setItem(row, 2, risk_item)

        if not tags:
            self.setRowCount(1)
            empty = QTableWidgetItem("Metadata bulunamadı")
            empty.setForeground(QColor(SUCCESS))
            self.setItem(0, 0, empty)
            self.setSpan(0, 0, 1, 3)

    def clear_tags(self) -> None:
        self.clearSpans()
        self.setRowCount(0)

    def selected_tag_names(self) -> list[str]:
        names: list[str] = []
        for item in self.selectedItems():
            if item.column() != 0:
                continue
            name = item.data(Qt.ItemDataRole.UserRole)
            if name and name not in names:
                names.append(str(name))
        return names
