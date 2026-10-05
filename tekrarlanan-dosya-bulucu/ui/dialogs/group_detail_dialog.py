from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QHBoxLayout,
    QLabel,
    QPushButton,
    QScrollArea,
    QVBoxLayout,
    QWidget,
)

from utils.file_actions import open_with_default_app, reveal_in_file_manager
from utils.formatters import human_size
from utils.models import DuplicateGroup


class GroupDetailDialog(QDialog):
    def __init__(self, group: DuplicateGroup, parent=None) -> None:
        super().__init__(parent)
        self.group = group
        self.setWindowTitle(f"Grup — {group.hash_short}")
        self.resize(640, 420)
        layout = QVBoxLayout(self)
        layout.addWidget(
            QLabel(
                f"<b>{group.count}</b> dosya · {human_size(group.size)} · "
                f"İsraf: {human_size(group.wasted_bytes)}"
            )
        )
        if group.is_hardlink_group:
            layout.addWidget(QLabel("Sert bağlantı — silme önerilmez."))

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        host = QWidget()
        inner = QVBoxLayout(host)
        self._boxes: list[tuple[QCheckBox, str]] = []
        for item in group.files:
            row = QHBoxLayout()
            cb = QCheckBox()
            cb.setChecked(item.marked_for_delete and not item.is_keeper)
            cb.setEnabled(not item.is_keeper and not group.is_hardlink_group)
            cb.setAccessibleName(f"Silmek için işaretle: {item.path}")
            path_lbl = QLabel(item.path)
            path_lbl.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            if item.preview:
                path_lbl.setToolTip(item.preview)
            show_btn = QPushButton("Göster")
            show_btn.setAccessibleName(f"Explorer'da göster: {item.path}")
            show_btn.clicked.connect(lambda _c, p=item.path: reveal_in_file_manager(p))
            open_btn = QPushButton("Aç")
            open_btn.setAccessibleName(f"Aç: {item.path}")
            open_btn.clicked.connect(lambda _c, p=item.path: open_with_default_app(p))
            row.addWidget(cb)
            row.addWidget(path_lbl, stretch=1)
            row.addWidget(QLabel(human_size(item.size)))
            row.addWidget(show_btn)
            row.addWidget(open_btn)
            inner.addLayout(row)
            self._boxes.append((cb, item.path))
        scroll.setWidget(host)
        layout.addWidget(scroll)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Close)
        buttons.rejected.connect(self._close)
        layout.addWidget(buttons)

    def apply_marks(self) -> None:
        for cb, path in self._boxes:
            for item in self.group.files:
                if item.path == path and not item.is_keeper:
                    item.marked_for_delete = cb.isChecked()

    def _close(self) -> None:
        self.apply_marks()
        self.accept()

    def reject(self) -> None:
        # Esc / pencere ✕ de işaret değişikliklerini uygulasın (eskiden sessizce kayboluyordu).
        self._close()
