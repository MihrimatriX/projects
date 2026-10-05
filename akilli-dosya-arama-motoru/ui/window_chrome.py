"""Windows 11 pencere çerçevesi — design/css/shared.css (.win-shell)."""

from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtGui import QMouseEvent
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QToolButton, QWidget

from ui import theme as T
from ui.icons import search_icon


class WinTitleBar(QFrame):
    """Sürüklenebilir özel başlık çubuğu; yalnızca kapat düğmesi (diyalog)."""

    def __init__(
        self,
        title: str,
        window: QWidget,
        *,
        on_close=None,
        show_controls: bool = True,
        parent=None,
    ) -> None:
        super().__init__(parent)
        self._window = window
        self._on_close = on_close
        self._drag_offset = None
        self.setFixedHeight(32)
        self.setObjectName("WinTitleBar")
        self.setStyleSheet(
            f"QFrame#WinTitleBar {{ background: {T.WIN_TITLEBAR}; "
            f"border-bottom: 1px solid {T.WIN_BORDER}; }}"
        )

        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)

        icon_box = QLabel()
        icon_box.setFixedSize(32, 32)
        icon_box.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_box.setPixmap(search_icon(14, T.ACCENT))
        icon_box.setStyleSheet("background: transparent;")

        title_lbl = QLabel(title)
        title_lbl.setStyleSheet(
            f"color: {T.TEXT_SECONDARY}; font-size: 12px; padding-left: 2px; "
            f"background: transparent;"
        )

        lay.addWidget(icon_box)
        lay.addWidget(title_lbl, stretch=1)

        if show_controls:
            controls = QWidget()
            controls.setFixedHeight(32)
            controls.setStyleSheet("background: transparent;")
            ctrl_lay = QHBoxLayout(controls)
            ctrl_lay.setContentsMargins(0, 0, 0, 0)
            ctrl_lay.setSpacing(0)

            close_btn = QToolButton()
            close_btn.setText("✕")
            close_btn.setAccessibleName("Kapat")
            close_btn.setToolTip("Kapat (Esc)")
            close_btn.setFixedSize(46, 32)
            close_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            close_btn.setStyleSheet(
                f"QToolButton {{ background: transparent; border: none; color: {T.TEXT_MUTED}; "
                f"font-size: 10px; }}"
                f"QToolButton:hover {{ background: #c42b1c; color: #ffffff; }}"
            )
            close_btn.clicked.connect(self._close_window)
            ctrl_lay.addWidget(close_btn)
            lay.addWidget(controls)

    def _close_window(self) -> None:
        if self._on_close is not None:
            self._on_close()
        else:
            self._window.close()

    def mousePressEvent(self, event: QMouseEvent) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag_offset = (
                event.globalPosition().toPoint() - self._window.frameGeometry().topLeft()
            )
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        if self._drag_offset is not None and event.buttons() & Qt.MouseButton.LeftButton:
            self._window.move(event.globalPosition().toPoint() - self._drag_offset)
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:
        self._drag_offset = None
        super().mouseReleaseEvent(event)
