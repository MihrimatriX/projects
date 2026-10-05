from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QAction, QDragEnterEvent, QDropEvent, QKeySequence
from PySide6.QtWidgets import (
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMenu,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QSplitter,
    QVBoxLayout,
    QWidget,
)

from core.app_info import APP_NAME
from core.macro import load_macro, load_last_rules, save_last_rules, save_macro
from core.models import PreviewStatus, path_key
from core.rename_ops import (
    apply_renames,
    collect_from_folder,
    export_preview_csv,
    export_preview_json,
    reveal_in_explorer,
)
from core.rules_engine import can_apply, compute_preview, filter_rows, preview_stats
from core.rules_io import export_rules_json, import_rules_json
from core.settings import SettingsStore, data_dir
from core.undo_stack import UndoStack
from ui.dialogs.about_dialog import AboutDialog
from ui.dialogs.help_dialog import HelpDialog
from ui.dialogs.settings_dialog import SettingsDialog
from ui.styles import get_app_style
from ui.widget_utils import configure_overlay
from ui.widgets.app_toolbar import AppToolbar
from ui.widgets.preview_table import PreviewTable
from ui.widgets.rules_panel import RulesPanel
from ui.workers.preview_worker import PreviewWorker


class PreviewStack(QWidget):
    """Önizleme tablosu, boş durum ve sürükle-bırak ipucu."""

    def __init__(self, on_add_files, on_pick_folder) -> None:
        super().__init__()
        self._drag_depth = 0
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        self._container = QWidget()
        container_layout = QVBoxLayout(self._container)
        container_layout.setContentsMargins(0, 0, 0, 0)

        self.table = PreviewTable()
        container_layout.addWidget(self.table, stretch=1)

        self.empty_pane = QWidget()
        empty_layout = QVBoxLayout(self.empty_pane)
        empty_layout.setContentsMargins(0, 0, 0, 0)
        empty_layout.addStretch()
        hint = QLabel(
            "Dosya sürükleyin veya klasör seçin.\n"
            "Kurallar uygulanmadan önce canlı önizleme gösterilir."
        )
        hint.setObjectName("EmptyHint")
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        hint.setWordWrap(True)
        empty_layout.addWidget(hint)
        add_btn = QPushButton("Dosya Ekle…")
        add_btn.setObjectName("ToolbarButton")
        add_btn.clicked.connect(on_add_files)
        folder_btn = QPushButton("Klasör Seç…")
        folder_btn.setObjectName("ToolbarButton")
        folder_btn.clicked.connect(on_pick_folder)
        self.add_btn, self.folder_btn = add_btn, folder_btn
        btn_row = QHBoxLayout()
        btn_row.addStretch()
        btn_row.addWidget(add_btn)
        btn_row.addWidget(folder_btn)
        btn_row.addStretch()
        empty_layout.addLayout(btn_row)
        empty_layout.addStretch()
        container_layout.addWidget(self.empty_pane, stretch=1)
        self.empty_pane.hide()

        self.drop_overlay = QFrame(self._container)
        self.drop_overlay.setObjectName("DropOverlay")
        configure_overlay(self.drop_overlay)
        overlay_layout = QVBoxLayout(self.drop_overlay)
        overlay_layout.setContentsMargins(0, 0, 0, 0)
        self.drop_hint = QLabel("↓  Dosyaları buraya bırakın")
        self.drop_hint.setObjectName("DropHint")
        self.drop_hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        overlay_layout.addWidget(self.drop_hint)
        self.drop_overlay.hide()

        layout.addWidget(self._container, stretch=1)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        if hasattr(self, "drop_overlay") and self._container:
            self.drop_overlay.setGeometry(self._container.rect())

    @property
    def preview_table(self) -> PreviewTable:
        return self.table

    def show_empty(self, empty: bool) -> None:
        self.table.setVisible(not empty)
        self.empty_pane.setVisible(empty)
        self.drop_overlay.hide()
        self._drag_depth = 0

    def set_drag_active(self, active: bool) -> None:
        if active:
            self._drag_depth += 1
            self.drop_overlay.setGeometry(self._container.rect())
            self.drop_overlay.show()
        else:
            self._drag_depth = max(0, self._drag_depth - 1)
            if self._drag_depth == 0:
                self.drop_overlay.hide()


class DropZone(QWidget):
    def __init__(self, on_files, preview_stack: PreviewStack) -> None:
        super().__init__()
        self._on_files = on_files
        self._preview_stack = preview_stack
        self.setAcceptDrops(True)

    def dragEnterEvent(self, event: QDragEnterEvent) -> None:
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            self._preview_stack.set_drag_active(True)

    def dragLeaveEvent(self, event) -> None:
        self._preview_stack.set_drag_active(False)

    def dropEvent(self, event: QDropEvent) -> None:
        self._preview_stack.set_drag_active(False)
        paths = [Path(u.toLocalFile()) for u in event.mimeData().urls()]
        self._on_files(paths)
        event.acceptProposedAction()


class MainWindow(QMainWindow):
    NARROW_BREAKPOINT = 900

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle(APP_NAME)
        self.setMinimumSize(800, 500)
        self._settings = SettingsStore.instance()
        self._theme = self._settings.settings.theme
        self.setStyleSheet(get_app_style(self._theme))
        self._files: list[Path] = []
        self._folder: Path | None = None
        self._undo_stack = UndoStack(
            self._settings.settings.undo_stack_max, path=data_dir() / "undo_history.json"
        )
        self._preview_worker: PreviewWorker | None = None
        self._all_preview_rows: list = []
        self._conflicts_only = False
        self._search = ""
        self._narrow_layout = False
        self._debounce = QTimer(self)
        self._debounce.setSingleShot(True)
        self._debounce.setInterval(150)
        self._debounce.timeout.connect(self._refresh_preview)

        self.resize(self._settings.settings.window_width, self._settings.settings.window_height)

        self.preview_stack = PreviewStack(self._pick_files, self._pick_folder)
        central = DropZone(self._ingest_paths, self.preview_stack)
        central.setObjectName("CentralWidget")
        root = QVBoxLayout(central)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        root.setSpacing(0)

        self.toolbar = AppToolbar("🌙" if self._theme == "dark" else "☀")
        self.toolbar.add_files.connect(self._pick_files)
        self.toolbar.undo.connect(self._undo_last)
        self.toolbar.redo.connect(self._redo_last)
        self.toolbar.set_undo_enabled(self._undo_stack.can_undo())  # kalıcı geçmiş
        self.toolbar.macro_save.connect(self._save_macro)
        self.toolbar.macro_run.connect(self._load_macro)
        self.toolbar.theme_toggle.connect(self._toggle_theme)
        self.toolbar.apply.connect(self._apply)
        self.apply_btn = self.toolbar.apply_button
        root.addWidget(self.toolbar)

        self._splitter = QSplitter(Qt.Orientation.Horizontal)
        self._splitter.setChildrenCollapsible(False)
        self._splitter.setHandleWidth(1)

        self.rules_panel = RulesPanel()
        saved = load_last_rules()
        if saved:
            self.rules_panel.set_rules(saved)
        self.rules_panel.rules_changed.connect(self._on_rules_changed)
        self._splitter.addWidget(self.rules_panel)

        preview_pane = QFrame()
        preview_pane.setObjectName("PreviewPane")
        preview_wrap = QVBoxLayout(preview_pane)
        preview_wrap.setContentsMargins(0, 0, 0, 0)
        preview_wrap.setSpacing(0)

        header = QFrame()
        header.setObjectName("PreviewHeader")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(16, 12, 16, 12)
        header_layout.setSpacing(12)
        title = QLabel("Önizleme")
        title.setObjectName("PreviewTitle")
        header_layout.addWidget(title)

        stats = QHBoxLayout()
        stats.setSpacing(12)
        self.stat_valid = QLabel("")
        self.stat_valid.setObjectName("StatValid")
        self.stat_conflict = QLabel("")
        self.stat_conflict.setObjectName("StatConflict")
        stats.addWidget(self.stat_valid)
        stats.addWidget(self.stat_conflict)
        header_layout.addLayout(stats)
        header_layout.addStretch()

        self.search_edit = QLineEdit()
        self.search_edit.setPlaceholderText("Ara… (Ctrl+F)")
        self.search_edit.setAccessibleName("Önizlemede ara")
        self.search_edit.setClearButtonEnabled(True)
        self.search_edit.setMaximumWidth(200)
        self.search_edit.textChanged.connect(self._on_search)
        header_layout.addWidget(self.search_edit)

        self.conflict_filter_btn = QPushButton("Çakışmalar")
        self.conflict_filter_btn.setObjectName("GhostTextButton")
        self.conflict_filter_btn.setCheckable(True)
        self.conflict_filter_btn.setEnabled(False)
        self.conflict_filter_btn.setToolTip("Yalnızca çakışan dosyaları göster")
        self.conflict_filter_btn.clicked.connect(self._toggle_conflict_filter)
        header_layout.addWidget(self.conflict_filter_btn)

        csv_btn = QPushButton("CSV")
        csv_btn.setObjectName("GhostTextButton")
        csv_btn.setToolTip("Önizlemeyi CSV olarak dışa aktar")
        csv_btn.clicked.connect(self._export_csv)
        header_layout.addWidget(csv_btn)
        json_btn = QPushButton("JSON")
        json_btn.setObjectName("GhostTextButton")
        json_btn.setToolTip("Önizlemeyi JSON olarak dışa aktar")
        json_btn.clicked.connect(self._export_json)
        header_layout.addWidget(json_btn)
        preview_wrap.addWidget(header)

        progress_row = QFrame()
        progress_row.setObjectName("ProgressRow")
        progress_layout = QHBoxLayout(progress_row)
        progress_layout.setContentsMargins(16, 8, 16, 8)
        progress_layout.setSpacing(10)
        self.progress = QProgressBar()
        self.progress.setTextVisible(False)
        self.progress.setMaximum(100)
        self.progress.setFixedHeight(4)
        self.progress_label = QLabel("")
        self.progress_label.setObjectName("StatMuted")
        self.progress_label.setMinimumWidth(72)
        progress_layout.addWidget(self.progress, stretch=1)
        progress_layout.addWidget(self.progress_label)
        self.cancel_preview_btn = QPushButton("Önizleme İptal")
        self.cancel_preview_btn.setObjectName("GhostDangerButton")
        self.cancel_preview_btn.clicked.connect(self._cancel_async_preview)
        progress_layout.addWidget(self.cancel_preview_btn)
        progress_row.hide()
        self._progress_row = progress_row
        preview_wrap.addWidget(progress_row)

        preview_wrap.addWidget(self.preview_stack, stretch=1)

        footer = QFrame()
        footer.setObjectName("PreviewFooter")
        footer_layout = QHBoxLayout(footer)
        footer_layout.setContentsMargins(16, 10, 16, 10)
        footer_layout.setSpacing(12)
        self.path_label = QLabel("Dosya seçilmedi")
        self.path_label.setObjectName("PathLabel")
        self.path_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
        shortcuts = QLabel(
            "Ctrl+Z / Ctrl+Y Geri al / Yinele · Del Listeden çıkar · F1 Yardım"
        )
        shortcuts.setObjectName("ShortcutLabel")
        shortcuts.setAlignment(Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter)
        footer_layout.addWidget(self.path_label, stretch=1)
        footer_layout.addWidget(shortcuts, stretch=1)
        preview_wrap.addWidget(footer)

        self._splitter.addWidget(preview_pane)
        self._splitter.setStretchFactor(0, 0)
        self._splitter.setStretchFactor(1, 1)
        self._splitter.setSizes([360, max(440, self.width() - 360)])

        root.addWidget(self._splitter, stretch=1)

        self.setCentralWidget(central)
        self.menuBar().setVisible(False)
        self._app_menu = self._build_menu()
        self.toolbar.set_menu(self._app_menu)

        self.preview_stack.preview_table.setContextMenuPolicy(
            Qt.ContextMenuPolicy.CustomContextMenu
        )
        self.preview_stack.preview_table.customContextMenuRequested.connect(
            self._preview_context_menu
        )

        self.preview_stack.preview_table.set_theme(self._theme)
        self._schedule_preview()
        if self._settings.settings.show_welcome:
            QTimer.singleShot(0, self._show_welcome)

    def resizeEvent(self, event) -> None:
        super().resizeEvent(event)
        narrow = self.width() < self.NARROW_BREAKPOINT
        if narrow == self._narrow_layout:
            return
        self._narrow_layout = narrow
        orientation = (
            Qt.Orientation.Vertical if narrow else Qt.Orientation.Horizontal
        )
        self._splitter.setOrientation(orientation)
        if narrow:
            h = max(self.height(), 500)
            self._splitter.setSizes([int(h * 0.42), int(h * 0.58)])
        else:
            self._splitter.setSizes([360, max(440, self.width() - 360)])

    def _status_message(self, text: str) -> None:
        self.path_label.setText(text)

    def _apply_theme(self, theme: str) -> None:
        self._theme = theme
        self.setStyleSheet(get_app_style(theme))
        self.preview_stack.preview_table.set_theme(theme)
        if self._all_preview_rows:
            self._update_table_display()

    def _toggle_theme(self) -> None:
        next_theme = "light" if self._theme == "dark" else "dark"
        self._settings.settings.theme = next_theme
        self._settings.save()
        self._apply_theme(next_theme)
        self.toolbar.set_theme_icon("☀" if next_theme == "light" else "🌙")

    def _show_welcome(self) -> None:
        from ui.dialogs.welcome_dialog import WelcomeDialog

        dlg = WelcomeDialog(self)
        dlg.setWindowModality(Qt.WindowModality.ApplicationModal)
        dlg.exec()
        if dlg.skip_next_time():
            self._settings.settings.show_welcome = False
            self._settings.save()

    def _build_menu(self) -> QMenu:
        """Menü çubuğu gizli; eylemler ☰ menüsünde. Kısayollar pencereye de eklenir
        (gizli menüdeki eylemlerin kısayolları aksi halde tetiklenmez)."""
        menu = QMenu(self)

        def add(sub: QMenu, text: str, slot, *keys: str) -> QAction:
            action = sub.addAction(text)
            action.triggered.connect(lambda _=False: slot())
            if keys:
                action.setShortcuts([QKeySequence(k) for k in keys])
                self.addAction(action)
            return action

        file_menu = menu.addMenu("Dosya")
        add(file_menu, "Dosya Ekle…", self._pick_files, "Ctrl+O")
        add(file_menu, "Klasör Seç…", self._pick_folder, "Ctrl+Shift+O")
        add(file_menu, "Listeyi Temizle", self._clear_files)
        file_menu.addSeparator()
        add(file_menu, "CSV Dışa Aktar…", self._export_csv, "Ctrl+E")
        add(file_menu, "JSON Dışa Aktar…", self._export_json, "Ctrl+Shift+E")
        add(file_menu, "Kuralları JSON Kaydet…", self._export_rules)
        add(file_menu, "Kuralları JSON Yükle…", self._import_rules)
        file_menu.addSeparator()
        add(file_menu, "Çıkış", self.close, "Ctrl+Q")

        edit_menu = menu.addMenu("Düzen")
        self.undo_action = add(edit_menu, "Geri Al", self._undo_last, "Ctrl+Z")
        self.redo_action = add(edit_menu, "Yinele", self._redo_last, "Ctrl+Y", "Ctrl+Shift+Z")
        add(edit_menu, "Listeden Çıkar", self._remove_selected_files, "Delete")
        add(edit_menu, "Önizlemede Ara", self._focus_search, "Ctrl+F")
        edit_menu.addSeparator()
        add(edit_menu, "Uygula…", self._apply, "Ctrl+Return", "Ctrl+Enter")
        add(edit_menu, "Onaysız Uygula", self._apply_quick, "Ctrl+Shift+Return", "Ctrl+Shift+Enter")
        edit_menu.addSeparator()
        add(edit_menu, "Makro Kaydet", self._save_macro, "Ctrl+Shift+S")
        add(edit_menu, "Makro Çalıştır", self._load_macro, "Ctrl+Shift+R")

        view_menu = menu.addMenu("Görünüm")
        add(view_menu, "Tema Değiştir", self._toggle_theme, "Ctrl+T")

        help_menu = menu.addMenu("Yardım")
        add(help_menu, "Kullanım", lambda: HelpDialog(self).exec(), "F1")
        add(help_menu, "Ayarlar…", self._open_settings, "Ctrl+,")
        add(help_menu, "Hoş geldin", self._show_welcome)
        add(help_menu, "Hakkında", lambda: AboutDialog(self).exec())
        return menu

    def _focus_search(self) -> None:
        self.search_edit.setFocus()
        self.search_edit.selectAll()

    def _on_search(self, text: str) -> None:
        self._search = text
        self._update_table_display()

    def _visible_rows(self) -> list:
        """Tabloda görünen satırlar (ayar filtresi + çakışma filtresi + arama)."""
        return filter_rows(
            self._all_preview_rows,
            changed_only=self._settings.settings.filter_changed_only,
            conflicts_only=self._conflicts_only,
            search_text=self._search,
        )

    def _update_undo_buttons(self) -> None:
        self.toolbar.set_undo_enabled(self._undo_stack.can_undo())
        self.toolbar.set_redo_enabled(self._undo_stack.can_redo())

    def _open_settings(self) -> None:
        dlg = SettingsDialog(self)
        if dlg.exec():
            dlg.apply()
            # Yığını yeniden oluşturmak geri alma geçmişini siler; yalnızca sınırı güncelle.
            self._undo_stack._max_size = max(1, self._settings.settings.undo_stack_max)
            self._apply_theme(self._settings.settings.theme)
            self.toolbar.set_theme_icon("☀" if self._theme == "light" else "🌙")
            if self._folder:
                self._reload_folder()
            self._update_table_display()

    def closeEvent(self, event) -> None:
        # Çalışan QThread çıkışta yok edilirse süreç çöker; önce durdur.
        if self._preview_worker and self._preview_worker.isRunning():
            self._preview_worker.cancel()
            self._preview_worker.wait(2000)
        save_last_rules(self.rules_panel.rules)
        self._settings.settings.window_width = self.width()
        self._settings.settings.window_height = self.height()
        if self._folder:
            self._settings.settings.last_folder = str(self._folder)
        self._settings.save()
        super().closeEvent(event)

    def _on_rules_changed(self) -> None:
        self._schedule_preview()

    def _toggle_conflict_filter(self) -> None:
        self._conflicts_only = self.conflict_filter_btn.isChecked()
        self._update_table_display()

    def _pick_files(self) -> None:
        paths, _ = QFileDialog.getOpenFileNames(self, "Dosya seç")
        self._ingest_paths([Path(p) for p in paths])

    def _pick_folder(self) -> None:
        start = self._settings.settings.last_folder or ""
        folder = QFileDialog.getExistingDirectory(self, "Klasör seç", start)
        if folder:
            self._load_folder(Path(folder))

    def _reload_folder(self) -> None:
        if not self._folder:
            return
        self._files = collect_from_folder(
            self._folder,
            recursive=self._settings.settings.recursive,
            include_hidden=self._settings.settings.include_hidden,
        )
        self._dedupe_files()
        self._update_path_label()
        self._schedule_preview()

    def _load_folder(self, folder: Path) -> None:
        self._folder = folder
        self._settings.settings.last_folder = str(folder)
        self._reload_folder()

    def _ingest_paths(self, paths: list[Path]) -> None:
        added = 0
        for p in paths:
            if p.is_dir():
                self._load_folder(p)
                added = len(self._files)
                break
            if p.is_file():
                # Tek tek eklenen dosyalarda _folder atanmaz: geri al/ayarlar sonrası tüm klasör
                # yeniden yüklenip kullanıcının seçmediği dosyalar listeye giriyordu.
                if p not in self._files:
                    self._files.append(p)
                    added += 1
        if added:
            self._dedupe_files()
            self._update_path_label()
            self._schedule_preview()

    def _clear_files(self) -> None:
        self._files.clear()
        self._folder = None
        self._conflicts_only = False
        self.conflict_filter_btn.setChecked(False)
        self._update_path_label()
        self._schedule_preview()

    def _update_path_label(self) -> None:
        if not self._files:
            self.path_label.setText("Dosya seçilmedi")
            return
        parents = {f.parent for f in self._files}
        if self._folder:
            folder_text = str(self._folder)
        elif len(parents) == 1:
            folder_text = str(next(iter(parents)))
        else:
            folder_text = f"{len(parents)} klasör"
        text = f"{len(self._files)} dosya · {folder_text}"
        self.path_label.setText(self.fontMetrics().elidedText(
            text, Qt.TextElideMode.ElideMiddle, max(200, self.path_label.width() or 420)
        ))
        self.path_label.setToolTip(text)

    def _schedule_preview(self) -> None:
        self._debounce.start()

    def _dedupe_files(self) -> None:
        seen: set = set()
        unique: list[Path] = []
        for path in self._files:
            key = path.resolve()
            if key not in seen:
                seen.add(key)
                unique.append(path)
        self._files = unique

    def _refresh_preview(self) -> None:
        if not self._files:
            self.preview_stack.show_empty(True)
            self.preview_stack.preview_table.setRowCount(0)
            self.stat_valid.setText("")
            self.stat_conflict.setText("")
            self.apply_btn.setEnabled(False)
            self.apply_btn.setText("Dosya Yok")
            self._all_preview_rows = []
            self._hide_progress()
            self.conflict_filter_btn.setEnabled(False)
            return

        self.preview_stack.show_empty(False)
        threshold = self._settings.settings.preview_async_threshold
        if len(self._files) >= threshold:
            self._start_async_preview()
            return

        rows, err = compute_preview(
            self._files,
            self.rules_panel.rules,
            exif_mtime_fallback_default=self._settings.settings.exif_mtime_fallback_default,
        )
        self._apply_preview_result(rows, err)

    def _show_progress(self, total: int) -> None:
        self._progress_row.show()
        self.progress.setMaximum(max(1, total))
        self.progress.setValue(0)
        self.progress_label.setText(f"0 / {total}")

    def _hide_progress(self) -> None:
        self._progress_row.hide()
        self.progress.setValue(0)

    def _start_async_preview(self) -> None:
        if self._preview_worker and self._preview_worker.isRunning():
            self._preview_worker.cancel()
            self._preview_worker.wait(2000)
        total = len(self._files)
        self._show_progress(total)
        self._status_message(f"Önizleme hesaplanıyor (0/{total})…")
        self._preview_worker = PreviewWorker(
            list(self._files),
            list(self.rules_panel.rules),
            exif_mtime_fallback_default=self._settings.settings.exif_mtime_fallback_default,
        )
        self._preview_worker.progress.connect(self._on_preview_progress)
        self._preview_worker.finished.connect(self._on_async_preview_done)
        self._preview_worker.start()

    def _on_preview_progress(self, done: int, total: int) -> None:
        self.progress.setMaximum(max(1, total))
        self.progress.setValue(done)
        self.progress_label.setText(f"{done} / {total}")
        self._status_message(f"Önizleme hesaplanıyor ({done}/{total})…")

    def _cancel_async_preview(self) -> None:
        if self._preview_worker and self._preview_worker.isRunning():
            self._preview_worker.cancel()
        self._hide_progress()
        self._status_message("Önizleme iptal edildi")

    def _on_async_preview_done(self, rows, err) -> None:
        self._hide_progress()
        if err == "Önizleme iptal edildi":
            self._status_message(err)
            return
        self._apply_preview_result(rows, err)

    def _apply_preview_result(self, rows, err) -> None:
        self._all_preview_rows = rows

        if err and self.rules_panel._cards:
            self.rules_panel._cards[0].show_regex_error(err)
        elif self.rules_panel._cards:
            self.rules_panel._cards[0].show_regex_error(None)

        valid, conflicts, _, _ = preview_stats(self._all_preview_rows)
        self.stat_valid.setText(f"✓ {valid} geçerli")
        self.stat_conflict.setText(f"⚠ {conflicts} çakışma" if conflicts else "")
        self.conflict_filter_btn.setEnabled(conflicts > 0)
        if conflicts == 0:
            self._conflicts_only = False
            self.conflict_filter_btn.setChecked(False)

        apply_count = sum(1 for r in self._all_preview_rows if r.status == PreviewStatus.OK)
        self.apply_btn.setText(
            f"{apply_count} Dosyayı Uygula" if apply_count else "Uygula"
        )
        self.apply_btn.setEnabled(can_apply(self._all_preview_rows))
        self._update_table_display()

        if not err:
            undo_hint = (
                f" · Geri al: {self._undo_stack.depth()}" if self._undo_stack.depth() else ""
            )
            self._status_message(f"{len(self._files)} dosya önizlendi{undo_hint}")

    def _update_table_display(self) -> None:
        self.preview_stack.preview_table.set_rows(self._visible_rows())

    def _apply_quick(self) -> None:
        if can_apply(self._all_preview_rows):
            self._apply(skip_confirm=True)

    def _apply(self, skip_confirm: bool = False) -> None:
        if not can_apply(self._all_preview_rows):
            QMessageBox.warning(
                self, "Uygulanamaz", "Çakışma veya hata giderilmeden uygulanamaz."
            )
            return

        count = sum(1 for r in self._all_preview_rows if r.status == PreviewStatus.OK)
        if not skip_confirm:
            answer = QMessageBox.question(
                self,
                "Yeniden adlandır",
                f"{count} dosya yeniden adlandırılsın mı?\n\nGeri al: Ctrl+Z",
            )
            if answer != QMessageBox.StandardButton.Yes:
                return

        try:
            record = apply_renames(self._all_preview_rows)
            self._undo_stack.push(record)
            self._update_undo_buttons()
        except OSError as exc:
            QMessageBox.critical(self, "Hata", str(exc))
            self._schedule_preview()  # diskteki güncel durumu yeniden göster
            return
        count = len(record.moves)

        save_macro(self.rules_panel.rules)
        self._rebuild_paths_after_apply()
        self._status_message(f"{count} dosya yeniden adlandırıldı")
        if not skip_confirm:
            QMessageBox.information(self, "Tamam", f"{count} dosya yeniden adlandırıldı.")
        self._schedule_preview()

    def _rebuild_paths_after_apply(self) -> None:
        updated: list[Path] = []
        for row in self._all_preview_rows:
            if row.status == PreviewStatus.OK:
                updated.append(row.path.parent / row.new_name)
            else:
                updated.append(row.path)
        self._files = updated

    def _undo_last(self) -> None:
        if not self._undo_stack.can_undo():
            self._status_message("Geri alınacak işlem yok")
            return
        try:
            n, restored = self._undo_stack.undo()
        except OSError as exc:
            # RenameError: hiçbir dosya değişmedi, adım yığında duruyor.
            QMessageBox.warning(self, "Geri alınamadı", str(exc))
            return
        self._after_history_step(restored)
        depth = self._undo_stack.depth()
        extra = f" ({depth} adım kaldı)" if depth else ""
        self._status_message(f"{n} dosya geri alındı{extra} · Ctrl+Y yinele")

    def _redo_last(self) -> None:
        if not self._undo_stack.can_redo():
            self._status_message("Yinelenecek işlem yok")
            return
        try:
            n, renamed = self._undo_stack.redo()
        except OSError as exc:
            QMessageBox.warning(self, "Yinelenemedi", str(exc))
            return
        self._after_history_step(renamed)
        self._status_message(f"{n} dosya yeniden adlandırıldı (yinele)")

    def _after_history_step(self, fallback: list) -> None:
        """Geri al / yinele sonrası listedeki yolları yeni adlara eşler."""
        self._update_undo_buttons()
        if self._folder:
            self._reload_folder()
        else:
            mapping = {path_key(a): b for a, b in self._undo_stack.last_moves}
            self._files = [mapping.get(path_key(f), f) for f in self._files] or list(fallback)
            self._dedupe_files()
            self._update_path_label()
        self._schedule_preview()

    def _remove_selected_files(self) -> None:
        table = self.preview_stack.preview_table
        indexes = table.selectionModel().selectedRows()
        if not indexes:
            return
        visible = self._visible_rows()
        remove_paths = {
            visible[idx.row()].path for idx in indexes if idx.row() < len(visible)
        }
        if not remove_paths:
            return
        self._files = [f for f in self._files if f not in remove_paths]
        if not self._files:
            self._folder = None
        self._update_path_label()
        self._schedule_preview()
        self._status_message(f"{len(remove_paths)} dosya listeden çıkarıldı")

    def _save_macro(self) -> None:
        save_macro(self.rules_panel.rules)
        self._status_message("Makro kaydedildi (Ctrl+Shift+R ile çalıştır)")

    def _load_macro(self) -> None:
        rules = load_macro()
        if not rules:
            QMessageBox.information(
                self,
                "Makro",
                "Kayıtlı makro yok. Önce Makro Kaydet veya bir işlem uygulayın.",
            )
            return
        self.rules_panel.set_rules(rules)
        self._status_message("Makro çalıştırıldı")
        self._schedule_preview()

    def _export_rules(self) -> None:
        path, _ = QFileDialog.getSaveFileName(
            self, "Kuralları kaydet", "kurallar.json", "JSON (*.json)"
        )
        if not path:
            return
        try:
            export_rules_json(self.rules_panel.rules, Path(path))
            self._status_message(f"Kurallar kaydedildi: {path}")
        except OSError as exc:
            QMessageBox.critical(self, "Hata", str(exc))

    def _import_rules(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Kuralları yükle", "", "JSON (*.json)")
        if not path:
            return
        try:
            rules = import_rules_json(Path(path))
            self.rules_panel.set_rules(rules)
            self._status_message("Kurallar yüklendi")
            self._schedule_preview()
        except (OSError, ValueError, KeyError) as exc:
            QMessageBox.critical(self, "Hata", str(exc))

    def _export_csv(self) -> None:
        if not self._all_preview_rows:
            QMessageBox.information(self, "CSV", "Önce dosya ekleyin.")
            return
        path, _ = QFileDialog.getSaveFileName(
            self, "Önizleme CSV", "onizleme.csv", "CSV (*.csv)"
        )
        if not path:
            return
        export_preview_csv(self._all_preview_rows, Path(path))
        self._status_message("CSV dışa aktarıldı")

    def _export_json(self) -> None:
        if not self._all_preview_rows:
            QMessageBox.information(self, "JSON", "Önce dosya ekleyin.")
            return
        path, _ = QFileDialog.getSaveFileName(
            self, "Önizleme JSON", "onizleme.json", "JSON (*.json)"
        )
        if not path:
            return
        export_preview_json(self._all_preview_rows, Path(path))
        self._status_message("JSON dışa aktarıldı")

    def _preview_context_menu(self, pos) -> None:
        table = self.preview_stack.preview_table
        row_idx = table.rowAt(pos.y())  # imlecin altındaki satır (önceden "geçerli" satır kullanılıyordu)
        visible = self._visible_rows()
        if row_idx < 0 or row_idx >= len(visible):
            return
        if not table.selectionModel().isRowSelected(row_idx):
            table.selectRow(row_idx)
        row = visible[row_idx]
        menu = QMenu(self)
        menu.addAction("Explorer'da göster", lambda: reveal_in_explorer(row.path))
        menu.addAction("Listeden çıkar", self._remove_selected_files)
        menu.exec(table.viewport().mapToGlobal(pos))
