from __future__ import annotations

from PySide6.QtCore import QAbstractListModel, QModelIndex, Qt, Signal
from PySide6.QtWidgets import QListView

from utils.formatters import human_size
from utils.models import DuplicateGroup


class GroupsListModel(QAbstractListModel):
    def __init__(self, groups: list[DuplicateGroup] | None = None) -> None:
        super().__init__()
        self._groups = groups or []

    def set_groups(self, groups: list[DuplicateGroup]) -> None:
        self.beginResetModel()
        self._groups = groups
        self.endResetModel()

    def group_at(self, row: int) -> DuplicateGroup | None:
        if 0 <= row < len(self._groups):
            return self._groups[row]
        return None

    def rowCount(self, parent: QModelIndex = QModelIndex()) -> int:  # noqa: N802
        if parent.isValid():
            return 0
        return len(self._groups)

    def data(self, index: QModelIndex, role: int = Qt.ItemDataRole.DisplayRole):  # noqa: N802
        if not index.isValid():
            return None
        group = self._groups[index.row()]
        if role == Qt.ItemDataRole.DisplayRole:
            if group.is_hardlink_group:
                extra = "sert bağlantı"
            elif group.hash_hex.startswith("phash-"):
                extra = f"pHash · {human_size(group.wasted_bytes)}"
            else:
                extra = human_size(group.wasted_bytes)
            return f"{group.hash_short} · {group.count} dosya · {extra}"
        if role == Qt.ItemDataRole.UserRole:
            return index.row()
        return None


class GroupsListView(QListView):
    """10k+ grup için sanal liste (QAbstractListModel)."""

    group_activated = Signal(int)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._model = GroupsListModel()
        self.setModel(self._model)
        self.setAccessibleName("Mükerrer gruplar")
        # activated: çift tık + klavyede Enter (doubleClicked yalnız fareydi)
        self.activated.connect(self._on_double_click)

    def load_groups(self, groups: list[DuplicateGroup]) -> None:
        self._model.set_groups(groups)

    def _on_double_click(self, index: QModelIndex) -> None:
        row = index.row()
        if row >= 0:
            self.group_activated.emit(row)
