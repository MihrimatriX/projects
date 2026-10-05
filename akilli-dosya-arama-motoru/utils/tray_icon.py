from PySide6.QtCore import Qt
from PySide6.QtGui import QBrush, QColor, QIcon, QPainter, QPixmap, QRadialGradient


def _draw_app_icon(painter: QPainter, size: int) -> None:
    """design/tray.html — radial-gradient yeşil tepsi simgesi."""
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.setPen(Qt.PenStyle.NoPen)
    margin = max(2, size // 8)
    grad = QRadialGradient(size * 0.35, size * 0.35, size * 0.55)
    grad.setColorAt(0.0, QColor("#6ee7a0"))
    grad.setColorAt(0.6, QColor("#45b86a"))
    grad.setColorAt(1.0, QColor("#2d7a45"))
    painter.setBrush(QBrush(grad))
    painter.drawEllipse(margin, margin, size - margin * 2, size - margin * 2)


def create_tray_icon(size: int = 32) -> QIcon:
    px = QPixmap(size, size)
    px.fill(Qt.GlobalColor.transparent)
    painter = QPainter(px)
    _draw_app_icon(painter, size)
    painter.end()
    return QIcon(px)


def create_tray_header_icon(size: int = 24) -> QPixmap:
    px = QPixmap(size, size)
    px.fill(Qt.GlobalColor.transparent)
    painter = QPainter(px)
    _draw_app_icon(painter, size)
    painter.end()
    return px
