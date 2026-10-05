"""Grafikler için klavye erişimi: ←/→ (↑/↓) segment seç, Enter içine gir, Delete çöpe taşı,
Menü tuşu / Shift+F10 sağ tık menüsü. Klavye seçimi fare üzerine gelmeyle aynı vurguyu kullanır."""
from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QColor, QPainter, QPen

from ui.theme import ACCENT

_NEXT = (Qt.Key.Key_Right, Qt.Key.Key_Down)
_PREV = (Qt.Key.Key_Left, Qt.Key.Key_Up)


class SegmentKeysMixin:
    # Alt sınıf sağlar: _hover, _kb_items(), _kb_center(item), segment_* sinyalleri.

    def _kb_select(self, item) -> None:
        self._hover = item
        self.setAccessibleDescription(item.node.name)
        self.segment_hovered.emit(item.node)
        self.update()

    def selected_node(self):
        return self._hover.node if self._hover in self._kb_items() else None

    def keyPressEvent(self, event) -> None:  # noqa: N802
        items = self._kb_items()
        key = event.key()
        cur = items.index(self._hover) if self._hover in items else -1
        node = items[cur].node if cur >= 0 else None
        shift = bool(event.modifiers() & Qt.KeyboardModifier.ShiftModifier)
        if key in _NEXT and items:
            self._kb_select(items[(cur + 1) % len(items)])
        elif key in _PREV and items:
            self._kb_select(items[cur - 1] if cur > 0 else items[-1])
        elif key in (Qt.Key.Key_Return, Qt.Key.Key_Enter) and node and node.is_dir:
            self.segment_clicked.emit(node)
        elif key == Qt.Key.Key_Delete and node:
            self.segment_delete.emit(node)
        elif node and (key == Qt.Key.Key_Menu or (key == Qt.Key.Key_F10 and shift)):
            self.segment_context.emit(node, self.mapToGlobal(self._kb_center(items[cur]).toPoint()))
        else:
            super().keyPressEvent(event)
            return
        event.accept()

    def _paint_focus(self, painter: QPainter) -> None:
        if self.hasFocus():
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.setPen(QPen(QColor(ACCENT), 1, Qt.PenStyle.DashLine))
            painter.drawRect(self.rect().adjusted(0, 0, -1, -1))

    def focusInEvent(self, event) -> None:  # noqa: N802
        self.update()
        super().focusInEvent(event)

    def focusOutEvent(self, event) -> None:  # noqa: N802
        self.update()
        super().focusOutEvent(event)
