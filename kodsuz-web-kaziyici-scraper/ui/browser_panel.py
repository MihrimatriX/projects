"""Gömülü Chromium tarayıcı — gezinme, önizleme ve element seçici."""

from __future__ import annotations

import json

from PySide6.QtCore import QTimer, QUrl, Signal
from PySide6.QtWidgets import QHBoxLayout, QLabel, QLineEdit, QPushButton, QVBoxLayout, QWidget

try:
    from PySide6.QtWebEngineCore import QWebEngineProfile
    from PySide6.QtWebEngineWidgets import QWebEngineView

    _WEBENGINE = True
except ImportError:
    _WEBENGINE = False
    QWebEngineView = None  # type: ignore

PICKER_JS = """
(function() {
  // Dinleyiciler sayfa başına bir kez kurulur; yalnızca __scraperPickerActive iken çalışır.
  // Python tarafı 200 ms'de bir __scraperPicked değerini okur (_poll_picker).
  window.__scraperPickerActive = true;
  window.__scraperPicked = '';
  if (window.__scraperPickerInstalled) return;
  window.__scraperPickerInstalled = true;
  if (!document.getElementById('scraper-pick-style')) {
    const s = document.createElement('style');
    s.id = 'scraper-pick-style';
    s.textContent = '.scraper-pick-hover{outline:2px solid #3b82f6!important;cursor:crosshair!important}';
    document.head.appendChild(s);
  }
  function path(el) {
    if (!el || el.nodeType !== 1) return '';
    if (el.id) return '#' + CSS.escape(el.id);
    const parts = [];
    while (el && el.nodeType === 1 && el !== document.documentElement) {
      let p = el.tagName.toLowerCase();
      if (el.classList && el.classList.length) {
        p += '.' + [...el.classList].slice(0, 2).map(c => CSS.escape(c)).join('.');
      }
      const parent = el.parentElement;
      if (parent) {
        const same = [...parent.children].filter(c => c.tagName === el.tagName);
        if (same.length > 1) p += `:nth-of-type(${same.indexOf(el) + 1})`;
      }
      parts.unshift(p);
      el = el.parentElement;
    }
    return parts.join(' > ');
  }
  document.addEventListener('mouseover', e => {
    if (!window.__scraperPickerActive) return;
    document.querySelectorAll('.scraper-pick-hover').forEach(n => n.classList.remove('scraper-pick-hover'));
    if (e.target.classList) e.target.classList.add('scraper-pick-hover');
  }, true);
  document.addEventListener('click', e => {
    if (!window.__scraperPickerActive) return;
    e.preventDefault();
    e.stopPropagation();
    window.__scraperPicked = path(e.target);
    window.__scraperPickerActive = false;
    document.querySelectorAll('.scraper-pick-hover').forEach(n => n.classList.remove('scraper-pick-hover'));
  }, true);
})();
"""

PICKER_OFF_JS = """
window.__scraperPickerActive = false;
document.querySelectorAll('.scraper-pick-hover').forEach(e => e.classList.remove('scraper-pick-hover'));
"""

SCROLL_JS = """
(async () => {
  for (let i = 0; i < 5; i++) {
    window.scrollBy(0, window.innerHeight);
    await new Promise(r => setTimeout(r, 250));
  }
  window.scrollTo(0, 0);
})();
"""


def webengine_available() -> bool:
    return _WEBENGINE


class BrowserPanel(QWidget):
    selector_picked = Signal(str)
    url_changed = Signal(str)
    load_finished = Signal(bool)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        if not _WEBENGINE:
            layout.addWidget(QLabel("Tarayıcı için: pip install PySide6-Addons"))
            self._view = None
            return

        nav = QHBoxLayout()
        nav.setContentsMargins(8, 8, 8, 4)
        self._back = QPushButton("←")
        self._back.setProperty("class", "icon")
        self._back.setFixedWidth(32)
        self._fwd = QPushButton("→")
        self._fwd.setProperty("class", "icon")
        self._fwd.setFixedWidth(32)
        self._reload = QPushButton("↻")
        self._reload.setProperty("class", "icon")
        self._reload.setFixedWidth(32)
        self._url = QLineEdit()
        self._url.setPlaceholderText("https://…")
        self._go = QPushButton("Git")
        self._go.setProperty("class", "primary")
        self._pick = QPushButton("Element seç")
        self._pick.setCheckable(True)
        nav.addWidget(self._back)
        nav.addWidget(self._fwd)
        nav.addWidget(self._reload)
        nav.addWidget(self._url, stretch=1)
        nav.addWidget(self._go)
        nav.addWidget(self._pick)
        layout.addLayout(nav)

        self._view = QWebEngineView()
        self._view.setUrl(QUrl("about:blank"))
        layout.addWidget(self._view, stretch=1)

        self._back.clicked.connect(self._view.back)
        self._fwd.clicked.connect(self._view.forward)
        self._reload.clicked.connect(self._view.reload)
        self._go.clicked.connect(self._navigate)
        self._url.returnPressed.connect(self._navigate)
        self._pick.toggled.connect(self._toggle_picker)
        self._view.urlChanged.connect(self._on_url_changed)
        self._view.loadFinished.connect(self._on_load_finished)

        # Yükleme sürerken run_after_ready isteği bekletilir, loadFinished'de başlatılır
        self._loading = False
        self._pending_ready = None
        self._view.loadStarted.connect(self._on_load_started)

        self._picker_timer = QTimer(self)
        self._picker_timer.setInterval(200)
        self._picker_timer.timeout.connect(self._poll_picker)

    def set_user_agent(self, ua: str) -> None:
        if self._view:
            QWebEngineProfile.defaultProfile().setHttpUserAgent(ua)

    def current_url(self) -> str:
        if not self._view:
            return ""
        return self._view.url().toString()

    def load_url(self, url: str) -> None:
        if not self._view or not url.strip():
            return
        self._url.setText(url.strip())
        self._loading = True
        self._view.setUrl(QUrl(url.strip()))

    def _navigate(self) -> None:
        url = self._url.text().strip()
        if url and not url.startswith(("http://", "https://")):
            url = "https://" + url
        if url:
            self.load_url(url)

    def _on_url_changed(self, qurl: QUrl) -> None:
        s = qurl.toString()
        if s and s != "about:blank":
            self._url.setText(s)
            self.url_changed.emit(s)

    def _on_load_started(self) -> None:
        self._loading = True

    def _on_load_finished(self, ok: bool) -> None:
        self._loading = False
        pending, self._pending_ready = self._pending_ready, None
        if pending:
            pending()
        self.load_finished.emit(ok)

    def _toggle_picker(self, on: bool) -> None:
        if not self._view:
            return
        self._view.page().runJavaScript(PICKER_JS if on else PICKER_OFF_JS)
        if on:
            self._picker_timer.start()
            self._pick.setText("Seçimi bitir")
        else:
            self._picker_timer.stop()
            self._pick.setText("Element seç")

    def _poll_picker(self) -> None:
        if not self._view:
            return
        self._view.page().runJavaScript("window.__scraperPicked || ''", self._on_picked)

    def _on_picked(self, selector: str) -> None:
        if not selector:
            return
        self._picker_timer.stop()
        self._pick.setChecked(False)
        self._pick.setText("Element seç")
        self.selector_picked.emit(selector)

    def run_after_ready(self, wait_ms: int, auto_scroll: bool, callback) -> None:
        """Sayfa yüklendikten sonra bekle, isteğe bağlı kaydır, HTML callback ile döndür."""
        if not self._view:
            callback("")
            return

        def deliver() -> None:
            if auto_scroll:
                self._view.page().runJavaScript(SCROLL_JS)
                QTimer.singleShot(1600, grab)
            else:
                grab()

        def grab() -> None:
            self._view.page().toHtml(callback)

        def start() -> None:
            QTimer.singleShot(max(0, wait_ms), deliver)

        if self._loading:
            self._pending_ready = start
        else:
            start()

    def get_html_sync_via_callback(self, callback) -> None:
        if not self._view:
            callback("")
            return
        self._view.page().toHtml(callback)

    def count_matches(self, selector: str, callback) -> None:
        if not self._view:
            callback(0)
            return
        sel = json.dumps(selector)
        self._view.page().runJavaScript(f"document.querySelectorAll({sel}).length", callback)
