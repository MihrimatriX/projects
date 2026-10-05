from __future__ import annotations

import time
from pathlib import Path

from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import QAction, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QComboBox,
    QDialog,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QListWidget,
    QMainWindow,
    QMenu,
    QMenuBar,
    QMessageBox,
    QPushButton,
    QStackedWidget,
    QStatusBar,
    QSystemTrayIcon,
    QVBoxLayout,
    QWidget,
)

from ui.dialogs.about_dialog import AboutDialog
from ui.dialogs.delete_confirm_dialog import DeleteConfirmDialog
from ui.dialogs.group_detail_dialog import GroupDetailDialog
from ui.dialogs.help_dialog import HelpDialog
from ui.dialogs.scan_history_dialog import ScanHistoryDialog
from ui.dialogs.settings_dialog import SettingsDialog
from ui.theme import APP_STYLE
from ui.widgets.empty_state import EmptyStateWidget
from ui.widgets.groups_list_view import GroupsListView
from ui.widgets.groups_scroll_view import GroupsScrollView
from ui.widgets.results_tree_widget import ResultsTreeWidget
from ui.widgets.savings_banner import SavingsBanner
from ui.widgets.scan_panel import ScanPanel
from utils.app_info import APP_NAME
from utils.duplicates import (
    apply_keep_strategy,
    clear_all_marks,
    parse_protected_folders,
    invert_marks,
    mark_all_copies_for_deletion,
    marked_for_deletion,
    total_wasted_bytes,
)
from utils.scan_cache import clear_cache
from utils.scan_history import append_scan_entry
from utils.sort_groups import SortMode, sort_groups
from utils.export import export_groups_csv, export_groups_html, export_groups_json
from utils.file_actions import move_to_trash, reveal_in_file_manager
from utils.filter_groups import filter_groups
from utils.formatters import human_size
from utils.image_similarity import image_libs_available
from utils.image_scan_worker import ImageScanWorker
from utils.models import DuplicateGroup, KeepStrategy, ScanSettings
from utils.scheduler import scheduled_scan_due, stamp_scheduled_scan
from utils.log_service import log
from utils.scan_worker import ScanWorker
from utils.session import load_session, save_session
from utils.settings import SettingsStore


class MainWindow(QMainWindow):
    def __init__(
        self,
        *,
        initial_roots: list[str] | None = None,
        auto_scan: bool = False,
    ) -> None:
        super().__init__()
        self._store = SettingsStore.instance()
        self._all_groups: list[DuplicateGroup] = []
        self._worker: ScanWorker | ImageScanWorker | None = None
        self._scan_start = 0.0
        self._last_progress_count = 0
        self._display_limit = self._store.settings.results_page_size
        self._tray: QSystemTrayIcon | None = None
        self._last_scan_type = "byte"
        self._scan_mode = "byte"

        s = self._store.settings
        self.setAcceptDrops(True)
        self.setWindowTitle(APP_NAME)
        self.resize(s.window_width, s.window_height)
        self.setStyleSheet(APP_STYLE)

        if initial_roots:
            for r in initial_roots:
                if r not in s.roots:
                    s.roots.append(r)

        self._build_menu()
        self._build_ui()
        self._bind_shortcuts()
        self._schedule_timer = QTimer(self)
        self._schedule_timer.setInterval(60 * 60 * 1000)
        self._schedule_timer.timeout.connect(self._check_scheduled_scan)
        self._schedule_timer.start()
        QTimer.singleShot(2500, self._check_scheduled_scan)
        self._sync_page()
        self._update_idle_status()

        if auto_scan and self._roots():
            QTimer.singleShot(400, self._start_scan)

    def set_tray(self, tray: QSystemTrayIcon) -> None:
        self._tray = tray

    def _bring_to_front(self) -> None:
        self.show()
        self.setWindowState(
            (self.windowState() & ~Qt.WindowState.WindowMinimized)
            | Qt.WindowState.WindowActive
        )
        self.raise_()
        self.activateWindow()

    def apply_external_handoff(self, payload: dict) -> None:
        if payload.get("action") == "show":
            self._bring_to_front()
            self.statusBar().showMessage("Pencere öne getirildi")
            return
        for root in payload.get("roots", []):
            if root and root not in self._roots():
                self.roots_list.addItem(root)
        self._persist_roots()
        self._sync_page()
        self._update_idle_status()
        self._bring_to_front()
        if payload.get("auto_scan") and self._roots():
            log(f"IPC handoff — {len(self._roots())} kök, tarama başlıyor")
            self._start_scan()
        else:
            self.statusBar().showMessage("Handoff alındı — kökler güncellendi")

    def _build_menu(self) -> None:
        bar = QMenuBar(self)
        file_menu = QMenu("Dosya", self)
        self._act_add = QAction("Klasör ekle…", self)
        self._act_add.triggered.connect(self._add_folder)
        self._act_scan = QAction("Taramayı başlat", self)
        self._act_scan.triggered.connect(self._start_scan)
        act_image = QAction("Görsel benzerlik taraması", self)
        act_image.triggered.connect(self._start_image_scan)
        self._act_export_json = QAction("JSON dışa aktar", self)
        self._act_export_json.triggered.connect(self._export_json)
        self._act_export_csv = QAction("CSV dışa aktar", self)
        self._act_export_csv.triggered.connect(self._export_csv)
        act_html = QAction("HTML rapor dışa aktar", self)
        act_html.triggered.connect(self._export_html)
        self._act_quit = QAction("Çıkış", self)
        self._act_quit.triggered.connect(self.close)
        for act in (
            self._act_add,
            self._act_scan,
            act_image,
        ):
            file_menu.addAction(act)
        file_menu.addSeparator()
        for act in (self._act_export_json, self._act_export_csv, act_html):
            file_menu.addAction(act)
        file_menu.addSeparator()
        file_menu.addAction(self._act_quit)

        tools_menu = QMenu("Araçlar", self)
        act_settings = QAction("Ayarlar…", self)
        act_settings.triggered.connect(self._open_settings)
        act_strategy = QAction("Öneriyi uygula", self)
        act_strategy.triggered.connect(self._apply_strategy)
        act_select = QAction("Tüm kopyaları işaretle", self)
        act_select.triggered.connect(self._select_all_copies)
        act_clear = QAction("İşaretleri temizle", self)
        act_clear.triggered.connect(self._clear_marks)
        act_invert = QAction("İşaretleri tersine çevir", self)
        act_invert.triggered.connect(self._invert_marks)
        act_history = QAction("Tarama geçmişi", self)
        act_history.triggered.connect(self._show_history)
        act_clear_cache = QAction("Önbelleği temizle", self)
        act_clear_cache.triggered.connect(self._clear_scan_cache)
        act_save_session = QAction("Oturumu kaydet…", self)
        act_save_session.triggered.connect(self._save_session)
        act_load_session = QAction("Oturumu yükle…", self)
        act_load_session.triggered.connect(self._load_session)
        for act in (
            act_settings,
            act_strategy,
            act_select,
            act_clear,
            act_invert,
            act_history,
            act_clear_cache,
            act_save_session,
            act_load_session,
        ):
            tools_menu.addAction(act)

        help_menu = QMenu("Yardım", self)
        act_help = QAction("Kısayollar", self)
        act_help.triggered.connect(self._show_help)
        act_about = QAction("Hakkında", self)
        act_about.triggered.connect(self._show_about)
        help_menu.addAction(act_help)
        help_menu.addAction(act_about)

        bar.addMenu(file_menu)
        bar.addMenu(tools_menu)
        bar.addMenu(help_menu)
        self.setMenuBar(bar)

    def _build_ui(self) -> None:
        root = QWidget()
        root.setObjectName("CentralWidget")
        outer = QHBoxLayout(root)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        sidebar = QFrame()
        sidebar.setObjectName("Sidebar")
        side_layout = QVBoxLayout(sidebar)
        side_layout.setContentsMargins(0, 0, 0, 0)
        side_layout.setSpacing(0)
        side_layout.addWidget(QLabel("Kök klasörler", objectName="SidebarHeader"))

        self.roots_list = QListWidget(objectName="RootsList")
        self.roots_list.setAccessibleName("Kök klasörler")
        self.roots_list.setAcceptDrops(True)
        for r in self._store.settings.roots:
            self.roots_list.addItem(r)
        self.roots_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.roots_list.customContextMenuRequested.connect(self._roots_menu)
        side_layout.addWidget(self.roots_list, stretch=1)

        add_btn = QPushButton("+ Kök klasör ekle")
        add_btn.setObjectName("SidebarAdd")
        add_btn.clicked.connect(self._add_folder)
        side_layout.addWidget(add_btn)
        # Eskiden kökü kaldırmanın arayüzde hiçbir yolu yoktu (_remove_folder bağlı değildi).
        self.remove_root_btn = QPushButton("− Seçili kökü kaldır")
        self.remove_root_btn.setObjectName("SidebarAdd")
        self.remove_root_btn.setToolTip("Listeden çıkarır; diskteki klasöre dokunmaz (Delete)")
        self.remove_root_btn.setEnabled(False)
        self.remove_root_btn.clicked.connect(self._remove_folder)
        self.roots_list.currentRowChanged.connect(
            lambda row: self.remove_root_btn.setEnabled(row >= 0)
        )
        side_layout.addWidget(self.remove_root_btn)
        outer.addWidget(sidebar)

        main_col = QVBoxLayout()
        main_col.setContentsMargins(0, 0, 0, 0)
        main_col.setSpacing(0)

        toolbar = QFrame(objectName="Toolbar")
        tb = QHBoxLayout(toolbar)
        tb.setContentsMargins(16, 0, 16, 0)

        mode_frame = QFrame(objectName="ModeSelect")
        mode_row = QHBoxLayout(mode_frame)
        mode_row.setContentsMargins(0, 0, 0, 0)
        mode_row.setSpacing(0)
        self.mode_byte_btn = QPushButton("Byte")
        self.mode_byte_btn.setObjectName("ModeButton")
        self.mode_byte_btn.setCheckable(True)
        self.mode_byte_btn.setChecked(True)
        self.mode_phash_btn = QPushButton("pHash")
        self.mode_phash_btn.setObjectName("ModeButton")
        self.mode_phash_btn.setCheckable(True)
        if not image_libs_available():
            self.mode_phash_btn.setEnabled(False)
            self.mode_phash_btn.setToolTip("pip install -r requirements-optional.txt")
        self.mode_byte_btn.clicked.connect(lambda: self._set_scan_mode("byte"))
        self.mode_phash_btn.clicked.connect(lambda: self._set_scan_mode("phash"))
        mode_row.addWidget(self.mode_byte_btn)
        mode_row.addWidget(self.mode_phash_btn)
        tb.addWidget(mode_frame)

        self.scan_btn = QPushButton("Yeniden tara")
        self.scan_btn.setObjectName("PrimaryButton")
        self.scan_btn.clicked.connect(self._run_scan_for_mode)
        tb.addWidget(self.scan_btn)

        self.scan_status = QLabel("Hazır")
        self.scan_status.setObjectName("MutedLabel")
        tb.addStretch()
        tb.addWidget(self.scan_status)
        main_col.addWidget(toolbar)

        self.page_stack = QStackedWidget()
        self.empty_state = EmptyStateWidget()
        self.empty_state.browse_clicked.connect(self._add_folder)
        self.page_stack.addWidget(self.empty_state)

        work = QWidget()
        work_layout = QVBoxLayout(work)
        work_layout.setContentsMargins(0, 0, 0, 0)
        work_layout.setSpacing(0)

        self.scan_panel = ScanPanel()
        self.scan_panel.cancel_btn.clicked.connect(self._cancel_scan)
        work_layout.addWidget(self.scan_panel)

        self.savings_banner = SavingsBanner()
        self.savings_banner.hide()
        work_layout.addWidget(self.savings_banner)

        filter_row = QHBoxLayout()
        filter_row.setContentsMargins(16, 10, 16, 0)
        self.filter_input = QLineEdit()
        self.filter_input.setPlaceholderText("Sonuçlarda yol ara… (Ctrl+F)")
        self.filter_input.setAccessibleName("Sonuçlarda yol ara")
        self.filter_input.setClearButtonEnabled(True)
        self.filter_input.textChanged.connect(self._on_filter_changed)
        filter_row.addWidget(self.filter_input, stretch=1)
        self.sort_combo = QComboBox()
        self.sort_combo.setAccessibleName("Sıralama")
        self.sort_combo.addItem("İsraf", SortMode.WASTED.value)
        self.sort_combo.addItem("Kopya sayısı", SortMode.COUNT.value)
        self.sort_combo.addItem("Dosya boyutu", SortMode.SIZE.value)
        self.sort_combo.addItem("Yol", SortMode.PATH.value)
        idx = self.sort_combo.findData(self._store.settings.sort_mode)
        if idx >= 0:
            self.sort_combo.setCurrentIndex(idx)
        self.sort_combo.currentIndexChanged.connect(self._on_sort_changed)
        filter_row.addWidget(self.sort_combo)
        self.results_info = QLabel("")
        self.results_info.setObjectName("MutedLabel")
        filter_row.addWidget(self.results_info)
        work_layout.addLayout(filter_row)

        self.results_stack = QStackedWidget()
        self.groups_scroll = GroupsScrollView()
        self.groups_scroll.selection_changed.connect(self._update_delete_button)
        self.results_tree = ResultsTreeWidget()
        self.results_tree.selection_changed.connect(self._update_delete_button)
        self.compact_list = GroupsListView()
        self.compact_list.group_activated.connect(self._open_compact_group)
        self.results_stack.addWidget(self.groups_scroll)
        self.results_stack.addWidget(self.results_tree)
        self.results_stack.addWidget(self.compact_list)
        work_layout.addWidget(self.results_stack, stretch=1)

        more_row = QHBoxLayout()
        more_row.setContentsMargins(16, 8, 16, 8)
        self.load_more_btn = QPushButton("Daha fazla grup göster")
        self.load_more_btn.clicked.connect(self._load_more_groups)
        self.load_more_btn.setVisible(False)
        more_row.addWidget(self.load_more_btn)
        more_row.addStretch()
        work_layout.addLayout(more_row)

        action_bar = QFrame(objectName="ActionBar")
        ab = QHBoxLayout(action_bar)
        ab.setContentsMargins(16, 8, 16, 8)
        self.selection_info = QLabel("0 dosya seçili")
        self.selection_info.setObjectName("MutedLabel")
        ab.addWidget(self.selection_info)
        ab.addStretch()
        self.strategy_btn = QPushButton("Öneriyi uygula")
        self.strategy_btn.clicked.connect(self._apply_strategy)
        self.select_all_btn = QPushButton("Tümünü seç")
        self.select_all_btn.clicked.connect(self._select_all_copies)
        self.export_btn = QPushButton("Dışa aktar")
        self.export_btn.clicked.connect(self._export_json)
        self.delete_btn = QPushButton("Seçilileri sil")
        self.delete_btn.setObjectName("DangerButton")
        self.delete_btn.setEnabled(False)
        self.delete_btn.clicked.connect(self._delete_selected)
        for w in (self.strategy_btn, self.select_all_btn, self.export_btn, self.delete_btn):
            ab.addWidget(w)
        work_layout.addWidget(action_bar)
        self.page_stack.addWidget(work)
        main_col.addWidget(self.page_stack, stretch=1)

        main_widget = QWidget()
        main_widget.setLayout(main_col)
        outer.addWidget(main_widget, stretch=1)

        self.setCentralWidget(root)
        sb = QStatusBar()
        sb.showMessage("SHA-256 · 2 aşamalı doğrulama · F5 tara · Delete sil · Esc iptal")
        self.setStatusBar(sb)
        self._persist_roots()

    def _set_scan_mode(self, mode: str) -> None:
        self._scan_mode = mode
        self.mode_byte_btn.setChecked(mode == "byte")
        self.mode_phash_btn.setChecked(mode == "phash")

    def _run_scan_for_mode(self) -> None:
        if self._scan_mode == "phash":
            self._start_image_scan()
        else:
            self._start_scan()

    def _sync_page(self) -> None:
        self.page_stack.setCurrentIndex(0 if not self._roots() else 1)

    def _bind_shortcuts(self) -> None:
        QShortcut(QKeySequence("F5"), self, self._run_scan_for_mode)
        QShortcut(QKeySequence("F1"), self, self._show_help)
        QShortcut(QKeySequence("Ctrl+O"), self, self._add_folder)
        QShortcut(QKeySequence("Ctrl+,"), self, self._open_settings)
        QShortcut(QKeySequence("Ctrl+E"), self, self._export_json)
        QShortcut(QKeySequence("Ctrl+Shift+E"), self, self._export_csv)
        QShortcut(QKeySequence("Ctrl+Shift+H"), self, self._export_html)
        QShortcut(QKeySequence("Escape"), self, self._cancel_scan)
        QShortcut(QKeySequence("Delete"), self, self._on_delete_key)
        QShortcut(QKeySequence("Ctrl+F"), self, self._focus_filter)

    def _on_delete_key(self) -> None:
        # Kök listesi odaktayken Delete kökü listeden çıkarır; aksi halde seçili kopyaları siler.
        if self.roots_list.hasFocus():
            self._remove_folder()
        else:
            self._delete_selected()

    def _focus_filter(self) -> None:
        self.filter_input.setFocus()
        self.filter_input.selectAll()

    def _roots_menu(self, pos) -> None:
        item = self.roots_list.itemAt(pos)
        if item is None:
            return
        self.roots_list.setCurrentItem(item)
        self._build_roots_menu(item.text()).exec(self.roots_list.mapToGlobal(pos))

    def _build_roots_menu(self, path: str) -> QMenu:
        menu = QMenu(self)
        menu.addAction("Explorer'da aç", lambda: reveal_in_file_manager(path))
        menu.addAction("Listeden kaldır\tDelete", self._remove_folder)
        return menu

    def _visible_groups(self) -> list[DuplicateGroup]:
        return filter_groups(self._all_groups, self.filter_input.text())

    def _roots(self) -> list[str]:
        return [self.roots_list.item(i).text() for i in range(self.roots_list.count())]

    def _scan_settings(self) -> ScanSettings:
        s = self._store.settings
        exts = [e.strip() for e in s.exclude_extensions.split(",") if e.strip()]
        return ScanSettings(
            roots=self._roots(),
            min_size_bytes=max(0, s.min_size_kb) * 1024,
            exclude_extensions=exts,
            skip_hidden=s.skip_hidden,
            skip_system_dirs=s.skip_system_dirs,
            hash_workers=s.hash_workers,
            follow_symlinks=s.follow_symlinks,
        )

    def _apply_keep(self) -> None:
        apply_keep_strategy(
            self._all_groups,
            self._keep_strategy(),
            parse_protected_folders(self._store.settings.protected_folders),
        )

    def _keep_strategy(self) -> KeepStrategy:
        try:
            return KeepStrategy(self._store.settings.keep_strategy)
        except ValueError:
            return KeepStrategy.OLDEST

    def dragEnterEvent(self, event) -> None:
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event) -> None:
        for url in event.mimeData().urls():
            path = url.toLocalFile()
            if path and Path(path).is_dir() and path not in self._roots():
                self.roots_list.addItem(path)
        self._persist_roots()
        self._sync_page()
        self._update_idle_status()
        event.acceptProposedAction()

    def _add_roots(self, paths: list[str]) -> None:
        for folder in paths:
            if folder and folder not in self._roots():
                self.roots_list.addItem(folder)
        self._persist_roots()
        self._sync_page()
        self._update_idle_status()

    def _add_folder(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Tarama klasörü")
        if folder:
            self._add_roots([folder])

    def _remove_folder(self) -> None:
        row = self.roots_list.currentRow()
        if row >= 0:
            self.roots_list.takeItem(row)
            self._persist_roots()
            self._sync_page()
            self._update_idle_status()

    def _persist_roots(self) -> None:
        self._store.settings.roots = self._roots()
        self._store.save()

    def _update_idle_status(self) -> None:
        n = len(self._roots())
        self.scan_status.setText(
            f"Taramaya hazır · {n} kök klasör" if n else "Kök klasör ekleyin"
        )
        self.statusBar().showMessage(f"Hazır · {n} kök")

    def _bind_worker(self, worker: ScanWorker | ImageScanWorker) -> None:
        self._worker = worker
        worker.progress.connect(self._on_progress)
        worker.finished_ok.connect(self._on_scan_done)
        worker.finished_error.connect(self._on_scan_error)
        worker.finished_cancelled.connect(self._on_scan_cancelled)

    def _start_scan(self) -> None:
        if not self._roots():
            QMessageBox.warning(self, APP_NAME, "En az bir tarama klasörü ekleyin.")
            return
        if self._worker and self._worker.isRunning():
            return
        self._set_scan_mode("byte")
        self._begin_scan("byte", ScanWorker(
            self._scan_settings(),
            use_cache=self._store.settings.use_scan_cache,
        ))

    def _start_image_scan(self) -> None:
        if not self._roots():
            QMessageBox.warning(self, APP_NAME, "En az bir tarama klasörü ekleyin.")
            return
        if not image_libs_available():
            QMessageBox.information(
                self,
                APP_NAME,
                "Görsel benzerlik için:\npip install -r requirements-optional.txt",
            )
            return
        if self._worker and self._worker.isRunning():
            return
        self._set_scan_mode("phash")
        self._begin_scan("image", ImageScanWorker(self._scan_settings()))

    def _begin_scan(self, scan_type: str, worker: ScanWorker | ImageScanWorker) -> None:
        self._all_groups = []
        self._display_limit = self._store.settings.results_page_size
        self.savings_banner.hide()
        self.scan_btn.setEnabled(False)
        self._scan_start = time.perf_counter()
        self._last_progress_count = 0
        self._last_scan_type = scan_type
        self._bind_worker(worker)
        worker.start()
        self.scan_status.setText("Taranıyor…")
        self.statusBar().showMessage("Taranıyor…")

    def _cancel_scan(self) -> None:
        if self._worker:
            self._worker.cancel()

    def _on_progress(self, phase: str, count: int, path: str, groups: int) -> None:
        elapsed = max(time.perf_counter() - self._scan_start, 0.001)
        speed = count / elapsed if phase in ("collect", "image") else self._last_progress_count / elapsed
        if phase in ("collect", "image"):
            self._last_progress_count = count
        self.scan_panel.set_scanning(path, phase)
        self.scan_panel.set_stats(count, speed, groups)

    def _on_scan_done(self, groups: list, from_cache: bool = False) -> None:
        self.scan_btn.setEnabled(True)
        self._all_groups = groups
        self._apply_keep()
        wasted = total_wasted_bytes(self._all_groups)
        self.scan_panel.set_complete(wasted, len(self._all_groups))
        selectable = sum(
            1
            for g in self._all_groups
            for f in g.files
            if not f.is_keeper and not g.is_hardlink_group
        )
        if self._all_groups:
            self.savings_banner.set_stats(wasted, len(self._all_groups), selectable)
            self.savings_banner.show()
        self._render_groups()
        self._update_delete_button()
        msg = f"{len(self._all_groups)} grup — {human_size(wasted)} kazanç potansiyeli"
        if from_cache:
            msg = f"Önbellekten yüklendi — {msg}"
        self.scan_status.setText(msg)
        self.statusBar().showMessage(msg)
        append_scan_entry(
            scan_type=self._last_scan_type,
            roots=self._roots(),
            group_count=len(self._all_groups),
            wasted_bytes=wasted,
            from_cache=from_cache,
        )
        if self._tray:
            self._tray.showMessage(APP_NAME, msg, QSystemTrayIcon.MessageIcon.Information, 5000)

    def _on_scan_cancelled(self) -> None:
        self.scan_btn.setEnabled(True)
        self.scan_panel.set_idle("")
        self._update_idle_status()

    def _on_scan_error(self, message: str) -> None:
        self.scan_btn.setEnabled(True)
        self.scan_panel.set_idle("")
        log(f"Tarama hatası: {message}")
        QMessageBox.critical(self, APP_NAME, message)
        self._update_idle_status()

    def _on_filter_changed(self) -> None:
        self._display_limit = self._store.settings.results_page_size
        self._render_groups()

    def _on_sort_changed(self) -> None:
        self._store.settings.sort_mode = self.sort_combo.currentData()
        self._store.save()
        self._render_groups()

    def _sorted_visible_groups(self) -> list[DuplicateGroup]:
        try:
            mode = SortMode(self._store.settings.sort_mode)
        except ValueError:
            mode = SortMode.WASTED
        return sort_groups(self._visible_groups(), mode)

    def _render_groups(self) -> None:
        visible = self._sorted_visible_groups()
        if not visible:
            self.groups_scroll.load_groups([])
            self.results_tree.clear()
            self.compact_list.load_groups([])
            self.results_info.setText(
                "Tekrarlanan dosya bulunamadı."
                if self._all_groups
                else "Sonuç yok — tarama başlatın (F5)."
            )
            self.load_more_btn.setVisible(False)
            if not self._all_groups:
                self.savings_banner.hide()
            return

        threshold = self._store.settings.compact_list_threshold
        if len(visible) >= threshold:
            self.results_stack.setCurrentWidget(self.compact_list)
            self.compact_list.load_groups(visible)
            self.results_info.setText(f"{len(visible)} grup · kompakt liste")
            self.load_more_btn.setVisible(False)
            return

        use_cards = len(visible) <= 80
        if use_cards:
            self.results_stack.setCurrentWidget(self.groups_scroll)
            hidden = self.groups_scroll.load_groups(visible, limit=self._display_limit)
            shown = min(len(visible), self._display_limit)
            self.results_info.setText(f"{shown}/{len(visible)} grup · kart görünümü")
        else:
            self.results_stack.setCurrentWidget(self.results_tree)
            hidden = self.results_tree.load_groups(visible, limit=self._display_limit)
            shown = min(len(visible), self._display_limit)
            self.results_info.setText(f"{shown}/{len(visible)} grup · ağaç görünümü")
        self.load_more_btn.setVisible(hidden > 0 or len(visible) > self._display_limit)
        if hidden > 0:
            self.load_more_btn.setText(f"Daha fazla grup ({hidden} gizli)")

    def _open_compact_group(self, row: int) -> None:
        group = self.compact_list._model.group_at(row)
        if not group:
            return
        dlg = GroupDetailDialog(group, self)
        if dlg.exec():
            self._render_groups()
            self._update_delete_button()

    def _load_more_groups(self) -> None:
        self._display_limit += self._store.settings.results_page_size
        self._render_groups()

    def _apply_strategy(self) -> None:
        if not self._all_groups:
            QMessageBox.information(self, APP_NAME, "Önce tarama yapın.")
            return
        self._apply_keep()
        self._render_groups()
        self._update_delete_button()

    def _select_all_copies(self) -> None:
        if not self._all_groups:
            QMessageBox.information(self, APP_NAME, "Önce tarama yapın.")
            return
        mark_all_copies_for_deletion(self._all_groups)
        self._render_groups()
        self._update_delete_button()

    def _clear_marks(self) -> None:
        if not self._all_groups:
            return
        clear_all_marks(self._all_groups)
        self._render_groups()
        self._update_delete_button()

    def _invert_marks(self) -> None:
        if not self._all_groups:
            return
        invert_marks(self._all_groups)
        self._render_groups()
        self._update_delete_button()

    def _show_history(self) -> None:
        ScanHistoryDialog(self).exec()

    def _clear_scan_cache(self) -> None:
        if clear_cache():
            QMessageBox.information(self, APP_NAME, "Tarama önbelleği temizlendi.")
            log("Önbellek temizlendi")
        else:
            QMessageBox.information(self, APP_NAME, "Önbellek zaten boş.")

    def _save_session(self) -> None:
        if not self._all_groups:
            QMessageBox.information(self, APP_NAME, "Kaydedilecek sonuç yok.")
            return
        start = self._store.settings.last_export_dir or str(Path.home())
        path, _ = QFileDialog.getSaveFileName(
            self, "Oturum kaydet", start, "Oturum (*.json)"
        )
        if not path:
            return
        try:
            save_session(self._all_groups, Path(path))
        except OSError as exc:
            QMessageBox.critical(self, APP_NAME, f"Oturum kaydedilemedi:\n{exc}")
            return
        self._store.settings.last_export_dir = str(Path(path).parent)
        self._store.save()
        self.statusBar().showMessage(f"Oturum kaydedildi: {path}")

    def _load_session(self) -> None:
        start = self._store.settings.last_export_dir or str(Path.home())
        path, _ = QFileDialog.getOpenFileName(self, "Oturum yükle", start, "Oturum (*.json)")
        if not path:
            return
        try:
            self._all_groups = load_session(Path(path))
            self._apply_keep()
            wasted = total_wasted_bytes(self._all_groups)
            self.scan_panel.set_complete(wasted, len(self._all_groups))
            selectable = sum(
                1 for g in self._all_groups for f in g.files if not f.is_keeper
            )
            self.savings_banner.set_stats(wasted, len(self._all_groups), selectable)
            self.savings_banner.show()
            self._display_limit = self._store.settings.results_page_size
            self._render_groups()
            self._update_delete_button()
            self.statusBar().showMessage(f"Oturum yüklendi — {len(self._all_groups)} grup")
            log(f"Oturum yüklendi: {path}")
        except (OSError, ValueError, KeyError) as exc:
            QMessageBox.critical(self, APP_NAME, f"Oturum yüklenemedi:\n{exc}")

    def _update_delete_button(self) -> None:
        paths = marked_for_deletion(self._all_groups)
        total = sum(f.size for g in self._all_groups for f in g.files if f.marked_for_delete)
        self.delete_btn.setEnabled(bool(paths))
        self.selection_info.setText(
            f"<b>{len(paths)}</b> dosya seçili · <b>{human_size(total)}</b>"
            if paths
            else "0 dosya seçili"
        )

    def _delete_selected(self) -> None:
        paths = marked_for_deletion(self._all_groups)
        if not paths:
            return
        total = sum(f.size for g in self._all_groups for f in g.files if f.marked_for_delete)
        dlg = DeleteConfirmDialog(paths, total, self)
        if dlg.exec() != QDialog.DialogCode.Accepted:
            return

        if dlg.permanent_delete:
            reply = QMessageBox.warning(
                self,
                "Kalıcı silme",
                "Kalıcı silme geri alınamaz. Devam etmek istiyor musunuz?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            )
            if reply != QMessageBox.StandardButton.Yes:
                return
            errors = []
            ok = 0
            for path in paths:
                try:
                    Path(path).unlink()
                    ok += 1
                except OSError as exc:
                    errors.append(f"{path}: {exc}")
        else:
            ok, errors = move_to_trash(paths)

        if errors:
            QMessageBox.warning(self, APP_NAME, "\n".join(errors[:10]))
        QMessageBox.information(self, APP_NAME, f"{ok} dosya işlendi.")
        # Yalnızca gerçekten silinenleri listeden düş; hata verenler görünür kalsın
        deleted_set = {p for p in paths if not Path(p).exists()}
        self._all_groups = [
            DuplicateGroup(
                hash_hex=g.hash_hex,
                size=g.size,
                files=[f for f in g.files if f.path not in deleted_set],
                is_hardlink_group=g.is_hardlink_group,
            )
            for g in self._all_groups
            if len([f for f in g.files if f.path not in deleted_set]) >= 2
        ]
        wasted = total_wasted_bytes(self._all_groups)
        if self._all_groups:
            selectable = sum(
                1 for g in self._all_groups for f in g.files if not f.is_keeper
            )
            self.savings_banner.set_stats(wasted, len(self._all_groups), selectable)
        else:
            self.savings_banner.hide()
        self.scan_panel.set_complete(wasted, len(self._all_groups))
        self._render_groups()
        self._update_delete_button()

    def _check_scheduled_scan(self) -> None:
        s = self._store.settings
        if not scheduled_scan_due(
            enabled=s.scheduled_scan_enabled,
            last_scan_utc=s.last_scheduled_scan_utc,
            interval_days=s.scheduled_scan_days,
        ):
            return
        if not self._roots():
            return
        if self._worker and self._worker.isRunning():
            return
        s.last_scheduled_scan_utc = stamp_scheduled_scan()
        self._store.save()
        self._start_scan()

    def _open_settings(self) -> None:
        dlg = SettingsDialog(self._store.settings, self)
        if dlg.exec() == QDialog.DialogCode.Accepted:
            s = self._store.settings
            before = (s.keep_strategy, s.protected_folders)
            dlg.apply_to(s)
            self._display_limit = s.results_page_size
            self._store.save()
            # Strateji / korunan klasör değiştiyse mevcut sonuçlardaki işaretleri yenile
            if self._all_groups and before != (s.keep_strategy, s.protected_folders):
                self._apply_keep()
                self._render_groups()
                self._update_delete_button()

    def _export_json(self) -> None:
        self._export_file("json", export_groups_json, "JSON (*.json)")

    def _export_csv(self) -> None:
        self._export_file("csv", export_groups_csv, "CSV (*.csv)")

    def _export_html(self) -> None:
        self._export_file("html", export_groups_html, "HTML (*.html)")

    def _export_file(self, ext: str, exporter, filter_str: str) -> None:
        if not self._all_groups:
            QMessageBox.information(self, APP_NAME, "Dışa aktarılacak sonuç yok.")
            return
        start = self._store.settings.last_export_dir or str(Path.home())
        path, _ = QFileDialog.getSaveFileName(self, f"{ext.upper()} kaydet", start, filter_str)
        if not path:
            return
        if not path.lower().endswith(f".{ext}"):
            path += f".{ext}"
        try:
            exporter(self._all_groups, Path(path))
        except OSError as exc:
            QMessageBox.critical(self, APP_NAME, f"Dışa aktarılamadı:\n{exc}")
            return
        self._store.settings.last_export_dir = str(Path(path).parent)
        self._store.save()
        self.statusBar().showMessage(f"Dışa aktarıldı: {path}")

    def _show_help(self) -> None:
        HelpDialog(self).exec()

    def _show_about(self) -> None:
        AboutDialog(self).exec()

    def closeEvent(self, event) -> None:
        from PySide6.QtWidgets import QApplication

        s = self._store.settings
        s.window_width = self.width()
        s.window_height = self.height()
        self._store.save()
        if self._tray and s.minimize_to_tray:
            # Tepsiye küçültülürken tarama arka planda sürsün
            self.hide()
            event.ignore()
            return
        if self._worker and self._worker.isRunning():
            self._worker.cancel()
            self._worker.wait(3000)
        if self._tray:
            self._tray.hide()
        super().closeEvent(event)
        QApplication.instance().quit()
