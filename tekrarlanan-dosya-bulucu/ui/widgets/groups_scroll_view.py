from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import QFrame, QLabel, QScrollArea, QVBoxLayout, QWidget

from ui.widgets.duplicate_group_widget import DuplicateGroupWidget
from utils.formatters import human_size
from utils.models import DuplicateGroup


class GroupsScrollView(QScrollArea):
    selection_changed = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWidgetResizable(True)
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        self._container = QWidget()
        self._layout = QVBoxLayout(self._container)
        self._layout.setContentsMargins(16, 0, 16, 16)
        self._layout.setSpacing(12)
        self._layout.addStretch()
        self.setWidget(self._container)

        self._header = QLabel()
        self._header.setObjectName("SectionHeader")
        self._groups: list[DuplicateGroup] = []

    def load_groups(self, groups: list[DuplicateGroup], *, limit: int | None = None) -> int:
        self._groups = groups
        while self._layout.count() > 1:
            item = self._layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        shown = groups[:limit] if limit else groups
        for i, group in enumerate(shown):
            widget = DuplicateGroupWidget(group, expanded=i == 0 and len(shown) <= 8)
            widget.selection_changed.connect(self.selection_changed.emit)
            self._layout.insertWidget(self._layout.count() - 1, widget)

        total_wasted = sum(g.wasted_bytes for g in groups)
        self._header.setText(f"Mükerrer gruplar · {len(groups)} grup · {human_size(total_wasted)}")
        return max(0, len(groups) - len(shown))

    def section_header(self) -> QLabel:
        return self._header
