from __future__ import annotations

import math
from dataclasses import dataclass

from PySide6.QtCore import QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QBrush, QColor, QFont, QPainter, QPen
from PySide6.QtWidgets import QWidget

from core.categorizer import color_for
from core.formatters import human_size
from core.models import ScanNode
from ui.charts.keyboard import SegmentKeysMixin
from ui.theme import BG_APP, BG_PANEL, BORDER, TEXT_PRIMARY, TEXT_SECONDARY


@dataclass
class _Segment:
    node: ScanNode
    start_angle: float
    span_angle: float
    inner_radius: float
    outer_radius: float


class SunburstChart(SegmentKeysMixin, QWidget):
    segment_hovered = Signal(object)
    segment_clicked = Signal(object)
    segment_context = Signal(object, object)
    segment_delete = Signal(object)

    def __init__(self) -> None:
        super().__init__()
        self.setMinimumSize(480, 480)
        self._root: ScanNode | None = None
        self._focus: ScanNode | None = None
        self._segments: list[_Segment] = []
        self._hover: _Segment | None = None
        self.setMouseTracking(True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setAccessibleName("Sunburst grafiği")

    def set_data(self, root: ScanNode, focus: ScanNode | None = None) -> None:
        self._root = root
        self._focus = focus or root
        self._hover = None
        self._rebuild_segments()
        self.update()

    def _rebuild_segments(self) -> None:
        self._segments.clear()
        if not self._focus or not self._focus.children:
            return

        children = [c for c in self._focus.sorted_children() if c.size > 0]
        if not children:
            return

        total = sum(c.size for c in children)
        start = 90.0  # 12 o'clock
        for child in children:
            span = (child.size / total) * 360.0
            if span < 0.5:
                continue
            self._segments.append(
                _Segment(child, start, span, 0.38, 0.98)
            )
            start += span

    def paintEvent(self, _event) -> None:  # noqa: N802
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        rect = self.rect()
        size = min(rect.width(), rect.height()) - 32
        cx = rect.center().x()
        cy = rect.center().y()
        max_r = size / 2

        painter.fillRect(rect, QColor(BG_APP))

        if not self._focus:
            painter.setPen(QColor(TEXT_SECONDARY))
            painter.drawText(rect, Qt.AlignmentFlag.AlignCenter, "Henüz tarama yok — F5 ile tarayın")
            return

        # background ring
        painter.setPen(Qt.PenStyle.NoPen)
        painter.setBrush(QColor(BG_PANEL))
        painter.drawEllipse(QPointF(cx, cy), max_r * 0.98, max_r * 0.98)

        for i, seg in enumerate(self._segments):
            is_hover = seg is self._hover
            color = QColor(color_for(seg.node.category, seg.node.name, i))
            if is_hover:
                color = color.lighter(115)
            painter.setBrush(QBrush(color))
            painter.setPen(QPen(QColor(BG_APP), 2))
            outer = max_r * seg.outer_radius
            painter.drawPie(
                QRectF(cx - outer, cy - outer, outer * 2, outer * 2),
                # start_angle = 90 + (saat 12'den saat yönünde başlangıç); Qt açısı
                # saat 3'ten saat yönü tersine ölçülür → 90 - (start_angle - 90).
                int((180.0 - seg.start_angle) * 16),
                int(-seg.span_angle * 16),
            )

        # Büyük dilimlere ad (fareyle üzerine gelmeden hangi klasör olduğu anlaşılsın)
        label_font = QFont("Segoe UI", 9, QFont.Weight.DemiBold)
        painter.setFont(label_font)
        metrics = painter.fontMetrics()
        for seg in self._segments:
            if seg.span_angle < 14:
                continue
            c = self._kb_center(seg)
            ring = max_r * (seg.outer_radius - seg.inner_radius)
            text = metrics.elidedText(seg.node.name, Qt.TextElideMode.ElideRight, int(ring * 0.95))
            box = QRectF(c.x() - ring / 2, c.y() - 9, ring, 18)
            painter.setPen(QColor(0, 0, 0, 150))
            painter.drawText(box.translated(1, 1), Qt.AlignmentFlag.AlignCenter, text)
            painter.setPen(QColor(TEXT_PRIMARY))
            painter.drawText(box, Qt.AlignmentFlag.AlignCenter, text)

        # center hole + label
        inner_r = max_r * 0.36
        painter.setBrush(QBrush(QColor(BG_APP)))
        painter.setPen(QPen(QColor(BORDER), 1))
        painter.drawEllipse(QPointF(cx, cy), inner_r, inner_r)

        painter.setPen(QColor(TEXT_PRIMARY))
        font = QFont("Segoe UI", 11, QFont.Weight.DemiBold)
        painter.setFont(font)
        name = self._focus.name
        if len(name) > 14:
            name = name[:12] + "…"
        painter.drawText(
            QRectF(cx - inner_r, cy - inner_r + 8, inner_r * 2, inner_r),
            Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop,
            name,
        )
        font.setPointSize(16)
        font.setWeight(QFont.Weight.Bold)
        painter.setFont(font)
        painter.drawText(
            QRectF(cx - inner_r, cy - 12, inner_r * 2, 28),
            Qt.AlignmentFlag.AlignCenter,
            human_size(self._focus.size),
        )
        if not self._segments:
            painter.setPen(QColor(TEXT_SECONDARY))
            painter.drawText(
                QRectF(0, cy + max_r * 0.5, rect.width(), 24), Qt.AlignmentFlag.AlignHCenter, "Bu klasör boş"
            )
        self._paint_focus(painter)

    def _kb_items(self) -> list[_Segment]:
        return self._segments

    def _kb_center(self, seg: _Segment) -> QPointF:
        rect = self.rect()
        max_r = (min(rect.width(), rect.height()) - 32) / 2
        mid = math.radians(seg.start_angle + seg.span_angle / 2 - 90)  # saat 12'den saat yönünde
        r = max_r * (seg.inner_radius + seg.outer_radius) / 2
        return QPointF(rect.center().x() + r * math.sin(mid), rect.center().y() - r * math.cos(mid))

    def _hit_test(self, pos: QPointF) -> _Segment | None:
        rect = self.rect()
        size = min(rect.width(), rect.height()) - 32
        cx, cy = rect.center().x(), rect.center().y()
        max_r = size / 2
        dx, dy = pos.x() - cx, pos.y() - cy
        dist = math.hypot(dx, dy)
        if dist < max_r * 0.36 or dist > max_r * 0.98:
            return None
        angle = math.degrees(math.atan2(dx, -dy))
        if angle < 0:
            angle += 360
        # atan2 açısı saat 12'den saat yönünde (0..360); start_angle ise 90'dan
        # başlayan aynı ölçek. Karşılaştırma için +90 ile hizala.
        angle += 90
        for seg in self._segments:
            end = seg.start_angle + seg.span_angle
            if seg.start_angle <= angle <= end:
                return seg
            if end > 360 and angle <= end - 360:
                return seg
        return None

    def mouseMoveEvent(self, event) -> None:  # noqa: N802
        seg = self._hit_test(event.position())
        if seg is not self._hover:
            self._hover = seg
            self.update()
            if seg:
                self.segment_hovered.emit(seg.node)
        super().mouseMoveEvent(event)

    def leaveEvent(self, _event) -> None:  # noqa: N802
        self._hover = None
        self.update()

    def mousePressEvent(self, event) -> None:  # noqa: N802
        if event.button() == Qt.MouseButton.LeftButton:
            seg = self._hit_test(event.position())
            if seg and seg.node.is_dir:
                self.segment_clicked.emit(seg.node)
        super().mousePressEvent(event)

    def contextMenuEvent(self, event) -> None:  # noqa: N802
        seg = self._hit_test(QPointF(event.pos()))
        if seg:
            self.segment_context.emit(seg.node, event.globalPos())
        else:
            super().contextMenuEvent(event)

    def render_to_pixmap(self):
        from PySide6.QtGui import QPixmap

        pix = QPixmap(self.size())
        self.render(pix)
        return pix
