from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QDialog,
    QDialogButtonBox,
    QHBoxLayout,
    QLabel,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from ui.widgets.metadata_table import MetadataTable
from ui.theme import DANGER, TEXT_MUTED, WARNING
from utils.models import MetadataTag, StripResult


class DiffDialog(QDialog):
    def __init__(self, result: StripResult, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Metadata karşılaştırma")
        self.resize(960, 520)

        layout = QVBoxLayout(self)
        title = QLabel(f"Önce / sonra — {result.source.name}")
        title.setObjectName("PanelTitle")
        layout.addWidget(title)

        removed = _removed_tags(result.before_tags, result.after_tags)
        kept = list(result.after_tags)

        row = QHBoxLayout()
        row.addWidget(_table_panel("Silinen tag'ler", removed, highlight_removed=True))
        row.addWidget(_table_panel("Kalan tag'ler", kept, highlight_removed=False))
        layout.addLayout(row)

        if result.hash_changed:
            warn = QLabel("⚠ Piksel verisi değişti — dosya yeniden kodlanmış olabilir (özellikle JPEG).")
            warn.setStyleSheet(f"color: {WARNING};")
            layout.addWidget(warn)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)


def _removed_tags(before: tuple[MetadataTag, ...], after: tuple[MetadataTag, ...]) -> list[MetadataTag]:
    after_names = {t.name for t in after}
    return [tag for tag in before if tag.name not in after_names]


def _table_panel(title: str, tags: list[MetadataTag], *, highlight_removed: bool) -> QWidget:
    panel = QWidget()
    box = QVBoxLayout(panel)
    label = QLabel(title)
    label.setObjectName("PanelTitle")
    box.addWidget(label)

    table = MetadataTable()
    if tags:
        table.set_tags(tags)
        if highlight_removed:
            for row in range(table.rowCount()):
                for col in range(table.columnCount()):
                    item = table.item(row, col)
                    if item:
                        item.setForeground(QColor(DANGER))
    else:
        table.setRowCount(1)
        empty = QTableWidgetItem("Kayıt yok")
        empty.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
        empty.setForeground(QColor(TEXT_MUTED))
        table.setItem(0, 0, empty)
        table.setSpan(0, 0, 1, 3)

    box.addWidget(table)
    return panel
