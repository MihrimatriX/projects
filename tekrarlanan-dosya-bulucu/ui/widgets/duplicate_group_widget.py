from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QApplication,
    QCheckBox,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMenu,
    QVBoxLayout,
    QWidget,
)

from utils.file_actions import reveal_in_explorer
from utils.formatters import human_size
from utils.models import DuplicateGroup


class DuplicateGroupWidget(QFrame):
    selection_changed = Signal()

    def __init__(self, group: DuplicateGroup, *, expanded: bool = False, parent=None) -> None:
        super().__init__(parent)
        self.group = group
        self._expanded = expanded
        self.setObjectName("GroupCard")
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        head = QFrame()
        head.setObjectName("GroupHead")
        head.setCursor(Qt.CursorShape.PointingHandCursor)
        head_layout = QHBoxLayout(head)
        head_layout.setContentsMargins(16, 10, 16, 10)

        self._chevron = QLabel("▼" if expanded else "▶")
        self._chevron.setObjectName("Chevron")
        head_layout.addWidget(self._chevron)

        hash_lbl = QLabel(group.hash_hex[:8])
        hash_lbl.setObjectName("MonoLabel")
        head_layout.addWidget(hash_lbl)

        meta = QLabel(f"· {group.count} dosya")
        meta.setObjectName("MutedLabel")
        head_layout.addWidget(meta)

        if group.hash_hex.startswith("phash-"):
            badge = QLabel("Benzer görsel")
            badge.setObjectName("BadgeWarning")
            head_layout.addWidget(badge)
        elif group.is_hardlink_group:
            badge = QLabel("Sert bağlantı")
            badge.setObjectName("BadgeWarning")
            head_layout.addWidget(badge)

        head_layout.addStretch()
        size_lbl = QLabel(human_size(group.size))
        size_lbl.setObjectName("MonoLabel")
        head_layout.addWidget(size_lbl)

        head.mousePressEvent = lambda _e: self._toggle()  # type: ignore[method-assign]
        # Klavye: Tab ile başlığa gel, Space/Enter ile aç-kapa
        head.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        head.setAccessibleName(f"Grup {group.hash_hex[:8]}, {group.count} dosya, {human_size(group.size)}")
        head.keyPressEvent = self._head_key  # type: ignore[method-assign]
        self._head = head
        layout.addWidget(head)

        self._body = QWidget()
        body_layout = QVBoxLayout(self._body)
        body_layout.setContentsMargins(0, 0, 0, 0)
        body_layout.setSpacing(0)
        self._body.setVisible(expanded)

        self._checkboxes: list[QCheckBox] = []
        self._tags: list[QLabel] = []
        for item in group.files:
            row = QFrame()
            row.setObjectName("FileRowKeep" if item.is_keeper else "FileRowMarked")
            row_layout = QHBoxLayout(row)
            row_layout.setContentsMargins(16, 10, 16, 10)

            cb = QCheckBox()
            cb.setChecked(item.marked_for_delete and not item.is_keeper)
            cb.setEnabled(not item.is_keeper and not group.is_hardlink_group)
            cb.setAccessibleName(f"Silmek için işaretle: {item.path}")
            cb.stateChanged.connect(self._on_check)
            row_layout.addWidget(cb)

            path_lbl = QLabel(item.path)
            path_lbl.setObjectName("MonoLabel")
            tip = item.path
            if item.preview:
                tip += f"\n\nÖnizleme: {item.preview}"
            path_lbl.setToolTip(tip)
            path_lbl.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            path_lbl.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
            path_lbl.customContextMenuRequested.connect(
                lambda _pos, p=item.path, lbl=path_lbl: self._path_menu(p, lbl)
            )
            row_layout.addWidget(path_lbl, stretch=1)

            tag = QLabel()
            tag.setObjectName("TagKeep" if item.is_keeper else "TagRecommended")
            row_layout.addWidget(tag)
            self._tags.append(tag)

            size_text = QLabel(human_size(item.size))
            size_text.setObjectName("MonoLabel")
            row_layout.addWidget(size_text)
            body_layout.addWidget(row)
            self._checkboxes.append(cb)

        layout.addWidget(self._body)
        self._refresh_tags()

    def _refresh_tags(self) -> None:
        # Etiket onay kutusuyla senkron kalsın (eskiden işaret kaldırılınca "Seçili" yazmaya devam ediyordu).
        for item, tag in zip(self.group.files, self._tags, strict=True):
            tag.setText("Asıl" if item.is_keeper else ("Silinecek" if item.marked_for_delete else "Kopya"))

    def _head_key(self, event) -> None:
        if event.key() in (Qt.Key.Key_Space, Qt.Key.Key_Return, Qt.Key.Key_Enter):
            self._toggle()
        else:
            QFrame.keyPressEvent(self._head, event)

    def _toggle(self) -> None:
        self._expanded = not self._expanded
        self._body.setVisible(self._expanded)
        self._chevron.setText("▼" if self._expanded else "▶")

    def _path_menu(self, path: str, label: QLabel) -> None:
        menu = QMenu(self)
        menu.addAction("Explorer'da göster", lambda: reveal_in_explorer(path))
        menu.addAction("Yolu kopyala", lambda: QApplication.clipboard().setText(path))
        menu.exec(label.mapToGlobal(label.rect().bottomLeft()))

    def _on_check(self) -> None:
        for item, cb in zip(self.group.files, self._checkboxes, strict=True):
            if not item.is_keeper:
                item.marked_for_delete = cb.isChecked()
        self._refresh_tags()
        self.selection_changed.emit()

    def sync_checkboxes(self) -> None:
        for item, cb in zip(self.group.files, self._checkboxes, strict=True):
            if not item.is_keeper:
                cb.setChecked(item.marked_for_delete)
