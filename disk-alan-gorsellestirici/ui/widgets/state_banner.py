from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import QFrame, QHBoxLayout, QLabel, QPushButton, QVBoxLayout, QWidget

from ui.theme import DANGER, SUCCESS, TEXT_SECONDARY, WARNING


class StateBanner(QFrame):
    action_clicked = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._kind = "info"
        self._title = QLabel()
        self._title.setObjectName("BannerTitle")
        self._detail = QLabel()
        self._detail.setStyleSheet(f"color: {TEXT_SECONDARY}; font-size: 12px;")
        self._action = QPushButton()
        self._action.setObjectName("GhostButton")
        self._action.hide()
        self._action.clicked.connect(self.action_clicked.emit)

        row = QHBoxLayout(self)
        row.setContentsMargins(16, 8, 16, 8)
        text_col = QVBoxLayout()
        text_col.setSpacing(2)
        text_col.addWidget(self._title)
        text_col.addWidget(self._detail)
        row.addLayout(text_col, stretch=1)
        row.addWidget(self._action)
        self.hide()

    def show_message(
        self,
        kind: str,
        title: str,
        detail: str = "",
        *,
        action_text: str | None = None,
    ) -> None:
        self._kind = kind
        self.setObjectName(
            {
                "success": "StateBannerSuccess",
                "warning": "StateBannerWarning",
                "danger": "StateBannerDanger",
            }.get(kind, "StateBanner")
        )
        self.setStyle(self.style())
        color = { "warning": WARNING, "danger": DANGER, "success": SUCCESS }.get(kind)
        if color:
            self._title.setStyleSheet(
                f"font-size: 11px; font-weight: 600; letter-spacing: 0.06em; "
                f"text-transform: uppercase; color: {color};"
            )
        else:
            self._title.setObjectName("BannerTitle")
            self._title.setStyleSheet("")
        self._title.setText(title)
        self._detail.setText(detail)
        self._detail.setVisible(bool(detail))
        if action_text:
            self._action.setText(action_text)
            self._action.show()
        else:
            self._action.hide()
        self.show()

    def hide_banner(self) -> None:
        self.hide()
