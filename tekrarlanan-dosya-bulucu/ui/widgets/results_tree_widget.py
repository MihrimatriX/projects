from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QColor
from PySide6.QtWidgets import QApplication, QMenu, QTreeWidget, QTreeWidgetItem

from ui.dialogs.group_detail_dialog import GroupDetailDialog
from ui.theme import TEXT_MUTED
from utils.file_actions import open_with_default_app, reveal_in_file_manager
from utils.formatters import human_size
from utils.models import DuplicateGroup


class ResultsTreeWidget(QTreeWidget):
    selection_changed = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setHeaderLabels(["Dosya / grup", "Boyut"])
        self.setColumnWidth(0, 520)
        self.setAlternatingRowColors(True)
        self.itemChanged.connect(self._on_item_changed)
        self.itemDoubleClicked.connect(self._on_double_click)
        self.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.customContextMenuRequested.connect(self._context_menu)
        self._groups: list[DuplicateGroup] = []

    def load_groups(self, groups: list[DuplicateGroup], *, limit: int | None = None) -> int:
        self._groups = groups
        self.blockSignals(True)
        self.clear()
        shown = groups[:limit] if limit else groups
        for group in shown:
            title = f"SHA-256 {group.hash_short} · {group.count} kopya"
            if group.is_hardlink_group:
                title += " · sert bağlantı"
            if group.hash_hex.startswith("phash-"):
                title = f"pHash {group.hash_short} · {group.count} görsel"
            top = QTreeWidgetItem([title, human_size(group.size)])
            top.setFlags(Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable)
            top.setData(0, Qt.ItemDataRole.UserRole, ("group", id(group)))
            if group.is_hardlink_group:
                top.setForeground(0, QColor(TEXT_MUTED))
            self.addTopLevelItem(top)
            for item in group.files:
                label = item.path
                if item.is_keeper:
                    label += " · tut"
                child = QTreeWidgetItem([label, human_size(item.size)])
                flags = Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsSelectable
                if not item.is_keeper and not group.is_hardlink_group:
                    flags |= Qt.ItemFlag.ItemIsUserCheckable
                    state = (
                        Qt.CheckState.Checked
                        if item.marked_for_delete
                        else Qt.CheckState.Unchecked
                    )
                    child.setCheckState(0, state)
                # Bayraklar uygulanmıyordu: asıl/sert bağlantı satırları da varsayılan olarak işaretlenebilir kalıyordu.
                child.setFlags(flags)
                child.setData(0, Qt.ItemDataRole.UserRole, ("file", item.path))
                if item.preview:
                    child.setToolTip(0, f"{item.path}\n\n{item.preview}")
                top.addChild(child)
            top.setExpanded(len(shown) <= 40)
        self.blockSignals(False)
        return max(0, len(groups) - len(shown))

    def _group_for_item(self, item: QTreeWidgetItem) -> DuplicateGroup | None:
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if not data or data[0] != "group":
            return None
        gid = data[1]
        for group in self._groups:
            if id(group) == gid:
                return group
        return None

    def _on_double_click(self, item: QTreeWidgetItem, _column: int) -> None:
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if not data:
            return
        if data[0] == "file":
            open_with_default_app(data[1])
            return
        group = self._group_for_item(item)
        if group:
            dlg = GroupDetailDialog(group, self)
            if dlg.exec():
                self.selection_changed.emit()

    def _context_menu(self, pos) -> None:
        item = self.itemAt(pos)
        if not item:
            return
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if not data:
            return
        menu = QMenu(self)
        if data[0] == "file":
            path = data[1]
            menu.addAction("Explorer'da göster", lambda: reveal_in_file_manager(path))
            menu.addAction("Dosyayı aç", lambda: open_with_default_app(path))
            menu.addAction("Yolu kopyala", lambda: QApplication.clipboard().setText(path))
        else:
            group = self._group_for_item(item)
            if group:
                menu.addAction("Grup detayı", lambda: self._open_group(group))
        menu.exec(self.mapToGlobal(pos))

    def _open_group(self, group: DuplicateGroup) -> None:
        dlg = GroupDetailDialog(group, self)
        if dlg.exec():
            self.selection_changed.emit()

    def _on_item_changed(self, item: QTreeWidgetItem, column: int) -> None:
        if column != 0:
            return
        data = item.data(0, Qt.ItemDataRole.UserRole)
        if not data or data[0] != "file":
            return
        path = data[1]
        for group in self._groups:
            for f in group.files:
                if f.path == path and not f.is_keeper:
                    f.marked_for_delete = item.checkState(0) == Qt.CheckState.Checked
        self.selection_changed.emit()
