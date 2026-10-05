from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QPoint, Qt, QThread, QTimer
from PySide6.QtGui import QColor, QKeyEvent, QShortcut, QKeySequence
from PySide6.QtWidgets import QApplication, QGraphicsDropShadowEffect, QMenu, QMessageBox, QVBoxLayout, QWidget

from ui import theme as T
from ui.components import FILTER_CHIPS, ResultRow, SearchPanel
from ui.settings_dialog import SettingsDialog
from utils.actions import (
    IndexCountWorker,
    SearchWorker,
    format_roots_summary,
    open_containing_folder,
    open_file,
)
from utils.file_search import SearchResult, highlight_name, parse_query
from utils.index_backend import get_index_stats
from utils.index_watcher import IndexWatcher
from utils.previews import file_ext_label, format_file_size, load_thumbnail
from utils.search_history import recent_queries
from utils.settings import get_search_roots, snippets_enabled


class SpotlightWindow(QWidget):
    """macOS Spotlight benzeri: tam ekran karartma + üstte yüzen palet."""

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Akıllı Dosya Arama")
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowStaysOnTopHint
            | Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        self._search_roots = get_search_roots()
        self._results: list[SearchResult] = []
        self._selected = 0
        self._search_worker: SearchWorker | None = None
        self._index_worker: IndexCountWorker | None = None
        self._watcher: IndexWatcher | None = None
        self._hiding = False

        self._debounce = QTimer(self)
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(200)
        self._debounce.timeout.connect(self._run_search)

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        screen = QApplication.primaryScreen().availableGeometry()
        top_margin = max(48, int(screen.height() * 0.08))
        root.setContentsMargins(16, top_margin, 16, 24)

        self.panel = SearchPanel()
        self.panel.search_changed.connect(self._on_query_changed)
        self.panel.filter_changed.connect(self._on_filter_changed)
        self.panel.settings_requested.connect(self._open_settings)
        self.panel.search_input.palette_key.connect(self._on_palette_key)
        # Hata rozetindeki "Yeniden dene": rozeti sıfırla, aramayı tekrarla.
        self.panel.index_badge.retry_clicked.connect(self._retry_after_error)
        self._setup_palette_shortcuts()
        shadow = QGraphicsDropShadowEffect(self.panel)
        shadow.setBlurRadius(T.PANEL_SHADOW_BLUR)
        shadow.setOffset(0, T.PANEL_SHADOW_OFFSET_Y)
        shadow.setColor(QColor(0, 0, 0, T.PANEL_SHADOW_ALPHA))
        self.panel.setGraphicsEffect(shadow)
        root.addWidget(self.panel, 0, Qt.AlignmentFlag.AlignHCenter)
        root.addStretch(1)

        self.setStyleSheet(f"SpotlightWindow {{ background-color: {T.OVERLAY_SCRIM}; }}")

        app = QApplication.instance()
        if app:
            app.focusChanged.connect(self._on_focus_changed)

        self._reload_roots()
        self._refresh_index_badge_from_stats(scanning=True)
        self._start_index_count()

    def set_index_watcher(self, watcher: IndexWatcher) -> None:
        self._watcher = watcher

    def on_index_count_changed(self, count: int) -> None:
        label = f"Güncel · {count:,}".replace(",", ".") + " dosya"
        self.panel.set_index_state(label=label, scanning=False)

    def on_index_sync(self, busy: bool) -> None:
        if busy:
            self.panel.set_index_state(label="Senkronize…", scanning=True)
        else:
            self._refresh_index_badge_from_stats(scanning=False)

    def _reload_roots(self) -> None:
        self._search_roots = get_search_roots()
        self.panel.set_roots_summary(format_roots_summary(self._search_roots))

    def _fill_screen(self) -> None:
        screen = QApplication.primaryScreen().availableGeometry()
        self.setGeometry(screen)

    def toggle(self) -> None:
        if self.isVisible():
            self.dismiss()
        else:
            self.present()

    def present(self) -> None:
        self._fill_screen()
        self._reload_roots()
        self.panel.search_input.clear()
        self._results = []
        self._selected = -1
        self.panel.clear_results()
        self.panel.set_empty_message("Aramak için yazmaya başlayın")
        self.panel.set_footer_timing(None)
        self.panel.set_scanning_footer(None)
        self.show()
        self.raise_()
        self.activateWindow()
        self.panel.search_input.setFocus()

    def dismiss(self) -> None:
        self._hiding = True
        self.hide()
        self._hiding = False

    def _on_focus_changed(self, _old: QWidget | None, new: QWidget | None) -> None:
        if self._hiding or not self.isVisible():
            return
        if new is None:
            return
        w = new
        while w is not None:
            if w is self:
                return
            w = w.parentWidget()  # type: ignore[assignment]
        QTimer.singleShot(0, self._hide_if_unfocused)

    def _hide_if_unfocused(self) -> None:
        if not self.isVisible():
            return
        focus = QApplication.focusWidget()
        w = focus
        while w is not None:
            if w is self:
                return
            w = w.parentWidget()  # type: ignore[assignment]
        self.dismiss()

    def mousePressEvent(self, event) -> None:
        w = self.childAt(event.position().toPoint())
        if w is None or not (w is self.panel or self.panel.isAncestorOf(w)):
            self.dismiss()
            return
        super().mousePressEvent(event)

    def _open_settings(self) -> None:
        dlg = SettingsDialog(self)
        if dlg.exec():
            self._reload_roots()
            self._refresh_index_badge_from_stats(scanning=True)
            self._start_index_count()
            if self._watcher is not None:
                self._watcher.restart(self._search_roots)
            self._run_search()

    def _start_index_count(self) -> None:
        if self._index_worker and self._index_worker.isRunning():
            return
        self._refresh_index_badge_from_stats(scanning=True)
        self._index_worker = IndexCountWorker(self._search_roots, self)
        self._index_worker.finished_count.connect(self._on_index_count)
        self._index_worker.start()

    def _on_index_count(self, count: int) -> None:
        label = f"Güncel · {count:,}".replace(",", ".") + " dosya"
        self.panel.set_index_state(label=label, scanning=False)

    def _refresh_index_badge_from_stats(self, *, scanning: bool = False) -> None:
        if scanning:
            self.panel.set_index_state(label="Taranıyor…", scanning=True)
            return
        stats = get_index_stats()
        count = stats.get("count", 0)
        if count > 0:
            label = f"Güncel · {count:,}".replace(",", ".") + " dosya"
        else:
            label = "Hazır"
        self.panel.set_index_state(label=label, scanning=False)

    def _retry_after_error(self) -> None:
        self._refresh_index_badge_from_stats(scanning=False)
        self._run_search()

    def _on_filter_changed(self, _filter_id: str) -> None:
        self._run_search()

    def _on_query_changed(self, _text: str) -> None:
        self._debounce.start()

    def _run_search(self) -> None:
        if not self._search_roots:
            self.panel.set_empty_message(
                "Ayarlardan en az bir arama klasörü ekleyin",
                "Ctrl+, ile indeks ayarlarını açın.",
            )
            self.panel.set_footer_timing(None)
            return

        raw = self.panel.search_input.text().strip()
        parsed = parse_query(raw)
        if not parsed.text and not parsed.extension:
            self._results = []
            self._selected = 0
            self.panel.clear_results()
            self.panel.set_footer_timing(None)
            self.panel.set_scanning_footer(None)
            recent = recent_queries(5)
            self.panel.set_empty_message(
                "Aramak için yazmaya başlayın",
                ("Son aramalar: " + " · ".join(recent) + "  (↑ sonuncuyu getirir)") if recent else None,
            )
            return

        old = self._search_worker
        if old is not None:
            # Eski (yavaş) arama sonradan biterse yeni sonuçları ezmesin.
            try:
                old.finished_search.disconnect(self._on_search_done)
                old.failed.disconnect(self._on_search_failed)
            except (RuntimeError, TypeError):
                pass
            # Her tuşta bir QThread birikmesin (uygulama tepside günlerce çalışır).
            if old.isRunning():
                old.requestInterruption()
                old.finished.connect(old.deleteLater)
            else:
                old.deleteLater()

        self.panel.set_scanning_footer("Aranıyor…")
        file_type = self.panel.active_filter
        self._search_worker = SearchWorker(
            self._search_roots, raw, file_type=file_type, parent=self
        )
        self._search_worker.finished_search.connect(self._on_search_done)
        self._search_worker.failed.connect(self._on_search_failed)
        self._search_worker.start()

    def _on_search_failed(self, message: str) -> None:
        self.panel.set_index_state(label="Arama hatası", error=True)
        self.panel.set_scanning_footer(None)
        self.panel.clear_results()
        self.panel.set_empty_message(
            "Arama tamamlanamadı",
            message or "İndeks servisi yanıt vermedi. Ayarlardan yeniden indekslemeyi deneyin.",
            error=True,
        )

    def _on_search_done(self, results: list, elapsed_ms: int) -> None:
        self._results = results
        self._selected = 0 if results else -1
        self.panel.set_scanning_footer(None)
        self.panel.set_footer_timing(elapsed_ms)

        parsed = parse_query(self.panel.search_input.text())
        show_snippets = snippets_enabled()
        rows: list[ResultRow] = []
        for i, item in enumerate(results):
            thumb = load_thumbnail(item.path) if item.is_image else None
            badge = "içerik" if item.match_kind == "content" else None
            if item.match_kind == "fuzzy":
                badge = "bulanık"
            elif item.match_kind == "everything":
                badge = "EV"
            snippet = item.snippet if show_snippets else None
            row = ResultRow(i)
            row.set_content(
                name_html=highlight_name(item.name, parsed.text),
                path=item.display_path,
                snippet=snippet,
                ext_label=file_ext_label(item.path.suffix),
                thumbnail=thumb,
                match_badge=badge,
                meta=format_file_size(item.path),
            )
            row.set_selected(i == 0)
            row.activated.connect(self._select_row)
            row.open_requested.connect(self._open_result_at)
            row.menu_requested.connect(self._show_result_menu)
            rows.append(row)
        self.panel.set_results(rows)
        if rows:
            self._scroll_to_selected()

    def _on_palette_key(self, event: QKeyEvent) -> None:
        key = event.key()
        mods = event.modifiers() & ~Qt.KeyboardModifier.KeypadModifier

        if key == Qt.Key.Key_Down:
            self._nav_down()
        elif key == Qt.Key.Key_Up:
            self._nav_up()
        elif key in (Qt.Key.Key_Return, Qt.Key.Key_Enter):
            if mods & Qt.KeyboardModifier.ControlModifier:
                self._activate_selection(folder=True)
            else:
                self._activate_selection(folder=False)
        elif key == Qt.Key.Key_Escape:
            self._on_escape_key()
        elif key == Qt.Key.Key_Comma and mods & Qt.KeyboardModifier.ControlModifier:
            self._open_settings()

    def _setup_palette_shortcuts(self) -> None:
        ctx = Qt.ShortcutContext.WidgetWithChildrenShortcut
        parent = self.panel

        def bind(keys: str | QKeySequence, slot) -> None:
            seq = QKeySequence(keys) if isinstance(keys, str) else keys
            sc = QShortcut(seq, parent)
            sc.setContext(ctx)
            sc.activated.connect(slot)

        bind(QKeySequence(Qt.Key.Key_Down), self._nav_down)
        bind(QKeySequence(Qt.Key.Key_Up), self._nav_up)
        bind(QKeySequence(Qt.Key.Key_Return), lambda: self._activate_selection(folder=False))
        bind(QKeySequence(Qt.Key.Key_Enter), lambda: self._activate_selection(folder=False))
        bind("Ctrl+Return", lambda: self._activate_selection(folder=True))
        bind("Ctrl+Enter", lambda: self._activate_selection(folder=True))
        bind(QKeySequence(Qt.Key.Key_Escape), self._on_escape_key)
        bind("Ctrl+,", self._open_settings)
        bind("Ctrl+Shift+C", self._copy_selected_path)
        for n, (fid, _label) in enumerate(FILTER_CHIPS, start=1):
            bind(f"Ctrl+{n}", lambda f=fid: self.panel._set_filter(f))

    def _result_menu(self, index: int) -> QMenu:
        """Sonuç satırı sağ tık menüsü (fareyle de klavye eylemlerine erişim)."""
        self._select_row(index)
        menu = QMenu(self)
        menu.addAction("Aç\tEnter", lambda: self._activate_selection(folder=False))
        menu.addAction("Klasörde göster\tCtrl+Enter", lambda: self._activate_selection(folder=True))
        menu.addAction("Yolu kopyala\tCtrl+Shift+C", self._copy_selected_path)
        return menu

    def _show_result_menu(self, index: int, global_pos: QPoint) -> None:
        self._result_menu(index).exec(global_pos)

    def _on_escape_key(self) -> None:
        if self.panel.search_input.text().strip():
            self.panel.search_input.clear()
            self._run_search()
        else:
            self.dismiss()

    def _nav_down(self) -> None:
        if not self.panel._result_rows:
            return
        start = self._selected if self._selected >= 0 else -1
        self._select_row(min(start + 1, len(self.panel._result_rows) - 1))
        self._scroll_to_selected()

    def _nav_up(self) -> None:
        if not self.panel._result_rows:
            # Boş kutuda ↑: son aramayı geri getir.
            if not self.panel.search_input.text().strip():
                recent = recent_queries(1)
                if recent:
                    self.panel.search_input.setText(recent[0])
                    self.panel.search_input.end(False)
            return
        start = self._selected if self._selected >= 0 else 0
        self._select_row(max(start - 1, 0))
        self._scroll_to_selected()

    def _scroll_to_selected(self) -> None:
        if self._selected < 0 or self._selected >= len(self.panel._result_rows):
            return
        row = self.panel._result_rows[self._selected]
        self.panel._results_scroll.ensureWidgetVisible(row, 12, 12)

    def _open_result_at(self, index: int) -> None:
        self._select_row(index)
        self._activate_selection(folder=False)

    def _select_row(self, index: int) -> None:
        self._selected = index
        for i, row in enumerate(self.panel._result_rows):
            row.set_selected(i == index)
        self._scroll_to_selected()

    def _activate_selection(self, *, folder: bool = False) -> None:
        if self._selected < 0 or self._selected >= len(self._results):
            return
        path = str(self._results[self._selected].path)
        self.dismiss()
        try:
            if folder:
                open_containing_folder(path)
            else:
                open_file(path)
        except OSError as exc:  # silinmiş/taşınmış dosya veya ilişkilendirilmemiş uzantı
            QMessageBox.warning(None, "Açılamadı", f"{path}\n\n{exc.strerror or exc}")

    def _copy_selected_path(self) -> None:
        if 0 <= self._selected < len(self._results):
            path = str(self._results[self._selected].path)
            QApplication.clipboard().setText(path)
            self.panel.result_count_label.setText("Yol kopyalandı")
            # Bağlam nesnesi: pencere kapanırsa zamanlayıcı silinmiş etikete dokunmaz.
            QTimer.singleShot(1500, self.panel, self._restore_result_count)

    def _restore_result_count(self) -> None:
        if self.panel.result_count_label.text() == "Yol kopyalandı":
            self.panel.set_result_count(len(self._results))

    def keyPressEvent(self, event: QKeyEvent) -> None:
        super().keyPressEvent(event)

    def shutdown(self) -> None:
        """Uygulama kapanırken arka plan thread'lerini güvenle durdur.

        Yerine yenisi başlatılan (sinyali kesilmiş) eski aramalar da hâlâ çalışıyor olabilir;
        hepsi beklenmezse pencere silinirken "QThread destroyed while running" ile süreç çöker.
        """
        self._debounce.stop()
        for worker in self.findChildren(QThread):
            worker.requestInterruption()
        for worker in self.findChildren(QThread):
            worker.wait(5000)

