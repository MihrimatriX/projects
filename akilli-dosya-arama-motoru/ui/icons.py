"""SVG ikon yardımcıları — design/spotlight.html ile uyumlu."""

from __future__ import annotations

from PySide6.QtCore import QByteArray, Qt
from PySide6.QtGui import QColor, QPainter, QPixmap
from PySide6.QtSvg import QSvgRenderer

from ui import theme as T

_SETTINGS_SVG = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="{color}" stroke-width="1.6">'
    '<circle cx="12" cy="12" r="3"/>'
    '<path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42'
    'M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/>'
    "</svg>"
)

_SEARCH_SVG = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="{color}" stroke-width="1.8">'
    '<circle cx="11" cy="11" r="7"/><path d="M20 20l-3-3"/>'
    "</svg>"
)

_FOLDER_SVG = (
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="{color}" stroke-width="1.75">'
    '<path d="M3 7a2 2 0 012-2h5l2 2h9a2 2 0 012 2v8a2 2 0 01-2 2H5a2 2 0 01-2-2V7z"/>'
    "</svg>"
)


def _render_svg(svg_template: str, size: int, color: str = T.TEXT_MUTED) -> QPixmap:
    svg = svg_template.format(color=color)
    renderer = QSvgRenderer(QByteArray(svg.encode("utf-8")))
    pix = QPixmap(size, size)
    pix.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pix)
    renderer.render(painter)
    painter.end()
    return pix


def settings_icon(size: int = 15, color: str = T.TEXT_MUTED) -> QPixmap:
    return _render_svg(_SETTINGS_SVG, size, color)


def search_icon(size: int = 18, color: str = T.TEXT_MUTED) -> QPixmap:
    return _render_svg(_SEARCH_SVG, size, color)


def folder_icon(size: int = 16, color: str = T.ACCENT) -> QPixmap:
    return _render_svg(_FOLDER_SVG, size, color)
