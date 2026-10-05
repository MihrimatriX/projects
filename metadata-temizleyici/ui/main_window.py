from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QAction, QIcon, QKeySequence, QShortcut
from PySide6.QtWidgets import (
    QApplication,
    QButtonGroup,
    QCheckBox,
    QFrame,
    QFileDialog,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QMenu,
    QPlainTextEdit,
    QProgressBar,
    QPushButton,
    QStackedWidget,
    QStatusBar,
    QSystemTrayIcon,
    QTableWidget,
    QTableWidgetItem,
    QVBoxLayout,
    QWidget,
    QDialog,
    QHeaderView,
)

from ui.theme import APP_STYLE, DANGER, SUCCESS, TEXT_MUTED, WARNING
from ui.widgets.custom_tags_dialog import CustomTagsDialog
from ui.widgets.diff_dialog import DiffDialog
from ui.widgets.drop_zone import DropZone
from ui.widgets.metadata_table import MetadataTable
from utils import exiftool_engine
from utils.app_paths import asset_path, ROOT
from utils.audit import AuditLog
from utils.batch_worker import BatchItemResult, BatchWorker
from utils.config import APP_VERSION, AppSettings, SETTINGS_FILE
from utils.metadata import (
    EXIFTOOL_REQUIRED_MESSAGE,
    collect_files,
    count_needing_exiftool,
    predict_removed_tag_names,
    read_metadata_tags,
)
from utils.metadata_export import export_tags_json
from utils.models import StripResult
from utils.platform_open import reveal_in_folder
from utils.presets import PRESETS, StripMode
from utils.restore import has_backup, restore_backup
from utils.watcher import FolderWatcher

VIEW_COPY = {
    "clean": ("Ana Pencere", "Dosya ekle, hassas tag'leri seç, yedekli temizleme başlat."),
    "batch": ("Batch İşlem", "Paralel worker durumu, hata satırları ve iptal kontrolü."),
    "audit": ("Audit Export", "KVKK kanıt metni, CSV özeti ve hash doğrulama kaydı."),
    "settings": ("Ayarlar", "Watcher, yedek varsayılanı ve preset listelerini yönet."),
}

CHIP_PRESETS = [
    ("social_media", "Sosyal medya"),
    ("gps_only", "Yalnızca GPS"),
    ("camera_only", "Kamera bilgisi"),
    ("custom", "Özel"),
]


class MainWindow(QMainWindow):
    append_log = Signal(str)

    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle(f"Metadata Temizleyici v{APP_VERSION}")
        self.setMinimumSize(1024, 720)
        self.resize(1120, 800)
        self.setStyleSheet(APP_STYLE)

        self._settings = AppSettings.load()
        self._files: list[Path] = []
        self._preview_index = 0
        self._worker: BatchWorker | None = None
        self._queue_status: dict[str, str] = {}
        self._audit = AuditLog()
        self._last_result: StripResult | None = None
        self._watcher = FolderWatcher()
        self._tray: QSystemTrayIcon | None = None
        self._tray_stop_action: QAction | None = None
        self._force_quit = False
        self._scan_mode = "file"
        self._active_preset = self._settings.last_preset_id
        self._custom_tags: list[str] = []

        central = QWidget()
        central.setObjectName("CentralWidget")
        shell = QHBoxLayout(central)
        shell.setContentsMargins(0, 0, 0, 0)
        shell.setSpacing(0)

        shell.addWidget(self._build_sidebar())
        shell.addWidget(self._build_main_area(), stretch=1)

        self.setCentralWidget(central)
        self.setStatusBar(QStatusBar())
        self._build_menu()
        self.append_log.connect(self._append_audit_preview)
        self._setup_shortcuts()
        self._setup_tray()
        self._select_preset_chip(self._active_preset)
        self._update_engine_status()
        self._set_view("clean")

        if self._settings.watch_enabled and self._settings.watch_directory:
            self._start_watcher(self._settings.watch_directory)

    def _build_sidebar(self) -> QFrame:
        sidebar = QFrame()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(260)
        layout = QVBoxLayout(sidebar)
        layout.setContentsMargins(14, 18, 14, 18)
        layout.setSpacing(18)

        brand = QHBoxLayout()
        mark = QLabel("🛡")
        mark.setFixedSize(38, 38)
        mark.setAlignment(Qt.AlignmentFlag.AlignCenter)
        mark.setStyleSheet(
            f"background: #15202b; border: 1px solid #38444d; border-radius: 10px; font-size: 18px;"
        )
        title_box = QVBoxLayout()
        title = QLabel("Metadata Temizleyici")
        title.setObjectName("AppTitle")
        subtitle = QLabel("Yerel EXIF gizlilik aracı")
        subtitle.setObjectName("AppSubtitle")
        title_box.addWidget(title)
        title_box.addWidget(subtitle)
        brand.addWidget(mark)
        brand.addLayout(title_box)
        layout.addLayout(brand)

        self._nav_group = QButtonGroup(self)
        self._nav_group.setExclusive(True)
        nav_layout = QVBoxLayout()
        nav_layout.setSpacing(6)
        self._nav_buttons: dict[str, QPushButton] = {}
        for key, label in [
            ("clean", "Temizle"),
            ("batch", "Batch"),
            ("audit", "Audit"),
            ("settings", "Ayarlar"),
        ]:
            btn = QPushButton(label)
            btn.setObjectName("NavButton")
            btn.setCheckable(True)
            btn.clicked.connect(lambda checked, k=key: self._set_view(k) if checked else None)
            self._nav_group.addButton(btn)
            self._nav_buttons[key] = btn
            nav_layout.addWidget(btn)
        layout.addLayout(nav_layout)

        side_card = QFrame()
        side_card.setObjectName("SideCard")
        card_layout = QVBoxLayout(side_card)
        card_layout.setContentsMargins(14, 14, 14, 14)
        card_layout.setSpacing(10)
        self._exiftool_pill = QLabel("Hazır")
        self._exiftool_pill.setObjectName("PillSuccess")
        card_layout.addWidget(self._status_row("Exiftool", self._exiftool_pill))
        card_layout.addWidget(self._status_row("Çalışma modu", QLabel("Buluta çıkmaz")))
        shortcut = QLabel("Ctrl+Enter")
        shortcut.setStyleSheet(f"font-family: monospace; color: {TEXT_MUTED}; font-size: 12px;")
        card_layout.addWidget(self._status_row("Kısayol", shortcut))
        layout.addStretch()
        layout.addWidget(side_card)
        return sidebar

    def _status_row(self, label: str, value_widget: QWidget) -> QWidget:
        row = QWidget()
        h = QHBoxLayout(row)
        h.setContentsMargins(0, 0, 0, 0)
        left = QLabel(label)
        left.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
        h.addWidget(left)
        h.addStretch()
        if isinstance(value_widget, QLabel):
            h.addWidget(value_widget)
        else:
            h.addWidget(value_widget)
        return row

    def _build_main_area(self) -> QWidget:
        area = QWidget()
        layout = QVBoxLayout(area)
        layout.setContentsMargins(18, 18, 18, 16)
        layout.setSpacing(16)

        self._title_bar = QFrame()
        self._title_bar.setObjectName("TitleBar")
        title_layout = QHBoxLayout(self._title_bar)
        title_layout.setContentsMargins(16, 12, 16, 12)
        copy_box = QVBoxLayout()
        self._view_title = QLabel()
        self._view_title.setObjectName("ViewTitle")
        self._view_desc = QLabel()
        self._view_desc.setObjectName("ViewDescription")
        copy_box.addWidget(self._view_title)
        copy_box.addWidget(self._view_desc)
        title_layout.addLayout(copy_box)
        title_layout.addStretch()

        actions = QHBoxLayout()
        local_pill = QLabel("Yerel işlem")
        local_pill.setObjectName("PillSuccess")
        ver_pill = QLabel(f"PySide6 v{APP_VERSION}")
        ver_pill.setObjectName("Pill")
        folder_btn = QPushButton("Klasör seç")
        folder_btn.setObjectName("SecondaryButton")
        folder_btn.clicked.connect(self._pick_folder)
        file_btn = QPushButton("Dosya seç")
        file_btn.setObjectName("SecondaryButton")
        actions.addWidget(local_pill)
        actions.addWidget(ver_pill)
        actions.addWidget(folder_btn)
        actions.addWidget(file_btn)
        title_layout.addLayout(actions)
        layout.addWidget(self._title_bar)

        self._views = QStackedWidget()
        self._views.addWidget(self._build_clean_view())
        file_btn.clicked.connect(self.drop_zone.pick_files)
        self._views.addWidget(self._build_batch_view())
        self._views.addWidget(self._build_audit_view())
        self._views.addWidget(self._build_settings_view())
        layout.addWidget(self._views, stretch=1)
        return area

    def _build_clean_view(self) -> QWidget:
        page = QWidget()
        grid = QGridLayout(page)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setSpacing(16)

        main_panel = QFrame()
        main_panel.setObjectName("Panel")
        main_layout = QVBoxLayout(main_panel)
        main_layout.setContentsMargins(0, 0, 0, 0)

        header = QHBoxLayout()
        header.setContentsMargins(18, 16, 18, 16)
        hcopy = QVBoxLayout()
        htitle = QLabel("Metadata temizleme")
        htitle.setObjectName("PanelTitle")
        hsub = QLabel("GPS, seri numarası, yazar ve kamera izlerini seçerek kaldır.")
        hsub.setObjectName("PanelSubtitle")
        hcopy.addWidget(htitle)
        hcopy.addWidget(hsub)
        diff_btn = QPushButton("Önce/sonra")
        diff_btn.setObjectName("GhostButton")
        diff_btn.clicked.connect(self._show_diff)
        header.addLayout(hcopy)
        header.addStretch()
        header.addWidget(diff_btn)
        self._diff_btn = diff_btn
        sep = QFrame()
        sep.setFixedHeight(1)
        sep.setStyleSheet(f"background: {TEXT_MUTED}; max-height: 1px;")
        main_layout.addLayout(header)
        main_layout.addWidget(sep)

        body = QVBoxLayout()
        body.setContentsMargins(18, 18, 18, 18)
        body.setSpacing(14)

        self.drop_zone = DropZone()
        self.drop_zone.files_dropped.connect(self._on_paths_added)
        body.addWidget(self.drop_zone)

        folder_strip = QFrame()
        folder_strip.setObjectName("FolderStrip")
        fs_layout = QHBoxLayout(folder_strip)
        fs_layout.setContentsMargins(12, 10, 12, 10)
        self._scan_mode_label = QLabel("Tekil dosya")
        self._scan_mode_label.setObjectName("Pill")
        self._scan_detail = QLabel(
            "Ctrl+Shift+O ile klasör seç; exiftool metadata gördüğü her dosyada çalışır."
        )
        self._scan_detail.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
        fs_layout.addWidget(self._scan_mode_label)
        fs_layout.addWidget(self._scan_detail, stretch=1)
        body.addWidget(folder_strip)

        self._state_note = QFrame()
        self._state_note.setObjectName("StateNote")
        sn_layout = QVBoxLayout(self._state_note)
        sn_layout.setContentsMargins(12, 10, 12, 10)
        self._state_title = QLabel("Dosya bekleniyor")
        self._state_title.setStyleSheet("font-weight: 600;")
        self._state_detail = QLabel("Sürükle-bırak veya dosya seç ile başlayın.")
        self._state_detail.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
        sn_layout.addWidget(self._state_title)
        sn_layout.addWidget(self._state_detail)
        body.addWidget(self._state_note)

        action_row = QHBoxLayout()
        chip_box = QHBoxLayout()
        self._chip_group = QButtonGroup(self)
        self._chip_group.setExclusive(True)
        self._chip_buttons: dict[str, QPushButton] = {}
        for preset_id, label in CHIP_PRESETS:
            chip = QPushButton(label)
            chip.setObjectName("ChipButton")
            chip.setCheckable(True)
            chip.clicked.connect(lambda checked, p=preset_id: self._on_chip_clicked(p) if checked else None)
            self._chip_group.addButton(chip)
            self._chip_buttons[preset_id] = chip
            chip_box.addWidget(chip)
        action_row.addLayout(chip_box)

        toolbar = QHBoxLayout()
        self.backup_check = QCheckBox("Yedek oluştur")
        self.backup_check.setObjectName("ToggleSwitch")
        self.backup_check.setChecked(self._settings.backup_enabled)
        self.backup_check.toggled.connect(self._on_backup_toggled)
        self.clean_btn = QPushButton("Temizle")
        self.clean_btn.setObjectName("PrimaryButton")
        self.clean_btn.clicked.connect(self._start_batch)
        self.clean_btn.setEnabled(False)
        toolbar.addWidget(self.backup_check)
        toolbar.addWidget(self.clean_btn)
        action_row.addStretch()
        action_row.addLayout(toolbar)
        body.addLayout(action_row)

        table_toolbar = QHBoxLayout()
        table_title = QLabel("EXIF tag'leri")
        table_title.setObjectName("PanelTitle")
        self._preset_label = QLabel("Seçili preset: Sosyal medya")
        self._preset_label.setObjectName("PanelSubtitle")
        table_toolbar.addWidget(table_title)
        table_toolbar.addStretch()
        self._tag_search = QLineEdit()
        self._tag_search.setObjectName("SearchInput")
        self._tag_search.setPlaceholderText("Tag ara…")
        self._tag_search.textChanged.connect(self._filter_tags)
        table_toolbar.addWidget(self._tag_search)
        body.addLayout(table_toolbar)
        body.addWidget(self._preset_label)

        nav_row = QHBoxLayout()
        self.prev_btn = QPushButton("◀")
        self.prev_btn.setObjectName("GhostButton")
        self.prev_btn.setFixedWidth(40)
        self.prev_btn.clicked.connect(self._prev_file)
        self.next_btn = QPushButton("▶")
        self.next_btn.setObjectName("GhostButton")
        self.next_btn.setFixedWidth(40)
        self.next_btn.clicked.connect(self._next_file)
        self.preview_file = QLabel("—")
        self.preview_file.setObjectName("FileName")
        self.reveal_btn = QPushButton("Konumda göster")
        self.reveal_btn.setObjectName("GhostButton")
        self.reveal_btn.clicked.connect(self._reveal_current)
        self.remove_btn = QPushButton("Kuyruktan çıkar")
        self.remove_btn.setObjectName("GhostButton")
        self.remove_btn.clicked.connect(self._remove_current)
        self.restore_btn = QPushButton("Yedekten geri yükle")
        self.restore_btn.setObjectName("GhostButton")
        self.restore_btn.clicked.connect(self._restore_current)
        nav_row.addWidget(self.preview_file)
        nav_row.addStretch()
        nav_row.addWidget(self.reveal_btn)
        nav_row.addWidget(self.remove_btn)
        nav_row.addWidget(self.restore_btn)
        nav_row.addWidget(self.prev_btn)
        nav_row.addWidget(self.next_btn)
        body.addLayout(nav_row)

        self.metadata_table = MetadataTable()
        self.metadata_table.setMinimumHeight(200)
        body.addWidget(self.metadata_table)

        main_layout.addLayout(body)
        grid.addWidget(main_panel, 0, 0)

        side = QVBoxLayout()
        side.setSpacing(16)
        queue_panel = QFrame()
        queue_panel.setObjectName("Panel")
        qp_layout = QVBoxLayout(queue_panel)
        qp_layout.setContentsMargins(18, 16, 18, 18)
        qh = QHBoxLayout()
        qtitle = QLabel("Kuyruk")
        qtitle.setObjectName("PanelTitle")
        self._queue_count_label = QLabel("0 dosya bekliyor")
        self._queue_count_label.setObjectName("PanelSubtitle")
        self._queue_batch_pill = QLabel("Batch %0")
        self._queue_batch_pill.setObjectName("Pill")
        qh.addWidget(qtitle)
        qh.addStretch()
        qh.addWidget(self._queue_batch_pill)
        qp_layout.addLayout(qh)
        qp_layout.addWidget(self._queue_count_label)

        prog_meta = QHBoxLayout()
        self._progress_label = QLabel("0 / 0 tamamlandı")
        self._progress_label.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
        self._current_file_label = QLabel("—")
        self._current_file_label.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
        prog_meta.addWidget(self._progress_label)
        prog_meta.addStretch()
        prog_meta.addWidget(self._current_file_label)
        qp_layout.addLayout(prog_meta)

        self.progress = QProgressBar()
        self.progress.setRange(0, 100)
        self.progress.setValue(0)
        qp_layout.addWidget(self.progress)

        self._queue_container = QVBoxLayout()
        self._queue_container.setSpacing(8)
        qp_layout.addLayout(self._queue_container)

        self.cancel_btn = QPushButton("İptal")
        self.cancel_btn.setObjectName("GhostButton")
        self.cancel_btn.clicked.connect(self._cancel_batch)
        self.cancel_btn.hide()
        qp_layout.addWidget(self.cancel_btn)

        side.addWidget(queue_panel)

        privacy_panel = QFrame()
        privacy_panel.setObjectName("Panel")
        pp_layout = QVBoxLayout(privacy_panel)
        pp_layout.setContentsMargins(18, 16, 18, 18)
        pt = QLabel("Gizlilik özeti")
        pt.setObjectName("PanelTitle")
        pp_layout.addWidget(pt)
        self._privacy_cloud = QLabel("Buluta yükleme: Kapalı")
        self._privacy_hash = QLabel("Hash doğrulama: Aktif")
        self._privacy_backup = QLabel("Yedek varsayılanı: Açık")
        self._selected_risk_label = QLabel("Seçili riskli tag: 0")
        for w in (self._privacy_cloud, self._privacy_hash, self._privacy_backup, self._selected_risk_label):
            w.setStyleSheet(f"padding: 8px 0; color: {TEXT_MUTED}; font-size: 13px;")
            pp_layout.addWidget(w)
        side.addWidget(privacy_panel)
        side.addStretch()

        side_widget = QWidget()
        side_widget.setLayout(side)
        side_widget.setMinimumWidth(320)
        grid.addWidget(side_widget, 0, 1)
        grid.setColumnStretch(0, 3)
        grid.setColumnStretch(1, 2)
        return page

    def _build_batch_view(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        panel = QFrame()
        panel.setObjectName("Panel")
        pl = QVBoxLayout(panel)
        pl.setContentsMargins(18, 16, 18, 18)

        header = QHBoxLayout()
        hcopy = QVBoxLayout()
        hcopy.addWidget(self._make_title("Batch işlem görünümü"))
        hcopy.addWidget(self._make_subtitle("Paralel worker durumu ve hata satırları."))
        header.addLayout(hcopy)
        header.addStretch()
        self._open_errors_btn = QPushButton("Hata listesini aç")
        self._open_errors_btn.setObjectName("GhostButton")
        self._open_errors_btn.clicked.connect(self._focus_batch_errors)
        header.addWidget(self._open_errors_btn)
        pl.addLayout(header)

        worker_grid = QHBoxLayout()
        self._worker_labels: list[QLabel] = []
        for i in range(3):
            w = QLabel(f"Worker {i + 1}: Beklemede")
            w.setStyleSheet(
                f"padding: 12px; border: 1px solid #38444d; border-radius: 8px; "
                f"background: #15202b; color: {TEXT_MUTED}; font-size: 12px;"
            )
            self._worker_labels.append(w)
            worker_grid.addWidget(w)
        pl.addLayout(worker_grid)

        stats = QHBoxLayout()
        self._batch_total_label = QLabel("0 dosya")
        self._batch_total_label.setObjectName("PanelTitle")
        stats.addWidget(self._batch_total_label)
        stats.addStretch()
        pl.addLayout(stats)

        self.batch_table = QTableWidget(0, 4)
        self.batch_table.setObjectName("BatchTable")
        self.batch_table.setHorizontalHeaderLabels(["Dosya", "Durum", "Preset", "Mesaj"])
        self.batch_table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.batch_table.verticalHeader().setVisible(False)
        self.batch_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        pl.addWidget(self.batch_table)

        self.dry_run_check = QCheckBox("Simülasyon (dosyaya yazma)")
        pl.addWidget(self.dry_run_check)

        layout.addWidget(panel)
        return page

    def _build_audit_view(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        panel = QFrame()
        panel.setObjectName("Panel")
        pl = QVBoxLayout(panel)
        pl.setContentsMargins(18, 16, 18, 18)

        header = QHBoxLayout()
        hcopy = QVBoxLayout()
        hcopy.addWidget(self._make_title("Audit export"))
        hcopy.addWidget(self._make_subtitle("KVKK kanıt metni, CSV özeti ve hash doğrulama kaydı."))
        header.addLayout(hcopy)
        header.addStretch()
        copy_btn = QPushButton("Kanıt metnini kopyala")
        copy_btn.setObjectName("SecondaryButton")
        copy_btn.clicked.connect(self._copy_audit)
        export_btn = QPushButton("CSV dışa aktar")
        export_btn.setObjectName("PrimaryButton")
        export_btn.clicked.connect(self._export_audit)
        header.addWidget(copy_btn)
        header.addWidget(export_btn)
        pl.addLayout(header)

        self._audit_scope = QLabel("0 dosya")
        self._audit_scope.setObjectName("PanelSubtitle")
        pl.addWidget(self._audit_scope)

        self.audit_preview = QPlainTextEdit()
        self.audit_preview.setObjectName("AuditPreview")
        self.audit_preview.setReadOnly(True)
        self.audit_preview.setPlaceholderText("Batch sonrası audit kayıtları burada görünür…")
        pl.addWidget(self.audit_preview)

        warn = QLabel(
            "Hash uyarısı: Piksel verisi değişir ama görüntü aynı kalırsa sarı uyarı audit kaydına eklenir."
        )
        warn.setStyleSheet(f"color: {WARNING}; font-size: 12px; padding: 8px; background: rgba(255,173,32,0.14); border-radius: 8px;")
        pl.addWidget(warn)
        layout.addWidget(panel)
        return page

    def _build_settings_view(self) -> QWidget:
        page = QWidget()
        layout = QVBoxLayout(page)
        panel = QFrame()
        panel.setObjectName("Panel")
        pl = QVBoxLayout(panel)
        pl.setContentsMargins(18, 16, 18, 18)

        header = QHBoxLayout()
        hcopy = QVBoxLayout()
        hcopy.addWidget(self._make_title("Ayarlar ve watcher"))
        hcopy.addWidget(self._make_subtitle("Opt-in klasör izleme, yedek varsayılanı ve preset yönetimi."))
        header.addLayout(hcopy)
        header.addStretch()
        config_btn = QPushButton("Ayar dosyasını aç")
        config_btn.setObjectName("SecondaryButton")
        config_btn.clicked.connect(self._open_config)
        header.addWidget(config_btn)
        pl.addLayout(header)

        watcher_row = QHBoxLayout()
        watcher_copy = QVBoxLayout()
        self._watcher_status = QLabel("Klasör izleme kapalı")
        self._watcher_status.setObjectName("PanelTitle")
        watcher_help = QLabel("Açıldığında sistem tepsisi dosya sayacı gösterir.")
        watcher_help.setObjectName("PanelSubtitle")
        watcher_copy.addWidget(self._watcher_status)
        watcher_copy.addWidget(watcher_help)
        watcher_row.addLayout(watcher_copy)
        watcher_row.addStretch()
        self.watch_check = QCheckBox("İzle")
        self.watch_check.setObjectName("ToggleSwitch")
        self.watch_check.setChecked(self._settings.watch_enabled)
        self.watch_check.toggled.connect(self._on_watch_toggled)
        watcher_row.addWidget(self.watch_check)
        pl.addLayout(watcher_row)

        watch_path_row = QHBoxLayout()
        self.watch_path = QLabel(self._settings.watch_directory or "Klasör seçilmedi")
        self.watch_path.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
        pick_watch = QPushButton("İzleme klasörü")
        pick_watch.setObjectName("GhostButton")
        pick_watch.clicked.connect(self._pick_watch_folder)
        watch_path_row.addWidget(self.watch_path, stretch=1)
        watch_path_row.addWidget(pick_watch)
        pl.addLayout(watch_path_row)

        settings_backup_row = QHBoxLayout()
        sb_copy = QVBoxLayout()
        self._settings_backup_status = QLabel("Temizlemeden önce .bak oluştur")
        self._settings_backup_status.setObjectName("PanelTitle")
        sb_help = QLabel("Kapalıysa destructive confirm gerekir.")
        sb_help.setObjectName("PanelSubtitle")
        sb_copy.addWidget(self._settings_backup_status)
        sb_copy.addWidget(sb_help)
        settings_backup_row.addLayout(sb_copy)
        settings_backup_row.addStretch()
        self.settings_backup_check = QCheckBox("Açık")
        self.settings_backup_check.setObjectName("ToggleSwitch")
        self.settings_backup_check.setChecked(self._settings.backup_enabled)
        self.settings_backup_check.toggled.connect(self._on_settings_backup_toggled)
        settings_backup_row.addWidget(self.settings_backup_check)
        pl.addLayout(settings_backup_row)

        custom_btn = QPushButton("Özel preset düzenle")
        custom_btn.setObjectName("GhostButton")
        custom_btn.clicked.connect(self._strip_custom_tags)
        pl.addWidget(custom_btn)

        self.auto_audit_check = QCheckBox("Batch sonrası otomatik CSV")
        self.auto_audit_check.setChecked(self._settings.auto_export_audit)
        self.auto_audit_check.toggled.connect(self._on_auto_audit_toggled)
        pl.addWidget(self.auto_audit_check)

        clear_btn = QPushButton("Listeyi temizle")
        clear_btn.setObjectName("GhostButton")
        clear_btn.clicked.connect(self._clear_queue)
        pl.addWidget(clear_btn)

        preset_table = QTableWidget(len(PRESETS), 3)
        preset_table.setHorizontalHeaderLabels(["Preset", "Tag kapsamı", "Durum"])
        preset_table.verticalHeader().setVisible(False)
        preset_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        for row, preset in enumerate(PRESETS.values()):
            preset_table.setItem(row, 0, QTableWidgetItem(preset.id))
            preset_table.setItem(row, 1, QTableWidgetItem(", ".join(preset.exiftool_args[:4])))
            status = "Aktif" if preset.id == self._active_preset else "Hazır"
            preset_table.setItem(row, 2, QTableWidgetItem(status))
        preset_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        pl.addWidget(preset_table)

        layout.addWidget(panel)
        return page

    def _make_title(self, text: str) -> QLabel:
        label = QLabel(text)
        label.setObjectName("PanelTitle")
        return label

    def _make_subtitle(self, text: str) -> QLabel:
        label = QLabel(text)
        label.setObjectName("PanelSubtitle")
        return label

    def _set_view(self, key: str) -> None:
        index = {"clean": 0, "batch": 1, "audit": 2, "settings": 3}[key]
        self._views.setCurrentIndex(index)
        for k, btn in self._nav_buttons.items():
            btn.setChecked(k == key)
        title, desc = VIEW_COPY[key]
        self._view_title.setText(title)
        self._view_desc.setText(desc)

    def _build_menu(self) -> None:
        menu = self.menuBar()
        file_menu = menu.addMenu("Dosya")
        open_action = QAction("Dosya ekle…", self)
        open_action.setShortcut(QKeySequence.StandardKey.Open)
        open_action.triggered.connect(lambda: self.drop_zone.pick_files())
        file_menu.addAction(open_action)
        file_menu.addAction("Kuyruktan çıkar", self._remove_current)
        file_menu.addAction("Listeyi temizle", self._clear_queue)
        file_menu.addSeparator()
        file_menu.addAction("Çıkış", self.close)

        tools_menu = menu.addMenu("Araçlar")
        tools_menu.addAction("Özel tag listesi…", self._strip_custom_tags)
        tools_menu.addAction("Yedekten geri yükle", self._restore_current)
        tools_menu.addAction("Metadata JSON export", self._export_json)
        tools_menu.addAction("CSV audit raporu", self._export_audit)
        tools_menu.addAction("Simülasyonu çalıştır", self._start_batch)

        help_menu = menu.addMenu("Yardım")
        help_menu.addAction("Hakkında", self._show_about)

    def _setup_shortcuts(self) -> None:
        QShortcut(QKeySequence("Ctrl+Return"), self, self._start_batch)
        QShortcut(QKeySequence("Escape"), self, self._cancel_batch)
        QShortcut(QKeySequence("Ctrl+Shift+O"), self, self._pick_folder)

    def _select_preset_chip(self, preset_id: str) -> None:
        if preset_id == "custom":
            btn = self._chip_buttons.get("custom")
            if btn:
                btn.setChecked(True)
            self._active_preset = "custom"
            self._preset_label.setText("Seçili preset: Özel")
            return
        for pid, btn in self._chip_buttons.items():
            btn.setChecked(pid == preset_id)
        self._active_preset = preset_id
        preset = PRESETS.get(preset_id)
        label = preset.label if preset else preset_id
        self._preset_label.setText(f"Seçili preset: {label}")
        self._settings.last_preset_id = preset_id
        self._settings.save()

    def _on_chip_clicked(self, preset_id: str) -> None:
        if preset_id == "custom":
            self._strip_custom_tags()
            return
        self._select_preset_chip(preset_id)
        self._highlight_preset_tags()

    def _current_strip_mode(self) -> tuple[StripMode, str | None, list[str] | None]:
        if self._active_preset == "custom":
            tags = self._custom_tags or self.metadata_table.selected_tag_names()
            return StripMode.CUSTOM, None, tags
        if self._active_preset == "gps_only":
            return StripMode.GPS_ONLY, None, None
        if self._active_preset == "camera_only":
            return StripMode.CAMERA_ONLY, None, None
        if self._active_preset in PRESETS:
            return StripMode.PRESET, self._active_preset, None
        return StripMode.ALL, None, None

    def _show_about(self) -> None:
        exif = "kurulu" if exiftool_engine.is_available() else "yok"
        ver = exiftool_engine.version() or "—"
        QMessageBox.about(
            self,
            "Metadata Temizleyici",
            f"Sürüm {APP_VERSION}\n\n"
            "EXIF/GPS metadata toplu temizleyici.\n"
            "Tüm işlemler yerelde yapılır.\n\n"
            f"exiftool: {exif} ({ver})\n"
            "Lisans: MIT",
        )

    def _on_paths_added(self, paths: list[str], *, scan_mode: str = "file") -> None:
        dirs = [Path(p) for p in paths if Path(p).is_dir()]
        if dirs:
            estimate = sum(len(collect_files([str(d)], recursive=True)) for d in dirs)
            answer = QMessageBox.question(
                self,
                "Klasör taraması",
                f"{len(dirs)} klasör alt dosyalarıyla taranacak.\n"
                f"Yaklaşık {estimate} desteklenen dosya bulundu.\n\nDevam edilsin mi?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
                QMessageBox.StandardButton.Yes,
            )
            if answer != QMessageBox.StandardButton.Yes:
                paths = [p for p in paths if not Path(p).is_dir()]
            else:
                scan_mode = "folder"

        new_files = DropZone.resolve_paths(paths)
        skipped_videos = count_needing_exiftool(paths)
        skipped_note = f" — {skipped_videos} video atlandı: {EXIFTOOL_REQUIRED_MESSAGE}" if skipped_videos else ""
        if not new_files:
            self._set_status("Desteklenen dosya bulunamadı" + skipped_note)
            return

        self._files = list(dict.fromkeys([*self._files, *new_files]))
        if self._preview_index >= len(self._files):
            self._preview_index = 0
        self._scan_mode = scan_mode
        self._scan_mode_label.setText("Klasör batch" if scan_mode == "folder" else "Tekil dosya")
        self._queue_count_label.setText(
            f"{len(self._files)} dosya bekliyor — {'klasör taraması' if scan_mode == 'folder' else 'elle seçildi'}"
        )
        self._batch_total_label.setText(f"{len(self._files)} dosya")
        for path in new_files:
            self._queue_status[str(path)] = "Bekliyor"
        self._rebuild_queue_ui()
        self._rebuild_batch_table()
        self._refresh_preview()
        self._set_action_enabled(bool(self._files))
        self._settings.last_directory = str(self._files[0].parent)
        self._settings.save()
        self._set_status(f"{len(self._files)} dosya kuyrukta" + skipped_note)
        self._set_state_note("", "Metadata analizi tamamlandı", "Riskli tag'ler seçildi; temizlik başlatılabilir.")

    def _pick_folder(self) -> None:
        folder = QFileDialog.getExistingDirectory(
            self,
            "Klasör seç",
            self._settings.last_directory or str(Path.home()),
        )
        if folder:
            self._on_paths_added([folder], scan_mode="folder")

    def _set_action_enabled(self, enabled: bool) -> None:
        busy = self._worker is not None
        self.clean_btn.setEnabled(enabled and not busy)
        self.remove_btn.setEnabled(enabled and not busy)
        self.reveal_btn.setEnabled(enabled and not busy)
        self.dry_run_check.setEnabled(not busy)
        self.drop_zone.setEnabled(not busy)

    def _refresh_preview(self) -> None:
        has_files = bool(self._files)
        self.prev_btn.setEnabled(has_files and len(self._files) > 1)
        self.next_btn.setEnabled(has_files and len(self._files) > 1)

        if not has_files:
            self.preview_file.setText("—")
            self.metadata_table.clear_tags()
            self.restore_btn.setEnabled(False)
            self._selected_risk_label.setText("Seçili riskli tag: 0")
            self._set_state_note("", "Dosya bekleniyor", "Sürükle-bırak veya dosya seç ile başlayın.")
            return

        path = self._files[self._preview_index]
        self.preview_file.setText(f"{path.name} ({self._preview_index + 1}/{len(self._files)})")
        try:
            tags = read_metadata_tags(path)
            self.metadata_table.set_tags(tags)
            self._filter_tags(self._tag_search.text())
            high = sum(1 for t in tags if t.risk == "high")
            backup_note = " · .bak mevcut" if has_backup(path) else ""
            self.restore_btn.setEnabled(has_backup(path))
            self._highlight_preset_tags()
            self._selected_risk_label.setText(f"Seçili riskli tag: {high}")
            if high:
                self._set_state_note(
                    "",
                    "GPS ve hassas tag tespit edildi",
                    f"{len(tags)} tag · {high} yüksek risk{backup_note}",
                )
            else:
                self._set_state_note("", "Metadata okundu", f"{len(tags)} tag bulundu{backup_note}")
        except Exception as exc:
            self.metadata_table.clear_tags()
            self.restore_btn.setEnabled(False)
            self._set_state_note("error", "Önizleme hatası", str(exc))

    def _highlight_preset_tags(self) -> None:
        if not self._files:
            return
        mode, preset_id, custom_tags = self._current_strip_mode()
        try:
            tags = read_metadata_tags(self._files[self._preview_index])
            removed = predict_removed_tag_names(tags, mode, preset_id, custom_tags)
        except Exception:
            return
        for row in range(self.metadata_table.rowCount()):
            item = self.metadata_table.item(row, 0)
            if not item:
                continue
            name = item.data(Qt.ItemDataRole.UserRole)
            if name in removed:
                self.metadata_table.selectRow(row)

    def _filter_tags(self, text: str) -> None:
        needle = text.strip().lower()
        for row in range(self.metadata_table.rowCount()):
            match = not needle
            if not match:
                for col in range(self.metadata_table.columnCount()):
                    item = self.metadata_table.item(row, col)
                    if item and needle in item.text().lower():
                        match = True
                        break
            self.metadata_table.setRowHidden(row, not match)

    def _set_state_note(self, kind: str, title: str, detail: str) -> None:
        self._state_title.setText(title)
        self._state_detail.setText(detail)
        color = TEXT_MUTED
        if kind == "error":
            color = DANGER
        elif kind == "warning":
            color = WARNING
        elif kind == "loading":
            color = SUCCESS
        self._state_title.setStyleSheet(f"font-weight: 600; color: {color};")

    def _on_backup_toggled(self, checked: bool) -> None:
        self._settings.backup_enabled = checked
        self.settings_backup_check.setChecked(checked)
        self._privacy_backup.setText(f"Yedek varsayılanı: {'Açık' if checked else 'Kapalı'}")
        self._settings_backup_status.setText(
            "Temizlemeden önce .bak oluştur" if checked else "Yedek kapalı — üzerine yazılır"
        )
        self._settings.save()

    def _on_settings_backup_toggled(self, checked: bool) -> None:
        self.backup_check.setChecked(checked)
        self._on_backup_toggled(checked)

    def _on_auto_audit_toggled(self, checked: bool) -> None:
        self._settings.auto_export_audit = checked
        if checked and not self._settings.audit_directory:
            folder = QFileDialog.getExistingDirectory(self, "CSV rapor klasörü", self._settings.last_directory)
            if folder:
                self._settings.audit_directory = folder
            else:
                self.auto_audit_check.setChecked(False)
                return
        self._settings.save()

    def _confirm_without_backup(self) -> bool:
        if self.dry_run_check.isChecked():
            return True
        if self._settings.backup_enabled:
            return True
        answer = QMessageBox.warning(
            self,
            "Yedek kapalı",
            "Orijinal yedek oluşturulmayacak. Dosyalar doğrudan üzerine yazılır.\n\nDevam edilsin mi?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        if answer != QMessageBox.StandardButton.Yes:
            return False
        answer2 = QMessageBox.warning(
            self,
            "Son onay",
            "Bu işlem geri alınamaz. Yine de devam edilsin mi?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )
        return answer2 == QMessageBox.StandardButton.Yes

    def _start_batch(self) -> None:
        if not self._files or self._worker is not None:
            return
        if not self._confirm_without_backup():
            return

        mode, preset_id, custom_tags = self._current_strip_mode()
        if mode == StripMode.CUSTOM and not custom_tags:
            QMessageBox.information(self, "Tag yok", "Özel preset veya tablo seçimi gerekli.")
            return

        self.progress.setRange(0, len(self._files))
        self.progress.setValue(0)
        self.clean_btn.setEnabled(False)
        self.cancel_btn.show()
        self.dry_run_check.setEnabled(False)
        self._set_state_note("loading", "Temizlik sürüyor", "Seçili metadata alanları yerelde siliniyor.")

        dry_run = self.dry_run_check.isChecked()
        self._worker = BatchWorker(
            self._files,
            backup=self._settings.backup_enabled,
            overwrite=self._settings.overwrite_in_place,
            mode=mode,
            preset_id=preset_id,
            custom_tags=custom_tags,
            audit=self._audit,
            dry_run=dry_run,
        )
        self._worker.progress.connect(self._on_batch_progress)
        self._worker.item_done.connect(self._on_batch_item)
        self._worker.finished_batch.connect(self._on_batch_finished)
        self._worker.start()

    def _strip_custom_tags(self) -> None:
        dialog = CustomTagsDialog(self)
        if dialog.exec() != QDialog.DialogCode.Accepted:
            return
        tags = dialog.tag_names()
        if not tags:
            QMessageBox.information(self, "Tag yok", "En az bir tag adı girin.")
            return
        self._custom_tags = tags
        self._select_preset_chip("custom")
        if self._files:
            self._highlight_preset_tags()

    def _on_batch_progress(self, current: int, total: int, filename: str) -> None:
        self.progress.setMaximum(total)
        self.progress.setValue(max(0, current - 1))
        pct = int((max(0, current - 1) / total) * 100) if total else 0
        self._progress_label.setText(f"{max(0, current - 1)} / {total} tamamlandı")
        self._current_file_label.setText(filename)
        self._queue_batch_pill.setText(f"Batch %{pct}")
        self._worker_labels[0].setText(f"Worker 1: {filename}")
        for path in self._files:
            key = str(path)
            if path.name == filename:
                self._queue_status[key] = "İşleniyor"
            elif self._queue_status.get(key) == "İşleniyor":
                self._queue_status[key] = "Bekliyor"
        self._rebuild_queue_ui()

    def _on_batch_item(self, result: BatchItemResult) -> None:
        key = str(result.path)
        if result.success:
            self._queue_status[key] = "Temizlendi"
            if result.strip_result:
                self._last_result = result.strip_result
                self._diff_btn.setEnabled(True)
        else:
            self._queue_status[key] = f"Hata: {result.message}"
        self._rebuild_queue_ui()
        self._update_batch_row(result)
        self._refresh_audit_preview()

    def _on_batch_finished(self) -> None:
        total = len(self._files)
        ok = sum(1 for s in self._queue_status.values() if s == "Temizlendi")
        sim = self.dry_run_check.isChecked()
        self.progress.setValue(total)
        label = "Simülasyon tamamlandı" if sim else f"Batch tamamlandı: {ok}/{total}"
        self._progress_label.setText(label)
        self._queue_batch_pill.setText("Batch tamam")
        self._queue_batch_pill.setObjectName("PillSuccess")
        self._set_status(label)
        self.cancel_btn.hide()
        self.dry_run_check.setEnabled(True)
        self._worker = None
        for w in self._worker_labels:
            w.setText(w.text().split(":")[0] + ": Beklemede")
        self._set_action_enabled(bool(self._files))
        if self._files:
            self._preview_index = 0
            self._refresh_preview()
        if self._settings.auto_export_audit and self._settings.audit_directory and not sim:
            dest = Path(self._settings.audit_directory) / f"audit-{APP_VERSION}.csv"
            try:
                self._audit.export_csv(dest)
                self.append_log.emit(f"Otomatik rapor: {dest}")
            except OSError:
                pass
        self._set_state_note("", "Temizlik tamamlandı", label)

    def _cancel_batch(self) -> None:
        if self._worker and self._worker.isRunning():
            self._worker.cancel()
            self._set_status("İptal ediliyor…")

    def _rebuild_queue_ui(self) -> None:
        while self._queue_container.count():
            item = self._queue_container.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        for path in self._files:
            status = self._queue_status.get(str(path), "Bekliyor")
            item_frame = QFrame()
            item_frame.setObjectName("QueueItem")
            row = QHBoxLayout(item_frame)
            row.setContentsMargins(10, 8, 10, 8)
            name_box = QVBoxLayout()
            strong = QLabel(path.name)
            strong.setStyleSheet("font-weight: 600;")
            span = QLabel(status)
            span.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px;")
            name_box.addWidget(strong)
            name_box.addWidget(span)
            pill = QLabel("OK" if status == "Temizlendi" else ("Aktif" if status == "İşleniyor" else "Sıra"))
            if status == "Temizlendi":
                pill.setObjectName("PillSuccess")
            elif status == "İşleniyor":
                pill.setObjectName("PillWarn")
            else:
                pill.setObjectName("Pill")
            row.addLayout(name_box, stretch=1)
            row.addWidget(pill)
            self._queue_container.addWidget(item_frame)

    def _rebuild_batch_table(self) -> None:
        self.batch_table.setRowCount(len(self._files))
        preset_label = PRESETS.get(self._active_preset, PRESETS["social_media"]).label
        for row, path in enumerate(self._files):
            self.batch_table.setItem(row, 0, QTableWidgetItem(path.name))
            status = self._queue_status.get(str(path), "Bekliyor")
            self.batch_table.setItem(row, 1, QTableWidgetItem(status))
            self.batch_table.setItem(row, 2, QTableWidgetItem(preset_label))
            self.batch_table.setItem(row, 3, QTableWidgetItem(""))

    def _update_batch_row(self, result: BatchItemResult) -> None:
        for row in range(self.batch_table.rowCount()):
            item = self.batch_table.item(row, 0)
            if item and item.text() == result.path.name:
                status = "Temizlendi" if result.success else "Hata"
                self.batch_table.setItem(row, 1, QTableWidgetItem(status))
                self.batch_table.setItem(row, 3, QTableWidgetItem(result.message))
                if not result.success:
                    for col in range(self.batch_table.columnCount()):
                        cell = self.batch_table.item(row, col)
                        if cell:
                            cell.setForeground(Qt.GlobalColor.red)
                break

    def _focus_batch_errors(self) -> None:
        self._set_view("batch")
        for row in range(self.batch_table.rowCount()):
            status_item = self.batch_table.item(row, 1)
            if status_item and "Hata" in status_item.text():
                self.batch_table.selectRow(row)
                break

    def _refresh_audit_preview(self) -> None:
        lines = ["timestamp,file,success,removed_tags,hash_changed"]
        for e in self._audit.entries:
            lines.append(
                f"{e.timestamp},{e.file_path},{e.success},{e.removed_tags},{e.hash_changed}"
            )
        self.audit_preview.setPlainText("\n".join(lines))
        self._audit_scope.setText(f"{len(self._audit.entries)} kayıt")

    def _append_audit_preview(self, line: str) -> None:
        self.audit_preview.appendPlainText(line)
        self._refresh_audit_preview()

    def _copy_audit(self) -> None:
        QApplication.clipboard().setText(self.audit_preview.toPlainText())
        self._set_status("Audit metni kopyalandı")

    def _open_config(self) -> None:
        reveal_in_folder(SETTINGS_FILE if SETTINGS_FILE.exists() else ROOT)

    def _setup_tray(self) -> None:
        icon_file = asset_path("icon.ico")
        if not icon_file.is_file():
            icon_file = asset_path("icon.png")
        if not icon_file.is_file():
            return

        self._tray = QSystemTrayIcon(QIcon(str(icon_file)), self)
        menu = QMenu()
        show_action = menu.addAction("Pencereyi göster")
        show_action.triggered.connect(self._show_from_tray)
        self._tray_stop_action = menu.addAction("İzlemeyi durdur")
        self._tray_stop_action.triggered.connect(self._stop_watch_from_tray)
        self._tray_stop_action.setEnabled(False)
        menu.addSeparator()
        menu.addAction("Çıkış", self._quit_app)
        self._tray.setContextMenu(menu)
        self._tray.activated.connect(self._on_tray_activated)
        self._tray.setToolTip("Metadata Temizleyici")
        self._tray.show()

    def _show_from_tray(self) -> None:
        self.showNormal()
        self.raise_()
        self.activateWindow()

    def _on_tray_activated(self, reason: QSystemTrayIcon.ActivationReason) -> None:
        if reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            self._show_from_tray()

    def _stop_watch_from_tray(self) -> None:
        self.watch_check.setChecked(False)

    def _quit_app(self) -> None:
        self._force_quit = True
        self.close()  # closeEvent watcher/worker'ı durdurup uygulamadan çıkar

    def _update_tray_state(self) -> None:
        if not self._tray:
            return
        if self._watcher.active:
            self._tray.setToolTip(f"İzleniyor: {self._watcher.directory}")
            if self._tray_stop_action:
                self._tray_stop_action.setEnabled(True)
        else:
            self._tray.setToolTip("Metadata Temizleyici")
            if self._tray_stop_action:
                self._tray_stop_action.setEnabled(False)

    def _prev_file(self) -> None:
        if not self._files:
            return
        self._preview_index = (self._preview_index - 1) % len(self._files)
        self._refresh_preview()

    def _next_file(self) -> None:
        if not self._files:
            return
        self._preview_index = (self._preview_index + 1) % len(self._files)
        self._refresh_preview()

    def _remove_current(self) -> None:
        if not self._files or self._worker is not None:
            return
        path = self._files[self._preview_index]
        self._queue_status.pop(str(path), None)
        del self._files[self._preview_index]
        if self._preview_index >= len(self._files) and self._files:
            self._preview_index = len(self._files) - 1
        if not self._files:
            self._preview_index = 0
        self._rebuild_queue_ui()
        self._rebuild_batch_table()
        self._refresh_preview()
        self._set_action_enabled(bool(self._files))
        self._queue_count_label.setText(f"{len(self._files)} dosya bekliyor")
        self._batch_total_label.setText(f"{len(self._files)} dosya")

    def _restore_current(self) -> None:
        if not self._files:
            return
        path = self._files[self._preview_index]
        try:
            restore_backup(path)
            self._refresh_preview()
            self._set_status(f"Geri yüklendi: {path.name}")
        except OSError as exc:
            QMessageBox.warning(self, "Geri yükleme", str(exc))

    def _reveal_current(self) -> None:
        if not self._files:
            return
        try:
            reveal_in_folder(self._files[self._preview_index])
        except OSError as exc:
            QMessageBox.warning(self, "Konum", str(exc))

    def _export_json(self) -> None:
        if not self._files:
            return
        path = self._files[self._preview_index]
        dest, _ = QFileDialog.getSaveFileName(
            self, "Metadata JSON kaydet", f"{path.stem}-metadata.json", "JSON (*.json)"
        )
        if not dest:
            return
        try:
            export_tags_json(path, Path(dest))
            self._set_status(f"JSON kaydedildi: {dest}")
        except OSError as exc:
            QMessageBox.warning(self, "Export hatası", str(exc))

    def _show_diff(self) -> None:
        if not self._last_result:
            QMessageBox.information(self, "Diff yok", "Henüz karşılaştırılacak bir işlem sonucu yok.")
            return
        DiffDialog(self._last_result, self).exec()

    def _export_audit(self) -> None:
        if not self._audit.entries:
            QMessageBox.information(self, "Rapor boş", "Dışa aktarılacak audit kaydı yok.")
            return
        path, _ = QFileDialog.getSaveFileName(self, "CSV rapor kaydet", "metadata-audit.csv", "CSV (*.csv)")
        if not path:
            return
        self._audit.export_csv(Path(path))
        self._set_status(f"Rapor kaydedildi: {path}")

    def _clear_queue(self) -> None:
        if self._worker is not None:
            return
        self._files.clear()
        self._preview_index = 0
        self._queue_status.clear()
        self._audit.clear()
        self._last_result = None
        self.metadata_table.clear_tags()
        self.preview_file.setText("—")
        self._diff_btn.setEnabled(False)
        self.progress.setValue(0)
        self._rebuild_queue_ui()
        self._rebuild_batch_table()
        self._refresh_audit_preview()
        self._set_action_enabled(False)
        self._queue_count_label.setText("0 dosya bekliyor")
        self._batch_total_label.setText("0 dosya")
        self._set_status("Kuyruk temizlendi")

    def _pick_watch_folder(self) -> None:
        folder = QFileDialog.getExistingDirectory(
            self,
            "İzleme klasörü",
            self._settings.watch_directory or self._settings.last_directory,
        )
        if not folder:
            return
        self._settings.watch_directory = folder
        self.watch_path.setText(folder)
        self._settings.save()
        if self.watch_check.isChecked():
            self._start_watcher(folder)

    def _on_watch_toggled(self, checked: bool) -> None:
        self._settings.watch_enabled = checked
        self._settings.save()
        self._watcher_status.setText("Klasör izleme aktif" if checked else "Klasör izleme kapalı")
        if checked:
            if not self._settings.watch_directory:
                self._pick_watch_folder()
                if not self._settings.watch_directory:
                    self.watch_check.setChecked(False)
                    return
            self._start_watcher(self._settings.watch_directory)
        else:
            self._watcher.stop()
            self._set_status("Klasör izleme durduruldu")
        self._update_tray_state()

    def _start_watcher(self, directory: str) -> None:
        mode, preset_id, custom_tags = self._current_strip_mode()

        def on_processed(path, payload) -> None:
            if isinstance(payload, StripResult):
                msg = f"{path.name} — otomatik temizlendi ({payload.tags_removed} tag)"
            else:
                msg = f"{path.name} — hata: {payload}"
            self.append_log.emit(msg)

        try:
            self._watcher.start(
                directory,
                backup=self._settings.backup_enabled,
                mode=mode,
                preset_id=preset_id,
                custom_tags=custom_tags,
                audit=self._audit,
                on_processed=on_processed,
            )
            self._set_status(f"Klasör izleniyor: {directory}")
            self._update_tray_state()
        except OSError as exc:
            QMessageBox.warning(self, "İzleme hatası", str(exc))
            self.watch_check.setChecked(False)

    def _update_engine_status(self) -> None:
        if exiftool_engine.is_available():
            ver = exiftool_engine.version() or "?"
            self._exiftool_pill.setText(f"Hazır v{ver}")
            self._exiftool_pill.setObjectName("PillSuccess")
            self._set_status(f"Hazır — exiftool v{ver}")
        else:
            self._exiftool_pill.setText("Yok")
            self._exiftool_pill.setObjectName("PillWarn")
            self._set_status("Hazır — exiftool yok (görsel: Pillow)")

    def _set_status(self, message: str) -> None:
        self.statusBar().showMessage(message)

    def closeEvent(self, event) -> None:
        if self._watcher.active and not self._force_quit and self._tray:
            self.hide()
            self._tray.showMessage(
                "Metadata Temizleyici",
                "Klasör izleme arka planda devam ediyor.",
                QSystemTrayIcon.MessageIcon.Information,
                3000,
            )
            event.ignore()
            return
        self._watcher.stop()
        if self._worker and self._worker.isRunning():
            # Yarıda öldürülürse dosya yazımı bozulabilir; sürmekte olan işlerin bitmesini bekle
            self._worker.cancel()
            self._worker.wait()
        if self._tray:
            self._tray.hide()
        super().closeEvent(event)
        # main.py setQuitOnLastWindowClosed(False) kullanır (tepside çalışmak için); çıkışı elle yap
        QApplication.quit()
