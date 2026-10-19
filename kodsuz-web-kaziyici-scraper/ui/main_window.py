from __future__ import annotations

import math
from pathlib import Path
from urllib.parse import urlparse

from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QFont, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QAbstractItemView,
    QButtonGroup,
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QListWidgetItem,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSpinBox,
    QTabWidget,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
)

from ui.browser_panel import BrowserPanel, webengine_available
from ui.theme import APP_STYLE, SIDEBAR_WIDTH, SUCCESS, TEXT_MUTED, TEXT_PRIMARY, WARNING
from utils.config import (
    dismiss_robots_banner,
    get_history,
    get_settings,
    push_history,
    resolve_user_agent,
    robots_dismissed,
    update_settings,
)
from utils.scraper import ScrapeOptions, ScrapeResult, count_selector_matches, export_csv, export_json, export_xlsx, scrape_with_selector

PRESETS = {
    "ecommerce": {
        "url": "https://ornek-magaza.com/urunler",
        "selector": ".product",
        "mode": "table",
        "cols": {"name": ".product strong", "price": ".product .price", "stock": ".product .stock", "link": "a@href"},
    },
    "blog": {
        "url": "https://ornek-blog.com/yazilar",
        "selector": "article.post",
        "mode": "links",
        "cols": {"name": "h2 a", "price": "", "stock": "", "link": "a@href"},
    },
    "news": {
        "url": "https://ornek-haber.com/gundem",
        "selector": ".headline",
        "mode": "text",
        "cols": {"name": ".headline", "price": ".date", "stock": ".category", "link": "a@href"},
    },
    "links": {
        "url": "https://ornek-site.com/sitemap",
        "selector": "nav a",
        "mode": "links",
        "cols": {"name": "a", "price": "", "stock": "", "link": "a@href"},
    },
}


class ScrapeWorker(QThread):
    finished_ok = Signal(object)
    failed = Signal(str)
    progress = Signal(str, int)

    def __init__(self, url: str, selector: str, mode: str, options: ScrapeOptions, settings: dict, html: str | None = None, parent=None) -> None:
        super().__init__(parent)
        self._url = url
        self._selector = selector
        self._mode = mode
        self._options = options
        self._settings = settings
        self._html = html

    def run(self) -> None:
        try:
            self.progress.emit("fetch", 20)
            result = scrape_with_selector(
                self._url,
                self._selector,
                self._mode,
                options=self._options,
                settings=self._settings,
                html=self._html,
            )
            self.progress.emit("extract", 100)
            self.finished_ok.emit(result)
        except Exception as exc:
            self.failed.emit(str(exc))


class SettingsDialog(QDialog):
    def __init__(self, settings: dict, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Ayarlar")
        self.setMinimumWidth(400)
        self._settings = dict(settings)

        layout = QVBoxLayout(self)
        self._rate = QSpinBox()
        self._rate.setRange(0, 60)
        self._rate.setValue(int(settings.get("rate", 2)))
        layout.addWidget(QLabel("Hız sınırı (sn/istek)"))
        layout.addWidget(self._rate)

        self._default_mode = QComboBox()
        self._default_mode.addItem("Tablo", "table")
        self._default_mode.addItem("Bağlantılar", "links")
        self._default_mode.addItem("Metin", "text")
        idx = self._default_mode.findData(settings.get("default_mode", "table"))
        if idx >= 0:
            self._default_mode.setCurrentIndex(idx)
        layout.addWidget(QLabel("Varsayılan mod"))
        layout.addWidget(self._default_mode)

        self._encoding = QComboBox()
        self._encoding.addItem("UTF-8 (BOM yok)", "utf-8")
        self._encoding.addItem("UTF-8 BOM (Excel)", "utf-8-bom")
        self._encoding.addItem("ISO-8859-9 (Türkçe)", "iso-8859-9")
        enc_idx = self._encoding.findData(settings.get("encoding", "utf-8"))
        if enc_idx >= 0:
            self._encoding.setCurrentIndex(enc_idx)
        layout.addWidget(QLabel("Dışa aktarma kodlaması"))
        layout.addWidget(self._encoding)

        self._export_path = QLineEdit(settings.get("export_path", ""))
        layout.addWidget(QLabel("Varsayılan kayıt klasörü"))
        layout.addWidget(self._export_path)

        self._save_history = QCheckBox("Çalıştırma geçmişini kaydet (son 20)")
        self._save_history.setChecked(bool(settings.get("save_history", True)))
        layout.addWidget(self._save_history)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def values(self) -> dict:
        return {
            "rate": float(self._rate.value()),
            "default_mode": self._default_mode.currentData(),
            "encoding": self._encoding.currentData(),
            "export_path": self._export_path.text().strip(),
            "save_history": self._save_history.isChecked(),
            "delay_ms": int(self._rate.value() * 1000),
        }


class HistoryDialog(QDialog):
    def __init__(self, on_pick, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Çalıştırma geçmişi")
        self.setMinimumSize(360, 420)
        self._on_pick = on_pick
        layout = QVBoxLayout(self)
        self._list = QListWidget()
        layout.addWidget(self._list)
        close = QPushButton("Kapat")
        close.clicked.connect(self.reject)
        layout.addWidget(close)
        self._reload()

    def _reload(self) -> None:
        self._list.clear()
        history = get_history()
        if not history:
            item = QListWidgetItem("Henüz çalıştırma yok")
            item.setFlags(Qt.ItemFlag.NoItemFlags)
            self._list.addItem(item)
            return
        for entry in history:
            text = f"{entry.get('url', '')}\n{entry.get('rows', 0)} satır · {entry.get('mode', '')} · {entry.get('time', '')}"
            item = QListWidgetItem(text)
            item.setData(Qt.ItemDataRole.UserRole, entry)
            self._list.addItem(item)
        self._list.itemClicked.connect(self._pick)

    def _pick(self, item: QListWidgetItem) -> None:
        entry = item.data(Qt.ItemDataRole.UserRole)
        if entry:
            self._on_pick(entry)
            self.accept()


class MainWindow(QMainWindow):
    PAGE_SIZE = 10

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Kodsuz Web Kazıyıcı")
        self.resize(1200, 720)
        self.setMinimumSize(960, 640)
        self.setStyleSheet(APP_STYLE)

        self._settings = get_settings()
        self._result: ScrapeResult | None = None
        self._worker: ScrapeWorker | None = None
        self._all_rows: list[list[str]] = []
        self._filtered_rows: list[list[str]] = []
        self._current_page = 1
        self._mode = self._settings.get("default_mode", "table")
        self._preset_group: QButtonGroup | None = None

        root = QWidget()
        root.setObjectName("AppRoot")
        outer = QVBoxLayout(root)
        outer.setContentsMargins(24, 24, 24, 24)

        shell = QFrame()
        shell.setObjectName("Shell")
        shell_layout = QVBoxLayout(shell)
        shell_layout.setContentsMargins(0, 0, 0, 0)
        shell_layout.setSpacing(0)

        shell_layout.addWidget(self._build_toolbar())
        self._robots_banner = self._build_robots_banner()
        shell_layout.addWidget(self._robots_banner)

        body = QHBoxLayout()
        body.setSpacing(0)
        body.addWidget(self._build_sidebar())
        body.addWidget(self._build_results(), stretch=1)
        shell_layout.addLayout(body, stretch=1)
        shell_layout.addWidget(self._build_statusbar())

        outer.addWidget(shell)
        self.setCentralWidget(root)
        self._wire_shortcuts()
        self._apply_preset("ecommerce", silent=True)
        self._set_trust_chip("idle")
        if robots_dismissed():
            self._robots_banner.hide()
        if webengine_available() and self._browser:
            self._browser.set_user_agent(resolve_user_agent(self._settings))

    def _build_toolbar(self) -> QFrame:
        bar = QFrame()
        bar.setObjectName("Toolbar")
        bar.setFixedHeight(48)
        row = QHBoxLayout(bar)
        row.setContentsMargins(16, 0, 16, 0)

        brand = QLabel("Kodsuz Web Kazıyıcı")
        brand.setProperty("class", "primary")
        f = brand.font()
        f.setPointSize(12)
        f.setWeight(QFont.Weight.DemiBold)
        brand.setFont(f)
        row.addWidget(brand)

        row.addStretch()

        hist_btn = QPushButton("⏱")
        hist_btn.setProperty("class", "icon")
        hist_btn.setToolTip("Geçmiş")
        hist_btn.clicked.connect(self._open_history)
        row.addWidget(hist_btn)

        settings_btn = QPushButton("⚙")
        settings_btn.setProperty("class", "icon")
        settings_btn.setToolTip("Ayarlar")
        settings_btn.clicked.connect(self._open_settings)
        row.addWidget(settings_btn)

        self._trust_chip = QFrame()
        self._trust_chip.setObjectName("TrustChip")
        chip_layout = QHBoxLayout(self._trust_chip)
        chip_layout.setContentsMargins(10, 4, 10, 4)
        self._trust_label = QLabel()
        chip_layout.addWidget(self._trust_label)
        row.addWidget(self._trust_chip)

        meta = QLabel("Yerel · CSV/JSON/Excel")
        meta.setProperty("class", "muted")
        row.addWidget(meta)
        return bar

    def _build_robots_banner(self) -> QFrame:
        frame = QFrame()
        frame.setObjectName("RobotsBanner")
        row = QHBoxLayout(frame)
        row.setContentsMargins(16, 10, 16, 10)
        text = QLabel(
            "<b>Etik kullanım:</b> Yalnızca izin verilen sitelerden veri çıkarın. "
            "robots.txt ve site kullanım şartlarına uyun. CAPTCHA bypass desteklenmez."
        )
        text.setObjectName("RobotsText")
        text.setWordWrap(True)
        row.addWidget(text, stretch=1)

        accept = QPushButton("Anladım")
        accept.setObjectName("RobotsAccept")
        accept.clicked.connect(self._dismiss_robots)
        later = QPushButton("Daha sonra")
        later.setStyleSheet(f"color: {WARNING}; border: none;")
        later.clicked.connect(self._dismiss_robots)
        dismiss = QPushButton("✕")
        dismiss.setStyleSheet(f"color: {WARNING}; border: none;")
        dismiss.clicked.connect(self._dismiss_robots)
        row.addWidget(accept)
        row.addWidget(later)
        row.addWidget(dismiss)
        return frame

    def _build_sidebar(self) -> QFrame:
        side = QFrame()
        side.setObjectName("Sidebar")
        side.setFixedWidth(SIDEBAR_WIDTH)
        layout = QVBoxLayout(side)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        tabs = QHBoxLayout()
        self._tab_group = QButtonGroup(self)
        self._tab_group.setExclusive(True)
        for i, (tid, label) in enumerate([("basic", "Temel"), ("columns", "Sütunlar"), ("advanced", "Gelişmiş")]):
            btn = QPushButton(label)
            btn.setProperty("class", "tab")
            btn.setCheckable(True)
            btn.setChecked(i == 0)
            btn.clicked.connect(lambda _=False, t=tid: self._switch_tab(t))
            self._tab_group.addButton(btn)
            tabs.addWidget(btn)
        layout.addLayout(tabs)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        panels = QWidget()
        panels_layout = QVBoxLayout(panels)

        self._panel_basic = QWidget()
        basic = QVBoxLayout(self._panel_basic)
        basic.addWidget(self._section_label("Hazır şablon"))
        chips = QHBoxLayout()
        self._preset_group = QButtonGroup(self)
        self._preset_group.setExclusive(True)
        for key, label in [("ecommerce", "E-ticaret"), ("blog", "Blog"), ("news", "Haber"), ("links", "Bağlantı listesi")]:
            chip = QPushButton(label)
            chip.setProperty("class", "chip")
            chip.setProperty("preset", key)
            chip.setCheckable(True)
            chip.clicked.connect(lambda _=False, k=key: self._apply_preset(k))
            self._preset_group.addButton(chip)
            chips.addWidget(chip)
        basic.addLayout(chips)

        basic.addWidget(self._field_label("URL"))
        self._url_input = QLineEdit("https://ornek-magaza.com/urunler")
        self._url_input.textChanged.connect(self._on_form_change)
        basic.addWidget(self._url_input)
        open_row = QHBoxLayout()
        self._open_page_btn = QPushButton("Sayfayı tarayıcıda aç")
        self._open_page_btn.clicked.connect(self._open_in_browser)
        open_row.addWidget(self._open_page_btn)
        basic.addLayout(open_row)

        basic.addWidget(self._field_label("Ana CSS seçici"))
        self._selector_input = QLineEdit(".product")
        self._selector_input.setProperty("mono", True)
        self._selector_input.textChanged.connect(self._on_form_change)
        basic.addWidget(self._selector_input)

        test_btn = QPushButton("Seçiciyi test et")
        test_btn.setStyleSheet("border-style: dashed; color: #6b7280;")
        test_btn.clicked.connect(self._test_selector)
        basic.addWidget(test_btn)
        self._match_preview = QLabel()
        self._match_preview.setProperty("class", "muted")
        self._match_preview.hide()
        basic.addWidget(self._match_preview)
        basic.addStretch()
        panels_layout.addWidget(self._panel_basic)

        self._panel_columns = QWidget()
        cols = QVBoxLayout(self._panel_columns)
        cols.addWidget(self._section_label("Sütun eşleme"))
        sub = QLabel("Tablo modunda her sütun için alt seçici tanımlayın.")
        sub.setProperty("class", "muted")
        cols.addWidget(sub)
        self._col_name = self._mono_field(".product strong")
        self._col_price = self._mono_field(".product .price")
        self._col_stock = self._mono_field(".product .stock")
        self._col_link = self._mono_field("a@href")
        for label, widget in [
            ("Ürün / başlık", self._col_name),
            ("Fiyat / değer", self._col_price),
            ("Stok / meta", self._col_stock),
            ("Bağlantı (href)", self._col_link),
        ]:
            cols.addWidget(self._field_label(label))
            cols.addWidget(widget)
        cols.addWidget(self._field_label("Öznitelik çıkarma"))
        self._attr_mode = QComboBox()
        for val, label in [("text", "Metin içeriği"), ("href", "href"), ("src", "src"), ("data-id", "data-id")]:
            self._attr_mode.addItem(label, val)
        cols.addWidget(self._attr_mode)
        cols.addStretch()
        self._panel_columns.hide()
        panels_layout.addWidget(self._panel_columns)

        self._panel_advanced = QWidget()
        adv = QVBoxLayout(self._panel_advanced)
        adv.addWidget(self._section_label("Gelişmiş ayarlar"))
        adv.addWidget(self._field_label("Veri kaynağı"))
        self._fetch_engine = QComboBox()
        self._fetch_engine.addItem("Tarayıcı (JS / SPA destekli)", "browser")
        self._fetch_engine.addItem("Statik (hızlı, urllib)", "static")
        eng_idx = self._fetch_engine.findData(self._settings.get("fetch_engine", "browser"))
        if eng_idx >= 0:
            self._fetch_engine.setCurrentIndex(eng_idx)
        adv.addWidget(self._fetch_engine)

        adv.addWidget(self._field_label("Render bekleme (ms)"))
        self._render_wait = QSpinBox()
        self._render_wait.setRange(0, 30000)
        self._render_wait.setValue(int(self._settings.get("render_wait_ms", 1500)))
        adv.addWidget(self._render_wait)

        self._auto_scroll = QCheckBox("Lazy-load için otomatik kaydır")
        self._auto_scroll.setChecked(bool(self._settings.get("auto_scroll", True)))
        adv.addWidget(self._auto_scroll)

        adv.addWidget(self._field_label("Accept-Language"))
        self._accept_lang = QLineEdit(self._settings.get("accept_language", "tr-TR,tr;q=0.9,en;q=0.8"))
        adv.addWidget(self._accept_lang)

        adv.addWidget(self._field_label("İstek ayarları"))
        grid = QGridLayout()
        self._delay_ms = QSpinBox()
        self._delay_ms.setRange(0, 60000)
        self._delay_ms.setValue(int(self._settings.get("delay_ms", 2000)))
        self._timeout_s = QSpinBox()
        self._timeout_s.setRange(5, 120)
        self._timeout_s.setValue(int(self._settings.get("timeout_s", 30)))
        grid.addWidget(QLabel("Bekleme (ms)"), 0, 0)
        grid.addWidget(self._delay_ms, 0, 1)
        grid.addWidget(QLabel("Zaman aşımı (sn)"), 1, 0)
        grid.addWidget(self._timeout_s, 1, 1)
        adv.addLayout(grid)

        adv.addWidget(self._field_label("Maks. satır"))
        self._max_rows = QSpinBox()
        self._max_rows.setRange(1, 5000)
        self._max_rows.setValue(int(self._settings.get("max_rows", 500)))
        adv.addWidget(self._max_rows)

        adv.addWidget(self._field_label("User-Agent"))
        self._ua_combo = QComboBox()
        for val, label in [
            ("chrome", "Chrome 122 — Windows"),
            ("firefox", "Firefox 123"),
            ("bot", "ScraperBot/1.0 (+etik)"),
            ("custom", "Özel…"),
        ]:
            self._ua_combo.addItem(label, val)
        adv.addWidget(self._ua_combo)
        self._custom_ua = QLineEdit(self._settings.get("custom_user_agent", ""))
        self._custom_ua.setProperty("mono", True)
        self._custom_ua.setPlaceholderText("Mozilla/5.0 …")
        self._custom_ua.setVisible(self._ua_combo.currentData() == "custom")
        self._ua_combo.currentIndexChanged.connect(
            lambda: self._custom_ua.setVisible(self._ua_combo.currentData() == "custom")
        )
        adv.addWidget(self._custom_ua)

        self._strip_html = QCheckBox("HTML etiketlerini temizle")
        self._strip_html.setChecked(bool(self._settings.get("strip_html", True)))
        self._follow_pagination = QCheckBox('Sayfalama takip et (rel="next")')
        self._follow_pagination.setChecked(bool(self._settings.get("follow_pagination", False)))
        self._robots_check = QCheckBox("robots.txt otomatik kontrol")
        self._robots_check.setChecked(bool(self._settings.get("robots_check", True)))
        for cb in (self._strip_html, self._follow_pagination, self._robots_check):
            adv.addWidget(cb)
        adv.addStretch()
        self._panel_advanced.hide()
        panels_layout.addWidget(self._panel_advanced)

        scroll.setWidget(panels)
        layout.addWidget(scroll, stretch=1)

        action = QFrame()
        action.setObjectName("ActionZone")
        action_layout = QVBoxLayout(action)
        action_layout.setContentsMargins(16, 16, 16, 16)
        action_layout.addWidget(self._section_label("Çıkarma modu"))

        mode_row = QHBoxLayout()
        self._mode_group = QButtonGroup(self)
        self._mode_group.setExclusive(True)
        for mode, label in [("links", "Bağlantılar"), ("text", "Metin"), ("table", "Tablo")]:
            btn = QPushButton(label)
            btn.setProperty("class", "mode")
            btn.setCheckable(True)
            btn.setProperty("mode", mode)
            btn.clicked.connect(lambda _=False, m=mode: self._set_mode(m))
            self._mode_group.addButton(btn)
            mode_row.addWidget(btn)
        action_layout.addLayout(mode_row)

        self._run_btn = QPushButton("▶  Çalıştır")
        self._run_btn.setProperty("class", "run")
        self._run_btn.clicked.connect(self._run_scrape)
        action_layout.addWidget(self._run_btn)

        hint = QLabel("<kbd>Ctrl+Enter</kbd> çalıştır · <kbd>Ctrl+E</kbd> CSV · <kbd>Ctrl+Shift+E</kbd> JSON · <kbd>F5</kbd> yenile")
        hint.setProperty("class", "muted")
        hint.setTextFormat(Qt.TextFormat.RichText)
        action_layout.addWidget(hint)
        layout.addWidget(action)

        self._set_mode(self._mode)
        return side

    def _build_results(self) -> QFrame:
        panel = QFrame()
        layout = QVBoxLayout(panel)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self._result_tabs = QTabWidget()
        self._browser = BrowserPanel()
        if webengine_available():
            self._browser.selector_picked.connect(self._on_selector_picked)
            self._browser.url_changed.connect(self._on_browser_url)
        self._result_tabs.addTab(self._browser, "Tarayıcı")

        results_page = QWidget()
        results_layout = QVBoxLayout(results_page)
        results_layout.setContentsMargins(0, 0, 0, 0)
        results_layout.setSpacing(0)

        self._request_meta = QLabel()
        self._request_meta.setStyleSheet(f"color: {TEXT_MUTED}; font-family: monospace; font-size: 11px; padding: 8px 16px;")
        self._request_meta.hide()
        results_layout.addWidget(self._request_meta)

        toolbar = QFrame()
        toolbar.setObjectName("ResultsToolbar")
        toolbar.setFixedHeight(48)
        trow = QHBoxLayout(toolbar)
        trow.setContentsMargins(16, 0, 16, 0)
        title = QLabel("Sonuç önizleme")
        title.setProperty("class", "primary")
        trow.addWidget(title)
        self._results_count = QLabel("—")
        self._results_count.setProperty("class", "muted")
        trow.addWidget(self._results_count)
        self._search = QLineEdit()
        self._search.setPlaceholderText("Tabloda ara…")
        self._search.setMaximumWidth(220)
        self._search.setEnabled(False)
        self._search.textChanged.connect(self._filter_table)
        trow.addWidget(self._search, stretch=1)

        self._copy_btn = QPushButton("Kopyala")
        self._copy_btn.setProperty("class", "ghost")
        self._copy_btn.setEnabled(False)
        self._copy_btn.clicked.connect(self._copy_selection)
        self._csv_btn = QPushButton("CSV")
        self._csv_btn.setProperty("class", "ghost")
        self._csv_btn.setEnabled(False)
        self._csv_btn.clicked.connect(lambda: self._export("csv"))
        self._json_btn = QPushButton("JSON")
        self._json_btn.setProperty("class", "ghost")
        self._json_btn.setEnabled(False)
        self._json_btn.clicked.connect(lambda: self._export("json"))
        self._xlsx_btn = QPushButton("Excel")
        self._xlsx_btn.setProperty("class", "ghost")
        self._xlsx_btn.setEnabled(False)
        self._xlsx_btn.clicked.connect(lambda: self._export("xlsx"))
        for btn in (self._copy_btn, self._csv_btn, self._json_btn, self._xlsx_btn):
            trow.addWidget(btn)
        results_layout.addWidget(toolbar)

        self._match_banner = QLabel("Seçici eşleşmedi — CSS seçiciyi veya sütun eşlemesini kontrol edin")
        self._match_banner.setStyleSheet(f"color: {WARNING}; background: rgba(245,158,11,0.12); padding: 8px 16px;")
        self._match_banner.hide()
        results_layout.addWidget(self._match_banner)

        self._table = QTableWidget()
        self._table.setAlternatingRowColors(True)
        self._table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self._table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self._table.itemSelectionChanged.connect(self._on_selection_changed)
        results_layout.addWidget(self._table, stretch=1)

        footer = QHBoxLayout()
        footer.setContentsMargins(16, 8, 16, 8)
        self._selection_info = QLabel("0 satır seçili")
        self._selection_info.setProperty("class", "muted")
        footer.addWidget(self._selection_info)
        self._page_info = QLabel("Sayfa 1 / 1")
        self._page_info.setProperty("class", "muted")
        footer.addWidget(self._page_info)
        footer.addStretch()
        self._prev_page = QPushButton("‹")
        self._prev_page.setProperty("class", "icon")
        self._prev_page.clicked.connect(lambda: self._change_page(-1))
        self._next_page = QPushButton("›")
        self._next_page.setProperty("class", "icon")
        self._next_page.clicked.connect(lambda: self._change_page(1))
        footer.addWidget(self._prev_page)
        footer.addWidget(self._next_page)
        self._footer = QWidget()
        self._footer.setLayout(footer)
        self._footer.hide()
        results_layout.addWidget(self._footer)

        self._result_tabs.addTab(results_page, "Sonuçlar")
        layout.addWidget(self._result_tabs, stretch=1)

        self._show_empty_state()
        return panel

    def _build_statusbar(self) -> QFrame:
        bar = QFrame()
        bar.setObjectName("StatusBar")
        bar.setFixedHeight(28)
        row = QHBoxLayout(bar)
        row.setContentsMargins(16, 0, 16, 0)
        self._status_dot = QLabel("●")
        self._status_dot.setStyleSheet(f"color: {SUCCESS}; font-size: 8px;")
        row.addWidget(self._status_dot)
        self._status_text = QLabel("Hazır — URL girin, seçici belirleyin, Çalıştır")
        self._status_text.setProperty("class", "muted")
        row.addWidget(self._status_text)
        self._progress = QProgressBar()
        self._progress.setMaximumWidth(160)
        self._progress.setTextVisible(False)
        self._progress.hide()
        row.addWidget(self._progress)
        row.addStretch()
        self._rate_label = QLabel(f"Hız sınırı: {self._settings.get('rate', 2)} sn/istek")
        self._rate_label.setProperty("class", "muted")
        row.addWidget(self._rate_label)
        return bar

    def _section_label(self, text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setProperty("class", "section")
        return lbl

    def _field_label(self, text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setStyleSheet(f"color: {TEXT_PRIMARY}; font-weight: 500; margin-top: 8px;")
        return lbl

    def _mono_field(self, value: str) -> QLineEdit:
        field = QLineEdit(value)
        field.setProperty("mono", True)
        return field

    def _switch_tab(self, tab: str) -> None:
        self._panel_basic.setVisible(tab == "basic")
        self._panel_columns.setVisible(tab == "columns")
        self._panel_advanced.setVisible(tab == "advanced")

    def _set_mode(self, mode: str) -> None:
        self._mode = mode
        for btn in self._mode_group.buttons():
            btn.setChecked(btn.property("mode") == mode)

    def _apply_preset(self, key: str, *, silent: bool = False) -> None:
        preset = PRESETS.get(key)
        if not preset:
            return
        self._url_input.setText(preset["url"])
        self._selector_input.setText(preset["selector"])
        cols = preset["cols"]
        self._col_name.setText(cols.get("name", ""))
        self._col_price.setText(cols.get("price", ""))
        self._col_stock.setText(cols.get("stock", ""))
        self._col_link.setText(cols.get("link", ""))
        self._set_mode(preset["mode"])
        if self._preset_group:
            for btn in self._preset_group.buttons():
                btn.setChecked(btn.property("preset") == key)
        if not silent:
            self._match_preview.hide()
        self._set_trust_chip("idle")

    def _on_form_change(self) -> None:
        self._run_btn.setEnabled(bool(self._url_input.text().strip() and self._selector_input.text().strip()))
        self._match_preview.hide()
        self._set_trust_chip("idle")

    def _set_trust_chip(self, state: str) -> None:
        # Gerçek robots.txt sonucunu gösterir (çalıştırma sonrası); öncesinde "denetlenmedi".
        label, color = {
            "idle": ("robots.txt: çalıştırınca denetlenir", TEXT_MUTED),
            "ok": ("robots.txt uyumlu", SUCCESS),
            "warn": ("robots.txt okunamadı", WARNING),
            "off": ("robots.txt denetimi kapalı", WARNING),
            "blocked": ("robots.txt engeli", "#ef4444"),
        }[state]
        self._trust_chip.setProperty("state", {"idle": "ok", "off": "warn"}.get(state, state))
        self._trust_chip.style().unpolish(self._trust_chip)
        self._trust_chip.style().polish(self._trust_chip)
        self._trust_label.setText(label)
        self._trust_label.setStyleSheet(f"color: {color}; font-size: 11px; font-weight: 500;")

    def _dismiss_robots(self) -> None:
        self._robots_banner.hide()
        dismiss_robots_banner()

    def _current_settings(self) -> dict:
        return {
            **self._settings,
            "delay_ms": self._delay_ms.value(),
            "timeout_s": self._timeout_s.value(),
            "max_rows": self._max_rows.value(),
            "user_agent": self._ua_combo.currentData(),
            "custom_user_agent": self._custom_ua.text().strip(),
            "strip_html": self._strip_html.isChecked(),
            "follow_pagination": self._follow_pagination.isChecked(),
            "robots_check": self._robots_check.isChecked(),
            "fetch_engine": self._fetch_engine.currentData(),
            "render_wait_ms": self._render_wait.value(),
            "auto_scroll": self._auto_scroll.isChecked(),
            "accept_language": self._accept_lang.text().strip(),
        }

    def _uses_browser(self) -> bool:
        return self._fetch_engine.currentData() == "browser" and webengine_available()

    def _open_in_browser(self) -> None:
        url = self._url_input.text().strip()
        if not url.startswith(("http://", "https://")):
            self._status_text.setText("Geçerli URL girin")
            return
        self._result_tabs.setCurrentIndex(0)
        self._browser.set_user_agent(resolve_user_agent(self._current_settings()))
        self._browser.load_url(url)

    def _on_browser_url(self, url: str) -> None:
        if url and url != self._url_input.text().strip():
            self._url_input.setText(url)

    def _on_selector_picked(self, selector: str) -> None:
        self._selector_input.setText(selector)
        self._match_preview.setText(f"Seçilen: {selector}")
        self._match_preview.show()
        self._status_text.setText("CSS seçici tarayıcıdan alındı")

    def _scrape_options(self) -> ScrapeOptions:
        return ScrapeOptions(
            max_rows=self._max_rows.value(),
            timeout_s=self._timeout_s.value(),
            delay_ms=self._delay_ms.value(),
            strip_html=self._strip_html.isChecked(),
            follow_pagination=self._follow_pagination.isChecked(),
            robots_check=self._robots_check.isChecked(),
            columns={
                "name": self._col_name.text().strip(),
                "price": self._col_price.text().strip(),
                "stock": self._col_stock.text().strip(),
                "link": self._col_link.text().strip(),
            },
            attr_mode=self._attr_mode.currentData(),
        )

    def _validate_form(self) -> bool:
        url = self._url_input.text().strip()
        ok_url = url.startswith("http://") or url.startswith("https://")
        ok_sel = bool(self._selector_input.text().strip())
        self._url_input.setProperty("invalid", not ok_url)
        self._selector_input.setProperty("invalid", not ok_sel)
        self._url_input.style().unpolish(self._url_input)
        self._url_input.style().polish(self._url_input)
        self._selector_input.style().unpolish(self._selector_input)
        self._selector_input.style().polish(self._selector_input)
        return ok_url and ok_sel

    def _run_scrape(self) -> None:
        # Buton çalışma boyunca kapalı; kısayollar (Ctrl+Enter/F5) da ikinci çalıştırmayı başlatmasın
        if (self._worker and self._worker.isRunning()) or not self._run_btn.isEnabled():
            return
        if not self._validate_form():
            self._status_text.setText("Form hatalı — URL ve seçici kontrol edin")
            return

        url = self._url_input.text().strip()
        selector = self._selector_input.text().strip()
        settings = self._current_settings()
        self._run_btn.setEnabled(False)
        self._status_text.setText("Sayfa getiriliyor…")
        self._progress.show()
        self._progress.setValue(10)
        self._status_dot.setStyleSheet(f"color: {TEXT_PRIMARY};")

        if self._uses_browser():
            self._result_tabs.setCurrentIndex(0)
            browser_url = self._browser.current_url() if self._browser else ""
            if not browser_url.startswith(("http://", "https://")) or urlparse(browser_url).netloc != urlparse(url).netloc:
                self._browser.load_url(url)

            def start_with_html(html: str) -> None:
                self._start_worker(url, selector, settings, html)

            self._browser.run_after_ready(
                settings.get("render_wait_ms", 1500),
                settings.get("auto_scroll", True),
                start_with_html,
            )
            return

        self._start_worker(url, selector, settings, None)

    def _start_worker(self, url: str, selector: str, settings: dict, html: str | None) -> None:
        self._worker = ScrapeWorker(url, selector, self._mode, self._scrape_options(), settings, html, self)
        self._worker.progress.connect(self._on_progress)
        self._worker.finished_ok.connect(self._on_done)
        self._worker.failed.connect(self._on_failed)
        self._worker.start()

    def _on_progress(self, step: str, value: int) -> None:
        labels = {"fetch": "Sayfa getiriliyor…", "parse": "HTML ayrıştırılıyor…", "extract": "Veri çıkarılıyor…"}
        self._status_text.setText(labels.get(step, "İşleniyor…"))
        self._progress.setValue(value)

    def _on_done(self, result: ScrapeResult) -> None:
        self._run_btn.setEnabled(True)
        self._result = result
        self._worker = None
        self._progress.hide()
        self._progress.setValue(0)
        self._status_dot.setStyleSheet(f"color: {SUCCESS}; font-size: 8px;")

        if result.robots_warning and not robots_dismissed():
            self._robots_banner.show()
        if not self._robots_check.isChecked():
            self._set_trust_chip("off")
        else:
            self._set_trust_chip("warn" if result.robots_warning else "ok")

        if not result.rows:
            self._match_banner.show()
            self._show_empty_state("Seçici eşleşmedi — farklı bir CSS seçici deneyin.")
            self._results_count.setText("0 satır")
            self._disable_exports()
            self._request_meta.hide()
            self._status_text.setText("Tamamlandı — 0 eşleşme")
            return

        self._match_banner.hide()
        self._all_rows = result.rows
        self._current_page = 1
        engine_label = "Qt WebEngine" if result.engine == "browser" else "urllib + BeautifulSoup4"
        self._request_meta.setText(
            f"GET  {result.status_code} OK  ·  {result.size_kb:.1f} KB  ·  {result.elapsed_ms} ms  ·  {engine_label}"
        )
        self._request_meta.show()
        self._result_tabs.setCurrentIndex(1)
        self._search.setEnabled(True)
        self._csv_btn.setEnabled(True)
        self._json_btn.setEnabled(True)
        self._xlsx_btn.setEnabled(True)
        self._filter_table()
        self._status_text.setText(f"Tamamlandı — {len(result.rows)} satır çıkarıldı")

        from datetime import datetime

        push_history(
            {
                "url": result.url,
                "selector": result.selector,
                "mode": result.mode,
                "rows": len(result.rows),
                "time": datetime.now().strftime("%d %b %H:%M"),
            }
        )

    def _on_failed(self, msg: str) -> None:
        self._run_btn.setEnabled(True)
        self._worker = None
        self._progress.hide()
        self._status_text.setText("Hata")
        if msg.startswith("robots.txt"):
            self._set_trust_chip("blocked")
        self._show_empty_state(msg, error=True)
        self._results_count.setText("Hata")
        self._disable_exports()
        self._request_meta.hide()

    def _disable_exports(self) -> None:
        self._search.setEnabled(False)
        self._csv_btn.setEnabled(False)
        self._json_btn.setEnabled(False)
        self._xlsx_btn.setEnabled(False)
        self._copy_btn.setEnabled(False)

    def _show_empty_state(self, message: str = "Sonuç yok — URL ve seçici girin, ardından Çalıştır'a basın.", *, error: bool = False) -> None:
        self._table.clear()
        self._table.setRowCount(1)
        self._table.setColumnCount(1)
        item = QTableWidgetItem(message)
        item.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
        if error:
            item.setForeground(Qt.GlobalColor.red)
        self._table.setItem(0, 0, item)
        self._table.horizontalHeader().setVisible(False)
        self._footer.hide()

    def _filter_table(self) -> None:
        if not self._result:
            return
        q = self._search.text().strip().lower()
        self._filtered_rows = (
            self._all_rows
            if not q
            else [r for r in self._all_rows if any(q in str(c).lower() for c in r)]
        )
        self._paint_page()

    def _paint_page(self) -> None:
        if not self._result:
            return
        cols = self._result.columns or ["değer"]
        total = len(self._filtered_rows)
        pages = max(1, math.ceil(total / self.PAGE_SIZE))
        self._current_page = min(self._current_page, pages)
        start = (self._current_page - 1) * self.PAGE_SIZE
        page_rows = self._filtered_rows[start : start + self.PAGE_SIZE]

        self._table.clear()
        self._table.setColumnCount(len(cols))
        self._table.setHorizontalHeaderLabels(cols)
        self._table.horizontalHeader().setVisible(True)
        self._table.setRowCount(len(page_rows))
        for r, row in enumerate(page_rows):
            for c, val in enumerate(row):
                self._table.setItem(r, c, QTableWidgetItem(str(val)))

        suffix = " (filtreli)" if self._search.text().strip() else ""
        self._results_count.setText(f"{total} satır{suffix}")
        if total > self.PAGE_SIZE:
            self._footer.show()
            self._page_info.setText(f"Sayfa {self._current_page} / {pages}")
            self._prev_page.setEnabled(self._current_page > 1)
            self._next_page.setEnabled(self._current_page < pages)
        else:
            self._footer.hide()

    def _change_page(self, delta: int) -> None:
        self._current_page += delta
        self._paint_page()

    def _on_selection_changed(self) -> None:
        n = len({idx.row() for idx in self._table.selectedIndexes()})
        self._selection_info.setText(f"{n} satır seçili")
        self._copy_btn.setEnabled(n > 0)

    def _copy_selection(self) -> None:
        rows = sorted({idx.row() for idx in self._table.selectedIndexes()})
        if not rows:
            return
        lines = []
        for r in rows:
            cells = [self._table.item(r, c).text() for c in range(self._table.columnCount()) if self._table.item(r, c)]
            lines.append("\t".join(cells))
        from PySide6.QtGui import QGuiApplication

        QGuiApplication.clipboard().setText("\n".join(lines))
        self._status_text.setText(f"{len(lines)} satır panoya kopyalandı")

    def _export(self, fmt: str) -> None:
        if not self._result or not self._result.rows:
            return
        default_dir = self._settings.get("export_path") or str(Path.home() / "Documents")
        title, name, filt = {
            "csv": ("CSV kaydet", "scrape-sonuc.csv", "CSV (*.csv)"),
            "json": ("JSON kaydet", "scrape-sonuc.json", "JSON (*.json)"),
            "xlsx": ("Excel kaydet", "scrape-sonuc.xlsx", "Excel (*.xlsx)"),
        }[fmt]
        path, _ = QFileDialog.getSaveFileName(self, title, str(Path(default_dir) / name), filt)
        if not path:
            return
        try:
            if fmt == "csv":
                export_csv(path, self._result, encoding=self._settings.get("encoding", "utf-8"))
            elif fmt == "json":
                export_json(path, self._result)
            else:
                export_xlsx(path, self._result)
        except (OSError, UnicodeEncodeError) as exc:
            # Dosya Excel'de açıksa / klasör yazılamazsa ya da ISO-8859-9 bir karakteri kodlayamazsa
            QMessageBox.warning(self, "Kaydedilemedi", f"Dosya kaydedilemedi:\n{path}\n\n{exc}")
            self._status_text.setText("Kaydetme başarısız")
            return
        self._status_text.setText(f"Kaydedildi: {path}")

    def _test_selector(self) -> None:
        if not self._validate_form():
            return
        settings = self._current_settings()
        url = self._url_input.text().strip()
        selector = self._selector_input.text().strip()

        if self._uses_browser():

            def show_count(n) -> None:
                self._match_preview.setText(f"Önizleme: {int(n)} eşleşme (tarayıcı)")
                self._match_preview.show()

            def after_html(html: str) -> None:
                try:
                    from utils.scraper import count_in_html
                    show_count(count_in_html(html, selector))
                except Exception as exc:
                    self._match_preview.setText(str(exc))
                    self._match_preview.show()

            self._result_tabs.setCurrentIndex(0)
            self._browser.load_url(url)
            self._browser.run_after_ready(settings.get("render_wait_ms", 1500), False, after_html)
            return

        try:
            n = count_selector_matches(url, selector, settings=settings)
            self._match_preview.setText(f"Önizleme: {n} eşleşme bulundu")
            self._match_preview.show()
        except ValueError as exc:
            self._match_preview.setText(str(exc))
            self._match_preview.show()

    def _open_settings(self) -> None:
        dlg = SettingsDialog(self._settings, self)
        if dlg.exec() == QDialog.DialogCode.Accepted:
            self._settings = update_settings(dlg.values())
            self._delay_ms.setValue(int(self._settings.get("delay_ms", 2000)))
            self._rate_label.setText(f"Hız sınırı: {self._settings.get('rate', 2)} sn/istek")
            self._status_text.setText("Ayarlar kaydedildi")

    def _open_history(self) -> None:
        HistoryDialog(self._load_history_entry, self).exec()

    def _load_history_entry(self, entry: dict) -> None:
        self._url_input.setText(entry.get("url", ""))
        self._selector_input.setText(entry.get("selector", ""))
        self._set_mode(entry.get("mode", "table"))
        self._open_in_browser()

    def closeEvent(self, event) -> None:
        # Çalışan QThread yok edilirse uygulama çöker; isteğin bitmesini bekle
        if self._worker and self._worker.isRunning():
            self._worker.wait()
        super().closeEvent(event)

    def _wire_shortcuts(self) -> None:
        QShortcut(QKeySequence("Ctrl+Return"), self, self._run_scrape)
        QShortcut(QKeySequence("F5"), self, self._run_scrape)
        QShortcut(QKeySequence("Ctrl+E"), self, lambda: self._export("csv"))
        QShortcut(QKeySequence("Ctrl+Shift+E"), self, lambda: self._export("json"))
        QShortcut(QKeySequence("Ctrl+Shift+X"), self, lambda: self._export("xlsx"))
