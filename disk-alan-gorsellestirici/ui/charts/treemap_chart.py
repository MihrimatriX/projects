from __future__ import annotations

from dataclasses import dataclass

from PySide6.QtCore import QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QBrush, QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import QWidget

from core.categorizer import color_for
from core.formatters import human_size
from core.models import ScanNode
from ui.charts.keyboard import SegmentKeysMixin
from ui.theme import BG_APP, TEXT_PRIMARY, TEXT_SECONDARY


@dataclass
class _Rect:
    node: ScanNode
    x: float
    y: float
    w: float
    h: float


def _squarify(items: list[ScanNode], x: float, y: float, w: float, h: float) -> list[_Rect]:
    if not items:
        return []
    if len(items) == 1:
        return [_Rect(items[0], x, y, w, h)]

    total = sum(i.size for i in items)
    if total <= 0:
        return []

    results: list[_Rect] = []
    remaining = list(items)
    cx, cy, cw, ch = x, y, w, h
    horizontal = cw >= ch

    while remaining:
        row: list[ScanNode] = []
        row_sum = 0
        idx = 0
        while idx < len(remaining):
            trial = remaining[idx]
            trial_row = row + [trial]
            trial_sum = row_sum + trial.size
            if not row:
                row = trial_row
                row_sum = trial_sum
                idx += 1
                continue
            if _worst(row, row_sum, cw, ch, horizontal) <= _worst(trial_row, trial_sum, cw, ch, horizontal):
                row = trial_row
                row_sum = trial_sum
                idx += 1
            else:
                break

        if not row:
            row = [remaining[0]]
            row_sum = row[0].size
            idx = 1

        if horizontal:
            row_h = ch * row_sum / total if total else ch
            cur_x = cx
            for node in row:
                rw = cw * node.size / row_sum if row_sum else cw / len(row)
                results.append(_Rect(node, cur_x, cy, rw, row_h))
                cur_x += rw
            cy += row_h
            ch -= row_h
        else:
            row_w = cw * row_sum / total if total else cw
            cur_y = cy
            for node in row:
                rh = ch * node.size / row_sum if row_sum else ch / len(row)
                results.append(_Rect(node, cx, cur_y, row_w, rh))
                cur_y += rh
            cx += row_w
            cw -= row_w

        total -= row_sum
        remaining = remaining[idx:]
        horizontal = not horizontal

    return results


def _worst(row: list[ScanNode], row_sum: int, w: float, h: float, horizontal: bool) -> float:
    if not row or row_sum <= 0:
        return float("inf")
    side = min(w, h) if horizontal else min(w, h)
    max_ratio = max(r.size / row_sum for r in row)
    min_ratio = min(r.size / row_sum for r in row)
    if min_ratio <= 0:
        return float("inf")
    return max(side**2 * max_ratio, side**2 / min_ratio / len(row))


class TreemapChart(SegmentKeysMixin, QWidget):
    segment_hovered = Signal(object)
    segment_clicked = Signal(object)
    segment_context = Signal(object, object)
    segment_delete = Signal(object)

    def __init__(self) -> None:
        super().__init__()
        self.setMinimumSize(480, 480)
        self._focus: ScanNode | None = None
        self._rects: list[_Rect] = []
        self._hover: _Rect | None = None
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setAccessibleName("Treemap grafiği")

    def set_data(self, _root: ScanNode, focus: ScanNode | None = None) -> None:
        self._focus = focus
        self._hover = None
        self._rects.clear()
        if focus and focus.children:
            children = [c for c in focus.sorted_children() if c.size > 0][:40]
            pad = 8
            self._rects = _squarify(
                children,
                pad,
                pad,
                max(1, self.width() - pad * 2),
                max(1, self.height() - pad * 2),
            )
        self.update()

    def resizeEvent(self, event) -> None:  # noqa: N802
        if self._focus:
            self.set_data(self._focus, self._focus)
        super().resizeEvent(event)

    def paintEvent(self, _event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.fillRect(self.rect(), QColor(BG_APP))

        if not self._focus or not self._rects:
            painter.setPen(QColor(TEXT_SECONDARY))
            text = "Bu klasör boş" if self._focus else "Henüz tarama yok — F5 ile tarayın"
            painter.drawText(self.rect(), Qt.AlignmentFlag.AlignCenter, text)
            self._paint_focus(painter)
            return

        for i, rect in enumerate(self._rects):
            is_hover = rect is self._hover
            color = QColor(color_for(rect.node.category, rect.node.name, i))
            if is_hover:
                color = color.lighter(120)
            painter.setBrush(QBrush(color))
            painter.setPen(QPen(QColor(BG_APP), 2))
            painter.drawRoundedRect(QRectF(rect.x, rect.y, rect.w, rect.h), 4, 4)

            if rect.w > 60 and rect.h > 28:
                painter.setPen(QColor(TEXT_PRIMARY))
                font = QFont("Segoe UI", 9, QFont.Weight.DemiBold)
                painter.setFont(font)
                label = rect.node.name
                if len(label) > 18:
                    label = label[:16] + "…"
                painter.drawText(
                    QRectF(rect.x + 6, rect.y + 4, rect.w - 12, rect.h / 2),
                    Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop,
                    label,
                )
                font.setWeight(QFont.Weight.Normal)
                painter.setFont(font)
                painter.setPen(QColor(TEXT_PRIMARY))  # gri kutuda gri metin okunmuyordu
                painter.drawText(
                    QRectF(rect.x + 6, rect.y + 20, rect.w - 12, max(1.0, rect.h - 24)),
                    Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop,
                    human_size(rect.node.size),
                )

        self._paint_focus(painter)

    def _kb_items(self) -> list[_Rect]:
        return self._rects

    def _kb_center(self, rect: _Rect) -> QPointF:
        return QPointF(rect.x + rect.w / 2, rect.y + rect.h / 2)

    def _hit(self, pos: QPointF) -> _Rect | None:
        for rect in self._rects:
            if rect.x <= pos.x() <= rect.x + rect.w and rect.y <= pos.y() <= rect.y + rect.h:
                return rect
        return None

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        rect = self._hit(event.position())
        if rect is not self._hover:
            self._hover = rect
            self.update()
            if rect:
                self.segment_hovered.emit(rect.node)
        super().mouseMoveEvent(event)

    def leaveEvent(self, _event) -> None:  # noqa: N802
        self._hover = None
        self.update()

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            rect = self._hit(event.position())
            if rect and rect.node.is_dir:
                self.segment_clicked.emit(rect.node)
        super().mousePressEvent(event)

    def contextMenuEvent(self, event) -> None:  # noqa: N802
        rect = self._hit(QPointF(event.pos()))
        if rect:
            self.segment_context.emit(rect.node, event.globalPos())
        else:
            super().contextMenuEvent(event)

    def render_to_pixmap(self):
        from PySide6.QtGui import QPixmap

        pix = QPixmap(self.size())
        self.render(pix)
        return pix
