from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from PySide6.QtCore import QTimer, Qt
from PySide6.QtGui import QAction, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QFrame,
    QHBoxLayout,
    QLabel,
    QMainWindow,
    QMenu,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QStackedWidget,
    QStatusBar,
    QSystemTrayIcon,
    QToolButton,
    QVBoxLayout,
    QWidget,
    QFileDialog,
)

from core.cache import invalidate_cache_for
from core.duplicates import find_duplicate_candidates
from core.export import export_csv, export_html, export_json, move_to_trash, reveal_in_explorer
from core.formatters import human_size
from core.history import list_history, load_snapshot
from core.models import ScanNode, is_same_or_under
from core.scan_worker import ScanWorker, list_windows_drives
from core.scanner import large_files_in
from core.settings import SettingsStore
from ui.charts.sunburst_chart import SunburstChart
from ui.charts.treemap_chart import TreemapChart
from ui.dialogs.about_dialog import AboutDialog
from ui.dialogs.duplicates_dialog import DuplicatesDialog
from ui.dialogs.help_dialog import HelpDialog
from ui.dialogs.settings_dialog import SettingsDialog
from ui.theme import APP_STYLE, ACCENT, SUCCESS
from ui.widgets.breadcrumb_bar import BreadcrumbBar
from ui.widgets.sidebar_panel import SidebarPanel
from ui.widgets.state_banner import StateBanner


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Disk Alanı Görselleştirici")
        self.setMinimumSize(1024, 640)
        self.setStyleSheet(APP_STYLE)

        self._settings = SettingsStore.instance().settings
        self._root: ScanNode | None = None
        self._focus: ScanNode | None = None
        self._trail: list[ScanNode] = []
        self._large_files = []
        self._duplicates = []
        self._worker: ScanWorker | None = None
        self._scan_root = self._settings.last_scan_root or (list_windows_drives() or ["C:\\"])[0]
        self._tray: QSystemTrayIcon | None = None
        self._scanning = False

        central = QWidget()
        central.setObjectName("CentralWidget")
        root_layout = QVBoxLayout(central)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        self.progress = QProgressBar()
        self.progress.setTextVisible(False)
        self.progress.setMaximum(100)
        self.progress.hide()
        root_layout.addWidget(self.progress)

        root_layout.addWidget(self._build_toolbar())

        self.state_banner = StateBanner()
        self.state_banner.action_clicked.connect(self._start_scan)  # tek eylem: "Yeniden tara"
        root_layout.addWidget(self.state_banner)

        body = QHBoxLayout()
        body.setSpacing(0)
        body.setContentsMargins(0, 0, 0, 0)

        chart_col = QVBoxLayout()
        chart_col.setContentsMargins(24, 12, 16, 12)
        self.breadcrumb = BreadcrumbBar()
        self.breadcrumb.navigated.connect(self._navigate_to)
        chart_col.addWidget(self.breadcrumb)

        self.chart_stack = QStackedWidget()
        self.sunburst = SunburstChart()
        self.treemap = TreemapChart()
        self.chart_stack.addWidget(self.sunburst)
        self.chart_stack.addWidget(self.treemap)
        chart_col.addWidget(self.chart_stack, stretch=1)

        chart_col.addWidget(self._build_view_toggle(), alignment=Qt.AlignmentFlag.AlignHCenter)

        chart_wrap = QWidget()
        chart_wrap.setLayout(chart_col)
        body.addWidget(chart_wrap, stretch=1)

        self.sidebar = SidebarPanel()
        self.sidebar.reveal_requested.connect(reveal_in_explorer)
        self.sidebar.delete_requested.connect(self._confirm_delete)
        self.sidebar.duplicates_requested.connect(self._show_duplicates)
        self.sidebar.snapshot_selected.connect(self._load_snapshot)
        body.addWidget(self.sidebar)

        body_wrap = QWidget()
        body_wrap.setLayout(body)
        root_layout.addWidget(body_wrap, stretch=1)

        self.setCentralWidget(central)
        self.setStatusBar(QStatusBar())

        self._wire_charts(self.sunburst)
        self._wire_charts(self.treemap)
        self._build_menu()
        self._bind_shortcuts()

        self._set_depth_index(self._settings.depth_index)
        self._set_view(self._settings.view_index)
        self.statusBar().showMessage("Hazır — F5 ile tara")

        self._schedule_timer = QTimer(self)
        self._schedule_timer.timeout.connect(self._check_scheduled_scan)
        self._schedule_timer.start(60 * 60 * 1000)
        QTimer.singleShot(2000, self._check_scheduled_scan)

    def set_tray(self, tray: QSystemTrayIcon) -> None:
        self._tray = tray

    def _wire_charts(self, chart) -> None:
        chart.segment_hovered.connect(self._on_hover)
        chart.segment_clicked.connect(self._drill_to)
        chart.segment_context.connect(self._context_menu)
        chart.segment_delete.connect(lambda node: self._confirm_delete(node.path))

    def _build_view_toggle(self) -> QFrame:
        frame = QFrame()
        frame.setObjectName("ViewToggle")
        row = QHBoxLayout(frame)
        row.setContentsMargins(3, 3, 3, 3)
        row.setSpacing(2)
        self.sunburst_btn = QPushButton("Sunburst")
        self.sunburst_btn.setToolTip("Ctrl+1")
        self.treemap_btn = QPushButton("Treemap")
        self.treemap_btn.setToolTip("Ctrl+2")
        self.sunburst_btn.clicked.connect(lambda: self._set_view(0))
        self.treemap_btn.clicked.connect(lambda: self._set_view(1))
        row.addWidget(self.sunburst_btn)
        row.addWidget(self.treemap_btn)
        return frame

    def _build_toolbar(self) -> QFrame:
        bar = QFrame()
        bar.setObjectName("Toolbar")
        layout = QHBoxLayout(bar)
        layout.setContentsMargins(16, 8, 16, 8)
        layout.setSpacing(8)

        brand = QLabel("Disk Alanı")
        brand.setObjectName("ToolbarBrand")
        layout.addWidget(brand)

        self.scan_btn = QPushButton("Tara")
        self.scan_btn.setObjectName("PrimaryButton")
        self.scan_btn.setToolTip("F5")
        self.scan_btn.clicked.connect(self._toggle_scan)
        layout.addWidget(self.scan_btn)

        pick_btn = QPushButton("Dizin Seç…")
        self.pick_btn = pick_btn
        pick_btn.setToolTip("Ctrl+O")
        pick_btn.clicked.connect(self._pick_folder)
        layout.addWidget(pick_btn)

        self.depth_chip = QToolButton()
        self.depth_chip.setObjectName("ChipButton")
        self.depth_chip.setPopupMode(QToolButton.ToolButtonPopupMode.InstantPopup)
        self.depth_chip.setMenu(self._depth_menu())
        self.depth_chip.setToolTip("Tarama derinliği")
        layout.addWidget(self.depth_chip)

        self.dup_chip = QPushButton("Tekrar adayı")
        self.dup_chip.setToolTip("Aynı boyutlu dosya grupları")
        self.dup_chip.setObjectName("ChipWarning")
        self.dup_chip.hide()
        self.dup_chip.clicked.connect(self._show_duplicates)
        layout.addWidget(self.dup_chip)

        layout.addStretch()

        self.scan_status = QLabel("")
        self.scan_status.setObjectName("ScanStatus")
        layout.addWidget(self.scan_status)

        self.sidebar_btn = QPushButton("☰")
        self.sidebar_btn.setObjectName("GhostButton")
        self.sidebar_btn.setFixedWidth(32)
        self.sidebar_btn.setToolTip("Detay paneli (Ctrl+B)")
        self.sidebar_btn.setAccessibleName("Detay panelini aç/kapat")
        self.sidebar_btn.clicked.connect(self._toggle_sidebar)
        layout.addWidget(self.sidebar_btn)

        return bar

    def _depth_menu(self) -> QMenu:
        menu = QMenu(self)
        for idx, label in enumerate(("Hızlı (3)", "Normal (5)", "Tam (sınırsız)")):
            action = menu.addAction(label)
            action.triggered.connect(lambda _=False, i=idx: self._set_depth_index(i))
        return menu

    def _set_depth_index(self, idx: int) -> None:
        labels = ("Hızlı (3)", "Normal (5)", "Tam (sınırsız)")
        depths = (3, 5, None)
        idx = idx if 0 <= idx < len(depths) else 1  # bozuk ayar dosyasında çökmesin
        self._settings.depth_index = idx
        SettingsStore.instance().save()
        self.depth_chip.setText(f"Derinlik: {depths[idx] if depths[idx] else '∞'}")

    def _build_menu(self) -> None:
        menu = self.menuBar()
        file_menu = menu.addMenu("Dosya")
        file_menu.addAction("Tara", self._start_scan, QKeySequence("F5"))
        file_menu.addAction(
            "Önbelleği atlayarak tara", lambda: self._start_scan(use_cache=False), QKeySequence("Shift+F5")
        )
        file_menu.addAction("Dizin seç…", self._pick_folder, QKeySequence("Ctrl+O"))
        self.recent_menu = file_menu.addMenu("Son klasörler")
        self.recent_menu.aboutToShow.connect(self._fill_recent_menu)
        file_menu.addAction("Dışa aktar", self._export_menu, QKeySequence("Ctrl+E"))
        file_menu.addSeparator()
        file_menu.addAction("Çık", self.close, QKeySequence("Ctrl+Q"))

        view_menu = menu.addMenu("Görünüm")
        view_menu.addAction("Sunburst", lambda: self._set_view(0), QKeySequence("Ctrl+1"))
        view_menu.addAction("Treemap", lambda: self._set_view(1), QKeySequence("Ctrl+2"))
        view_menu.addSeparator()
        view_menu.addAction("Üst klasör", self._go_up, QKeySequence(Qt.Key.Key_Backspace))
        view_menu.addAction("Köke dön", self._go_root, QKeySequence("Alt+Home"))
        view_menu.addAction("Detay paneli", self._toggle_sidebar, QKeySequence("Ctrl+B"))

        tools_menu = menu.addMenu("Araçlar")
        tools_menu.addAction("Tekrar adayları", self._show_duplicates, QKeySequence("Ctrl+D"))
        tools_menu.addAction("Ayarlar", self._open_settings, QKeySequence("Ctrl+,"))

        help_menu = menu.addMenu("Yardım")
        help_menu.addAction("Klavye kısayolları", self._open_help, QKeySequence("F1"))
        help_menu.addAction("Hakkında", self._open_about)

    def _fill_recent_menu(self) -> None:
        self.recent_menu.clear()
        roots = self._settings.recent_roots
        if not roots:
            self.recent_menu.addAction("(henüz yok)").setEnabled(False)
            return
        for root in roots:
            self.recent_menu.addAction(root, lambda r=root: self._scan_recent(r))
        self.recent_menu.addSeparator()
        self.recent_menu.addAction("Listeyi temizle", self._clear_recent)

    def _scan_recent(self, root: str) -> None:
        if not Path(root).exists():
            QMessageBox.warning(self, "Son klasörler", f"Klasör artık yok:\n{root}")
            self._settings.recent_roots = [r for r in self._settings.recent_roots if r != root]
            SettingsStore.instance().save()
            return
        self._scan_root = root
        self._start_scan()

    def _clear_recent(self) -> None:
        self._settings.recent_roots = []
        SettingsStore.instance().save()

    def _bind_shortcuts(self) -> None:
        QShortcut(QKeySequence(Qt.Key.Key_Escape), self, self._cancel_or_root)

    def pick_folder(self) -> None:
        self._pick_folder()

    def start_scan_from_shortcut(self) -> None:
        self._start_scan()

    def _toggle_sidebar(self) -> None:
        self.sidebar.setVisible(self.sidebar.isHidden())

    def _toggle_scan(self) -> None:
        if self._scanning:
            self._cancel_scan(user_initiated=True)
        else:
            self._start_scan()

    def _depth_limit(self) -> int | None:
        idx = self._settings.depth_index
        if idx == 0:
            return 3
        if idx == 1:
            return 5
        return None

    def _pick_folder(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Analiz klasörü", self._scan_root or "")
        if folder:
            self._scan_root = folder
            self._start_scan()

    def _start_scan(self, *, use_cache: bool = True) -> None:
        root = self._scan_root
        if not root:
            return
        self._settings.last_scan_root = root
        self._settings.remember_root(root)
        SettingsStore.instance().save()
        self._cancel_scan()
        self._scanning = True
        self._set_scan_ui(True)
        self.state_banner.show_message("info", "Tarama sürüyor", f"{root} taranıyor…")
        self.progress.show()
        self.progress.setMaximum(0)
        self.scan_status.setText("Taranıyor…")
        self.statusBar().showMessage(f"Taranıyor: {root}")

        self._worker = ScanWorker(root, max_depth=self._depth_limit(), use_cache=use_cache)
        self._worker.progress.connect(self._on_progress)
        self._worker.finished_ok.connect(self._on_scan_done)
        self._worker.finished_error.connect(self._on_scan_error)
        self._worker.start()

    def _cancel_scan(self, *, user_initiated: bool = False) -> None:
        worker = self._worker
        if worker:
            # Eski worker'ın kuyruktaki sinyalleri yeni taramanın arayüzünü bozmasın.
            for sig in (worker.progress, worker.finished_ok, worker.finished_error):
                try:
                    sig.disconnect()
                except (RuntimeError, TypeError):
                    pass
            if worker.isRunning():
                worker.cancel()
                worker.wait(2000)
                if worker.isRunning():
                    # Referans düşerken hâlâ çalışan QThread yok edilirse süreç çöker;
                    # bitene kadar pencereye bağla, sonra sil.
                    worker.setParent(self)
                    worker.finished.connect(worker.deleteLater)
        self._worker = None
        if self._scanning:
            self._scanning = False
            self._set_scan_ui(False)
            self.progress.hide()
            if user_initiated:
                self.scan_status.setText("İptal edildi")
                self.state_banner.show_message(
                    "danger",
                    "İptal edildi",
                    "Tarama durduruldu; görünen sonuçlar son önbellekten geliyor.",
                    action_text="Yeniden tara",
                )

    def _set_scan_ui(self, active: bool) -> None:
        if active:
            self.scan_btn.setText("İptal")
            self.scan_btn.setObjectName("DangerButton")
        else:
            self.scan_btn.setText("Tara")
            self.scan_btn.setObjectName("PrimaryButton")
        self.scan_btn.setStyle(self.scan_btn.style())
        chunk_color = ACCENT if active else SUCCESS
        self.setStyleSheet(APP_STYLE + f"QProgressBar::chunk {{ background: {chunk_color}; }}")

    def _on_progress(self, count: int, path: str) -> None:
        self.scan_status.setText(f"Taranıyor… {count:,} dosya · {Path(path).name}")

    def _on_scan_done(self, root: ScanNode, large_files: list) -> None:
        self._scanning = False
        self._set_scan_ui(False)
        self.progress.hide()
        self.progress.setMaximum(100)
        self.progress.setValue(100)
        self._root = root
        self._large_files = large_files
        min_dup = self._settings.min_duplicate_size_mb * 1024 * 1024
        self._duplicates = find_duplicate_candidates(root, min_size=min_dup)
        self.sidebar.set_duplicates(self._duplicates)
        self._update_dup_chip()
        self._navigate_to(root)
        self._refresh_timeline()
        self.chart_stack.currentWidget().setFocus()
        msg = f"Tarama tamamlandı — {human_size(root.size)}"
        self.scan_status.setText(f"Tarama tamam · {root.file_count:,} dosya")
        self.statusBar().showMessage(msg)
        self.state_banner.show_message(
            "success",
            "Tarama tamam",
            f"{root.file_count:,} dosya tarandı; sonuçlar önbelleğe kaydedildi.",
        )
        QTimer.singleShot(3200, self.state_banner.hide_banner)
        if self._tray:
            self._tray.showMessage("Disk Alanı Görselleştirici", msg, QSystemTrayIcon.MessageIcon.Information, 4000)

    def _update_dup_chip(self) -> None:
        count = len(self._duplicates)
        if count:
            self.dup_chip.setText(f"{count} tekrar adayı")
            self.dup_chip.show()
        else:
            self.dup_chip.hide()

    def _on_scan_error(self, message: str) -> None:
        self._scanning = False
        self._set_scan_ui(False)
        self.progress.hide()
        self.scan_status.setText("")
        self.state_banner.show_message("danger", "Tarama hatası", message)
        QMessageBox.warning(self, "Tarama hatası", message)

    def _refresh_timeline(self) -> None:
        if not self._scan_root or not self._root:
            self.sidebar.set_snapshots([])
            return
        # list_history en yeniden eskiye döner; zaman çizelgesi eskiden yeniye bekler
        # (sonuncusu "Bugün").
        snaps = list(reversed(list_history(self._scan_root)))
        self.sidebar.set_snapshots(snaps, current_size=self._root.size)

    def _load_snapshot(self, snapshot_id: int) -> None:
        node = load_snapshot(snapshot_id)
        if not node:
            return
        self._root = node
        self._large_files = large_files_in(node)
        self._navigate_to(node)
        self.statusBar().showMessage(f"Zaman makinesi: {human_size(node.size)}")

    def _navigate_to(self, node: ScanNode) -> None:
        if not self._root:
            return
        trail: list[ScanNode] = []
        self._build_trail(self._root, node.path, trail)
        if not trail:
            trail = [node]
        self._trail = trail
        self._focus = node
        self.breadcrumb.set_trail(trail)
        self._refresh_charts()
        self.sidebar.set_context(node, root_size=self._root.size, large_files=self._large_files)

    def _build_trail(self, node: ScanNode, target_path: str, trail: list[ScanNode]) -> bool:
        trail.append(node)
        if node.path.rstrip("\\") == target_path.rstrip("\\"):
            return True
        for child in node.children:
            tp = target_path.rstrip("\\")
            cp = child.path.rstrip("\\")
            if tp == cp or tp.startswith(cp + "\\"):
                if self._build_trail(child, target_path, trail):
                    return True
        trail.pop()
        return False

    def _drill_to(self, node: ScanNode) -> None:
        if node.is_dir:
            self._navigate_to(node)

    def _go_up(self) -> None:
        if len(self._trail) > 1:
            self._navigate_to(self._trail[-2])

    def _cancel_or_root(self) -> None:
        if self._scanning:
            self._cancel_scan(user_initiated=True)
        elif self._root:
            self._go_root()

    def _go_root(self) -> None:
        if self._root:
            self._navigate_to(self._root)

    def _refresh_charts(self) -> None:
        if not self._root or not self._focus:
            return
        self.sunburst.set_data(self._root, self._focus)
        self.treemap.set_data(self._root, self._focus)

    def _set_view(self, index: int) -> None:
        self.chart_stack.setCurrentIndex(index)
        self._settings.view_index = index
        SettingsStore.instance().save()
        self.sunburst_btn.setObjectName("ViewToggleActive" if index == 0 else "ViewToggleBtn")
        self.treemap_btn.setObjectName("ViewToggleActive" if index == 1 else "ViewToggleBtn")
        self.sunburst_btn.setStyle(self.sunburst_btn.style())
        self.treemap_btn.setStyle(self.treemap_btn.style())

    def _on_hover(self, node: ScanNode) -> None:
        self.statusBar().showMessage(
            f"{node.name} — {human_size(node.size)} · {node.file_count:,} dosya"
        )

    def _context_menu(self, node: ScanNode, global_pos) -> None:
        menu = QMenu(self)
        menu.addAction("Explorer'da göster", lambda: reveal_in_explorer(node.path))
        if node.is_dir:
            menu.addAction("Burayı tara", lambda: self._rescan_path(node.path))
            menu.addAction("İçine gir", lambda: self._drill_to(node))
        menu.addAction("Çöpe taşı", lambda: self._confirm_delete(node.path))
        menu.exec(global_pos)

    def _rescan_path(self, path: str) -> None:
        self._scan_root = path
        self._start_scan(use_cache=False)

    def _export_menu(self) -> None:
        if not self._root:
            QMessageBox.information(self, "Dışa aktar", "Önce bir tarama yapın.")
            return

        dest, _ = QFileDialog.getSaveFileName(
            self,
            "Dışa aktar",
            f"disk-raporu-{self._root.name}",
            "PNG (*.png);;SVG (*.svg);;JSON (*.json);;CSV (*.csv);;HTML (*.html)",
        )
        if not dest:
            return

        path = Path(dest)
        try:
            chart = self.sunburst if self.chart_stack.currentIndex() == 0 else self.treemap
            ext = path.suffix.lower()
            if ext == ".png":
                chart.grab().save(str(path))
            elif ext == ".svg":
                from PySide6.QtCore import QPoint
                from PySide6.QtGui import QPainter
                from PySide6.QtSvg import QSvgGenerator

                gen = QSvgGenerator()
                gen.setFileName(str(path))
                gen.setSize(chart.size())
                gen.setViewBox(chart.rect())
                painter = QPainter(gen)
                try:
                    # PySide6'da painter'lı render için hedef ofseti zorunlu.
                    chart.render(painter, QPoint())
                finally:
                    painter.end()
            elif ext == ".json":
                export_json(self._root, path)
            elif ext == ".csv":
                export_csv(self._root, path)
            elif ext == ".html":
                png_side = path.with_suffix(".png")
                self.sunburst.grab().save(str(png_side))
                export_html(self._root, path, chart_png_path=png_side.name)
            else:
                export_json(self._root, path.with_suffix(".json"))
            self.statusBar().showMessage(f"Dışa aktarıldı: {path}")
        except OSError as exc:
            QMessageBox.warning(self, "Dışa aktar", str(exc))

    def _show_duplicates(self) -> None:
        if not self._duplicates:
            if self._root:
                min_dup = self._settings.min_duplicate_size_mb * 1024 * 1024
                self._duplicates = find_duplicate_candidates(self._root, min_size=min_dup)
            if not self._duplicates:
                QMessageBox.information(
                    self, "Tekrar adayları", "Aynı boyutlu dosya grubu bulunamadı (önce tarayın ya da Ayarlar'dan alt sınırı düşürün)."
                )
                return
        DuplicatesDialog(self._duplicates, self).exec()

    def _confirm_delete(self, path: str) -> None:
        answer = QMessageBox.question(
            self,
            "Çöpe taşı",
            f"Bu öğe geri dönüşüm kutusuna taşınsın mı?\n\n{path}",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if answer != QMessageBox.StandardButton.Yes:
            return
        try:
            move_to_trash(path)
        except Exception as exc:  # noqa: BLE001
            QMessageBox.warning(self, "Hata", str(exc))
            return
        self._forget_path(path)
        self.statusBar().showMessage(f"Çöpe taşındı: {path}")

    def _forget_path(self, path: str) -> None:
        """Çöpe taşınan öğeyi ekrandaki ağaçtan ve önbellekten düşer; aksi halde grafik
        ve F5 (önbellek) silinmiş dosyaları göstermeye devam eder."""
        try:
            invalidate_cache_for(path)
        except Exception:  # noqa: BLE001 - önbellek hatası silmeyi geri almaz
            pass
        if not self._root or self._root.remove_descendant(path) is None:
            return
        self._large_files = [f for f in self._large_files if not is_same_or_under(f.path, path)]
        min_dup = self._settings.min_duplicate_size_mb * 1024 * 1024
        self._duplicates = find_duplicate_candidates(self._root, min_size=min_dup)
        self.sidebar.set_duplicates(self._duplicates)
        self._update_dup_chip()
        focus = self._focus
        if focus is None or is_same_or_under(focus.path, path):
            focus = self._trail[0] if self._trail else self._root
            for node in self._trail:
                if is_same_or_under(node.path, path):
                    break
                focus = node
        self._navigate_to(focus)

    def _open_settings(self) -> None:
        dlg = SettingsDialog(self._settings, self)
        if dlg.exec():
            self._settings = dlg.result_settings
            SettingsStore.instance().settings = self._settings
            SettingsStore.instance().save()
            if self._root:  # alt sınır değiştiyse adaylar hemen güncellensin
                min_dup = self._settings.min_duplicate_size_mb * 1024 * 1024
                self._duplicates = find_duplicate_candidates(self._root, min_size=min_dup)
                self.sidebar.set_duplicates(self._duplicates)
                self._update_dup_chip()

    def _open_about(self) -> None:
        AboutDialog(self).exec()

    def _open_help(self) -> None:
        HelpDialog(self).exec()

    def _check_scheduled_scan(self) -> None:
        if not self._settings.scheduled_scan_enabled or self._scanning:
            return  # kullanıcının süren taramasını iptal etme; bir sonraki saatte denenir
        last = self._settings.last_scheduled_scan_utc
        now = datetime.now(timezone.utc)
        if last:
            try:
                prev = datetime.fromisoformat(last)
                if (now - prev).days < self._settings.scheduled_scan_days:
                    return
            except ValueError:
                pass
        self._scan_root = self._settings.scheduled_scan_root
        self._settings.last_scheduled_scan_utc = now.isoformat()
        SettingsStore.instance().save()
        self._start_scan(use_cache=False)

    def closeEvent(self, event) -> None:  # noqa: N802
        self._cancel_scan()
        if self._tray:
            self._tray.hide()
        super().closeEvent(event)
