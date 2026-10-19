from __future__ import annotations

from PySide6.QtCore import QPoint, Qt, Signal
from PySide6.QtGui import QFont, QKeyEvent, QPixmap
from PySide6.QtWidgets import (
    QApplication,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QScrollArea,
    QToolButton,
    QVBoxLayout,
    QWidget,
)

from ui import theme as T
from ui.icons import search_icon, settings_icon
from utils.config import PREVIEW_SIZE

FILTER_CHIPS: list[tuple[str, str]] = [
    ("all", "Tümü"),
    ("docs", "Belgeler"),
    ("code", "Kod"),
    ("images", "Resimler"),
]

EMPTY_DETAILS: dict[str, str] = {
    "Aramak için yazmaya başlayın": "Ad, uzantı, klasör veya içerik parçası yazın.",
    "Sonuç bulunamadı": "Filtreyi genişletin veya dosya adını kısaltın.",
}


def _font_ui(size: int, weight: int = QFont.Weight.Normal) -> QFont:
    f = QFont("Segoe UI", size)
    f.setWeight(weight)
    return f


def _font_mono(size: int) -> QFont:
    return QFont("Cascadia Mono", size)


class SearchLineEdit(QLineEdit):
    """Arama kutusundayken palet kısayollarını yakalar."""

    palette_key = Signal(object)
    focus_changed = Signal(bool)

    def focusInEvent(self, event) -> None:
        super().focusInEvent(event)
        self.focus_changed.emit(True)

    def focusOutEvent(self, event) -> None:
        super().focusOutEvent(event)
        self.focus_changed.emit(False)

    def keyPressEvent(self, event: QKeyEvent) -> None:
        key = event.key()
        mods = event.modifiers() & ~Qt.KeyboardModifier.KeypadModifier

        if key in (Qt.Key.Key_Return, Qt.Key.Key_Enter, Qt.Key.Key_Down, Qt.Key.Key_Up, Qt.Key.Key_Escape):
            self.palette_key.emit(event)
            return
        if key == Qt.Key.Key_Comma and mods & Qt.KeyboardModifier.ControlModifier:
            self.palette_key.emit(event)
            return

        super().keyPressEvent(event)


class IndexBadge(QWidget):
    """İndeks durumu — yeşil/sarı/kırmızı nokta + mono metin."""

    retry_clicked = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._scanning = False
        self._error = False
        self._label = ""

        lay = QHBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(7)

        self._dot = QLabel("●")
        self._dot.setFixedWidth(10)
        self._dot.setFont(_font_ui(8))

        self._text = QLabel()
        self._text.setFont(_font_mono(11))

        self._retry = QPushButton("Yeniden dene")
        self._retry.setFlat(True)
        self._retry.setCursor(Qt.CursorShape.PointingHandCursor)
        self._retry.hide()
        self._retry.clicked.connect(self.retry_clicked.emit)

        lay.addWidget(self._dot)
        lay.addWidget(self._text)
        lay.addWidget(self._retry)
        self.set_state(label="Hazır", scanning=False)

    def set_state(self, *, label: str, scanning: bool = False, error: bool = False) -> None:
        self._label = label
        self._scanning = scanning
        self._error = error
        self._text.setText(label)
        self._retry.setVisible(error)

        if error:
            color = T.DANGER
        elif scanning:
            color = T.WARNING
        else:
            color = T.SUCCESS

        self._dot.setStyleSheet(f"color: {color}; background: transparent;")
        self._text.setStyleSheet(f"color: {T.TEXT_MUTED}; background: transparent;")
        self._retry.setStyleSheet(
            f"QPushButton {{ color: {T.ACCENT}; background: transparent; border: none; "
            f"font-family: {T.FONT_MONO}; font-size: 11px; padding: 0; }}"
            f"QPushButton:hover {{ color: {T.ACCENT_HOVER}; }}"
        )
        self.setStyleSheet("background: transparent;")


class FilterChipButton(QPushButton):
    def __init__(self, filter_id: str, label: str, parent=None) -> None:
        super().__init__(label, parent)
        self.filter_id = filter_id
        self.setCheckable(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFont(_font_ui(12, QFont.Weight.Medium))
        self._apply_style(active=False)

    def set_active(self, active: bool) -> None:
        self.setChecked(active)
        self._apply_style(active=active)

    def _apply_style(self, *, active: bool) -> None:
        if active:
            self.setStyleSheet(
                f"QPushButton {{ background: {T.BG_ELEVATED}; color: {T.TEXT_PRIMARY}; "
                f"border: none; border-radius: {T.RADIUS_SM}px; padding: 5px 12px; "
                f"font-weight: 500; }}"
            )
        else:
            self.setStyleSheet(
                f"QPushButton {{ background: transparent; color: {T.TEXT_MUTED}; "
                f"border: none; border-radius: {T.RADIUS_SM}px; padding: 5px 12px; }}"
                f"QPushButton:hover {{ color: {T.TEXT_PRIMARY}; }}"
                f"QPushButton:pressed {{ background: {T.BG_ELEVATED}; }}"
            )


class ResultRow(QFrame):
    activated = Signal(int)
    open_requested = Signal(int)
    menu_requested = Signal(int, QPoint)

    def __init__(self, index: int, parent=None) -> None:
        super().__init__(parent)
        self._index = index
        self._selected = False
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setObjectName("ResultRow")
        self.setMinimumHeight(T.ROW_HEIGHT)

        layout = QGridLayout(self)
        layout.setContentsMargins(16, 8, 16, 8)
        layout.setHorizontalSpacing(10)
        layout.setVerticalSpacing(2)

        self.preview_label = QLabel()
        self.preview_label.setFixedSize(28, 28)
        self.preview_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.preview_label.setStyleSheet(
            f"background: {T.BG_ELEVATED}; border: 1px solid {T.BORDER}; "
            f"border-radius: {T.RADIUS_SM}px;"
        )

        self.icon_label = QLabel()
        self.icon_label.setFixedSize(28, 28)
        self.icon_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.icon_label.setFont(_font_mono(10))
        self.icon_label.setStyleSheet(
            f"color: {T.TEXT_MUTED}; background: {T.BG_ELEVATED}; "
            f"border: 1px solid {T.BORDER}; border-radius: {T.RADIUS_SM}px;"
        )

        self.name_label = QLabel()
        self.name_label.setFont(_font_ui(14, QFont.Weight.Medium))
        self.name_label.setTextFormat(Qt.TextFormat.RichText)

        self.badge_label = QLabel()
        self.badge_label.setFont(_font_mono(10))
        self.badge_label.hide()

        name_row = QHBoxLayout()
        # Varsayılan 9-11 px kenar boşluğu satır yüksekliğini yiyip dosya adını kırpıyordu.
        name_row.setContentsMargins(0, 0, 0, 0)
        name_row.setSpacing(8)
        name_row.addWidget(self.name_label, stretch=1)
        name_row.addWidget(self.badge_label)
        name_wrap = QWidget()
        name_wrap.setLayout(name_row)
        name_wrap.setStyleSheet("background: transparent;")

        self.path_label = QLabel()
        self.path_label.setFont(_font_mono(11))
        self.path_label.setStyleSheet(f"color: {T.TEXT_MUTED}; background: transparent;")

        self.snippet_label = QLabel()
        self.snippet_label.setFont(_font_ui(12))
        self.snippet_label.setStyleSheet(
            f"color: {T.TEXT_MUTED}; font-style: italic; background: transparent;"
        )
        self.snippet_label.setWordWrap(True)
        self.snippet_label.hide()

        self.meta_label = QLabel()
        self.meta_label.setFont(_font_mono(11))
        self.meta_label.setAlignment(
            Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignTop
        )
        self.meta_label.setStyleSheet(f"color: {T.TEXT_MUTED}; background: transparent;")

        layout.addWidget(self.icon_label, 0, 0, 3, 1, Qt.AlignmentFlag.AlignTop)
        layout.addWidget(self.preview_label, 0, 0, 3, 1, Qt.AlignmentFlag.AlignTop)
        self.preview_label.hide()
        layout.addWidget(name_wrap, 0, 1)
        layout.addWidget(self.path_label, 1, 1)
        layout.addWidget(self.snippet_label, 2, 1)
        layout.addWidget(self.meta_label, 0, 2, 3, 1)

        self._refresh_style()

    @property
    def row_index(self) -> int:
        return self._index

    def set_content(
        self,
        *,
        name_html: str,
        path: str,
        snippet: str | None = None,
        ext_label: str = "?",
        thumbnail: QPixmap | None = None,
        match_badge: str | None = None,
        meta: str = "",
    ) -> None:
        if thumbnail and not thumbnail.isNull():
            self.preview_label.setPixmap(thumbnail.scaled(28, 28, Qt.AspectRatioMode.KeepAspectRatio))
            self.preview_label.show()
            self.icon_label.hide()
        else:
            self.preview_label.hide()
            self.icon_label.show()
            self.icon_label.setText(ext_label)

        self.name_label.setText(name_html)
        self.path_label.setText(path)
        self.meta_label.setText(meta)

        if match_badge:
            self.badge_label.setText(match_badge.upper())
            colors = {
                "içerik": (T.ACCENT, T.ACCENT_DIM),
                "bulanık": (T.WARNING, "rgba(212, 168, 67, 0.15)"),
                "EV": (T.ACCENT, "rgba(69, 184, 106, 0.22)"),
            }
            fg, bg = colors.get(match_badge, (T.TEXT_MUTED, T.BG_HOVER))
            self.badge_label.setStyleSheet(
                f"color: {fg}; background: {bg}; padding: 2px 6px; "
                f"border-radius: 10px;"
            )
            self.badge_label.show()
        else:
            self.badge_label.hide()

        if snippet:
            self.snippet_label.setText(snippet)
            self.snippet_label.show()
            layout = self.layout()
            if isinstance(layout, QGridLayout):
                layout.setContentsMargins(16, 10, 16, 10)
        else:
            self.snippet_label.hide()
            layout = self.layout()
            if isinstance(layout, QGridLayout):
                layout.setContentsMargins(16, 8, 16, 8)

    def set_selected(self, selected: bool) -> None:
        self._selected = selected
        self._refresh_style()

    def _refresh_style(self) -> None:
        if self._selected:
            border = f"border-left: 3px solid {T.ACCENT};"
            bg = T.BG_SELECTED
            name_color = T.TEXT_PRIMARY
        else:
            border = "border-left: 3px solid transparent;"
            bg = "transparent"
            name_color = T.TEXT_SECONDARY
        self.setStyleSheet(
            f"QFrame#ResultRow {{ background: {bg}; {border} }}"
            f"QFrame#ResultRow:hover {{ background: {T.BG_HOVER}; }}"
        )
        self.name_label.setStyleSheet(
            f"color: {name_color}; background: transparent;"
        )

    def mousePressEvent(self, event) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self.activated.emit(self._index)
        super().mousePressEvent(event)

    def contextMenuEvent(self, event) -> None:
        self.activated.emit(self._index)
        self.menu_requested.emit(self._index, event.globalPos())

    def mouseDoubleClickEvent(self, event) -> None:
        if event.button() == Qt.MouseButton.LeftButton:
            self.open_requested.emit(self._index)
        super().mouseDoubleClickEvent(event)


class SearchPanel(QFrame):
    """Merkez arama paleti — design/spotlight.html."""

    search_changed = Signal(str)
    filter_changed = Signal(str)
    settings_requested = Signal()

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("SearchPanel")
        self.setFixedWidth(T.PANEL_WIDTH)

        self._active_filter = "all"
        self._filter_buttons: dict[str, FilterChipButton] = {}
        self._search_focused = False
        self._is_searching = False
        self._search_row: QWidget | None = None

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Üst: indeks rozeti + ayarlar
        top = QWidget()
        top.setStyleSheet("background: transparent;")
        top_lay = QHBoxLayout(top)
        top_lay.setContentsMargins(16, 12, 16, 0)
        self.index_badge = IndexBadge()
        settings_btn = QToolButton()
        settings_btn.setIcon(settings_icon())
        settings_btn.setToolTip("İndeks ayarları (Ctrl+,)")
        settings_btn.setAccessibleName("İndeks ayarları")
        settings_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        settings_btn.setFixedSize(28, 28)
        settings_btn.clicked.connect(self.settings_requested.emit)
        top_lay.addWidget(self.index_badge)
        top_lay.addStretch()
        top_lay.addWidget(settings_btn)
        root.addWidget(top)

        # Arama satırı
        search_row = QWidget()
        self._search_row = search_row
        search_lay = QHBoxLayout(search_row)
        search_lay.setContentsMargins(16, 14, 16, 10)
        search_lay.setSpacing(10)

        search_icon_lbl = QLabel()
        search_icon_lbl.setPixmap(search_icon())
        search_icon_lbl.setFixedSize(18, 18)
        search_icon_lbl.setStyleSheet("background: transparent;")

        self.search_input = SearchLineEdit()
        self.search_input.setPlaceholderText("Dosya veya içerik ara…")
        self.search_input.setAccessibleName("Dosya veya içerik ara")
        self.search_input.setFont(_font_ui(16))
        self.search_input.textChanged.connect(self.search_changed.emit)
        self.search_input.focus_changed.connect(self._on_search_focus_changed)

        search_lay.addWidget(search_icon_lbl)
        search_lay.addWidget(self.search_input, stretch=1)
        root.addWidget(search_row)
        self._refresh_search_row_style()

        # Kök klasör özeti
        self.roots_label = QLabel()
        self.roots_label.setFont(_font_ui(11))
        self.roots_label.setStyleSheet(
            f"color: {T.TEXT_MUTED}; padding: 7px 16px; background: transparent; "
            f"border-bottom: 1px solid {T.BORDER};"
        )
        root.addWidget(self.roots_label)

        # Filtre sekmeleri (filter-tabs)
        chips_wrap = QFrame()
        chips_wrap.setStyleSheet(
            f"QFrame {{ background: transparent; border-bottom: 1px solid {T.BORDER}; }}"
        )
        chips_outer = QHBoxLayout(chips_wrap)
        chips_outer.setContentsMargins(16, 10, 16, 10)

        filter_tabs = QFrame()
        filter_tabs.setStyleSheet(
            f"QFrame {{ background: {T.BG_PANEL}; border: 1px solid {T.BORDER}; "
            f"border-radius: {T.RADIUS_MD}px; }}"
        )
        chips_lay = QHBoxLayout(filter_tabs)
        chips_lay.setContentsMargins(3, 3, 3, 3)
        chips_lay.setSpacing(4)
        for n, (fid, label) in enumerate(FILTER_CHIPS, start=1):
            btn = FilterChipButton(fid, label)
            btn.setToolTip(f"{label} (Ctrl+{n})")
            btn.clicked.connect(lambda _=False, f=fid: self._set_filter(f))
            self._filter_buttons[fid] = btn
            chips_lay.addWidget(btn)
        chips_outer.addWidget(filter_tabs)
        chips_outer.addStretch()
        self._filter_buttons["all"].set_active(True)
        root.addWidget(chips_wrap)

        # Sonuç listesi — ekranın ~58%'i, en az 360px
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        screen = QApplication.primaryScreen()
        if screen:
            avail_h = screen.availableGeometry().height()
            results_h = max(T.RESULTS_MIN_HEIGHT, min(int(avail_h * 0.58), 720))
        else:
            results_h = T.RESULTS_MAX_HEIGHT
        scroll.setMinimumHeight(T.RESULTS_MIN_HEIGHT)
        scroll.setMaximumHeight(results_h)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFocusPolicy(Qt.FocusPolicy.NoFocus)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        inner = QWidget()
        inner.setStyleSheet("background: transparent;")
        self._results_inner_layout = QVBoxLayout(inner)
        self._results_inner_layout.setContentsMargins(0, 0, 0, 0)
        self._results_inner_layout.setSpacing(0)
        scroll.setWidget(inner)
        self._results_scroll = scroll
        root.addWidget(scroll, stretch=1)

        self._empty_wrap = QWidget()
        empty_lay = QVBoxLayout(self._empty_wrap)
        empty_lay.setContentsMargins(16, 40, 16, 40)
        empty_lay.setSpacing(6)
        empty_lay.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._empty_title = QLabel("Aramak için yazmaya başlayın")
        self._empty_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._empty_title.setFont(_font_ui(13, QFont.Weight.Medium))
        self._empty_detail = QLabel(EMPTY_DETAILS["Aramak için yazmaya başlayın"])
        self._empty_detail.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self._empty_detail.setFont(_font_ui(12))
        self._empty_detail.setWordWrap(True)
        self._empty_detail.setMaximumWidth(280)
        empty_lay.addWidget(self._empty_title)
        empty_lay.addWidget(self._empty_detail)
        self._empty_wrap.setMinimumHeight(200)
        self._empty_wrap.setStyleSheet("background: transparent;")
        self._apply_empty_style(error=False)
        self._results_inner_layout.addWidget(self._empty_wrap)
        self._result_rows: list[ResultRow] = []

        # Footer — statusbar
        footer = QWidget()
        footer.setFixedHeight(28)
        footer.setStyleSheet(
            f"background: {T.BG_PANEL}; border-top: 1px solid {T.BORDER};"
        )
        footer_lay = QHBoxLayout(footer)
        footer_lay.setContentsMargins(16, 0, 16, 0)

        self.footer_hint = QLabel("↑↓ gezin · ↵ aç · Ctrl+↵ klasör · Ctrl+Shift+C yolu kopyala · Esc · Ctrl+, ayarlar")
        self.footer_hint.setFont(_font_mono(11))
        self.footer_hint.setStyleSheet(f"color: {T.TEXT_MUTED}; background: transparent;")

        self.timing_label = QLabel()
        self.timing_label.setFont(_font_mono(11))
        self.timing_label.setStyleSheet(f"color: {T.ACCENT}; background: transparent;")
        self.timing_label.hide()

        self.result_count_label = QLabel()
        self.result_count_label.setFont(_font_mono(11))
        self.result_count_label.setStyleSheet(f"color: {T.TEXT_MUTED}; background: transparent;")

        right = QHBoxLayout()
        right.setSpacing(10)
        right.addWidget(self.timing_label)
        right.addWidget(self.result_count_label)

        footer_lay.addWidget(self.footer_hint)
        footer_lay.addStretch()
        footer_lay.addLayout(right)
        root.addWidget(footer)

    def _on_search_focus_changed(self, focused: bool) -> None:
        self._search_focused = focused
        self._refresh_search_row_style()

    def _refresh_search_row_style(self) -> None:
        if not self._search_row:
            return
        if self._is_searching:
            accent = "rgba(69, 184, 106, 0.55)"
        elif self._search_focused:
            accent = "rgba(69, 184, 106, 0.7)"
        else:
            accent = T.BORDER
        self._search_row.setStyleSheet(
            f"border-bottom: 1px solid {accent}; background: transparent;"
        )

    def set_searching(self, searching: bool) -> None:
        self._is_searching = searching
        self._refresh_search_row_style()

    def _apply_empty_style(self, *, error: bool) -> None:
        if error:
            title_color = T.DANGER
            detail_color = T.TEXT_MUTED
        else:
            title_color = T.TEXT_SECONDARY
            detail_color = T.TEXT_MUTED
        self._empty_title.setStyleSheet(
            f"color: {title_color}; background: transparent;"
        )
        self._empty_detail.setStyleSheet(
            f"color: {detail_color}; background: transparent; line-height: 1.45;"
        )

    def _set_filter(self, filter_id: str) -> None:
        self._active_filter = filter_id
        for fid, btn in self._filter_buttons.items():
            btn.set_active(fid == filter_id)
        self.search_input.setFocus()
        self.filter_changed.emit(filter_id)

    @property
    def active_filter(self) -> str:
        return self._active_filter

    def set_roots_summary(self, text: str) -> None:
        self.roots_label.setText(text)

    def set_index_state(
        self, *, label: str, scanning: bool = False, error: bool = False
    ) -> None:
        self.index_badge.set_state(label=label, scanning=scanning, error=error)

    def set_footer_timing(self, ms: int | None) -> None:
        if ms is not None:
            self.timing_label.setText(f"{ms} ms")
            self.timing_label.show()
        else:
            self.timing_label.hide()

    def set_result_count(self, count: int | None) -> None:
        if count is None:
            self.result_count_label.setText("")
        else:
            self.result_count_label.setText(f"{count} sonuç")

    def set_scanning_footer(self, text: str | None) -> None:
        self.set_searching(bool(text))
        if text:
            self.result_count_label.setText(text)
            self.result_count_label.setStyleSheet(
                f"color: {T.TEXT_MUTED}; font-family: {T.FONT_MONO}; font-size: 11px; "
                f"font-style: italic; background: transparent;"
            )
        else:
            self.result_count_label.setStyleSheet(
                f"color: {T.TEXT_MUTED}; font-family: {T.FONT_MONO}; font-size: 11px; "
                f"background: transparent;"
            )

    def set_empty_message(
        self, title: str, detail: str | None = None, *, error: bool = False
    ) -> None:
        if detail is None:
            detail = EMPTY_DETAILS.get(title, "")
        self._empty_title.setText(title)
        self._empty_detail.setText(detail)
        self._empty_detail.setVisible(bool(detail))
        self._apply_empty_style(error=error)
        self._empty_wrap.show()

    def clear_results(self) -> None:
        for row in self._result_rows:
            self._results_inner_layout.removeWidget(row)
            row.deleteLater()
        self._result_rows.clear()
        self._empty_wrap.show()
        self.set_result_count(None)
        self.set_searching(False)

    def set_results(self, rows: list[ResultRow]) -> None:
        self.clear_results()
        if not rows:
            self.set_empty_message("Sonuç bulunamadı")
            self.set_result_count(0)
            return
        self._empty_wrap.hide()
        for row in rows:
            self._results_inner_layout.insertWidget(
                self._results_inner_layout.count() - 1, row
            )
            self._result_rows.append(row)
        self.set_result_count(len(rows))
