from __future__ import annotations

import os

from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QDialog,
    QDialogButtonBox,
    QFormLayout,
    QLabel,
    QLineEdit,
    QSpinBox,
    QVBoxLayout,
)

from utils.image_similarity import image_libs_available
from utils.models import KeepStrategy
from utils.settings import AppSettings


class SettingsDialog(QDialog):
    def __init__(self, settings: AppSettings, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Ayarlar")
        self.resize(480, 380)
        self._settings = settings

        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.min_size = QSpinBox()
        self.min_size.setRange(0, 1024 * 1024)
        self.min_size.setSuffix(" KB")
        self.min_size.setValue(settings.min_size_kb)
        form.addRow("Minimum dosya boyutu", self.min_size)

        self.extensions = QLineEdit(settings.exclude_extensions)
        form.addRow("Hariç uzantılar", self.extensions)

        self.skip_hidden = QCheckBox("Gizli dosyaları atla")
        self.skip_hidden.setChecked(settings.skip_hidden)
        form.addRow(self.skip_hidden)

        self.skip_system = QCheckBox("Sistem klasörlerini atla")
        self.skip_system.setChecked(settings.skip_system_dirs)
        form.addRow(self.skip_system)

        self.follow_symlinks = QCheckBox("Sembolik bağlantıları izle")
        self.follow_symlinks.setChecked(settings.follow_symlinks)
        form.addRow(self.follow_symlinks)

        self.use_cache = QCheckBox("Tarama önbelleği")
        self.use_cache.setChecked(settings.use_scan_cache)
        form.addRow(self.use_cache)

        self.hash_workers = QSpinBox()
        self.hash_workers.setRange(1, max(1, os.cpu_count() or 4))
        self.hash_workers.setValue(min(settings.hash_workers, self.hash_workers.maximum()))
        form.addRow("Paralel hash iş parçacığı", self.hash_workers)

        self.page_size = QSpinBox()
        self.page_size.setRange(20, 2000)
        self.page_size.setValue(settings.results_page_size)
        form.addRow("Sayfa başına grup", self.page_size)

        self.compact_threshold = QSpinBox()
        self.compact_threshold.setRange(50, 50000)
        self.compact_threshold.setValue(settings.compact_list_threshold)
        form.addRow("Kompakt liste eşiği (grup)", self.compact_threshold)

        self.strategy = QComboBox()
        self.strategy.addItem("En eski tut", KeepStrategy.OLDEST.value)
        self.strategy.addItem("En yeni tut", KeepStrategy.NEWEST.value)
        self.strategy.addItem("En kısa yol tut", KeepStrategy.SHORTEST_PATH.value)
        idx = self.strategy.findData(settings.keep_strategy)
        if idx >= 0:
            self.strategy.setCurrentIndex(idx)
        form.addRow("Silme önerisi", self.strategy)

        self.protected = QLineEdit(settings.protected_folders)
        self.protected.setPlaceholderText(r"Ör. D:\Arsiv;C:\Fotograflar")
        self.protected.setToolTip(
            "Bu klasörlerdeki (';' ile ayırın) kopyalar her zaman tutulur, silinmeye işaretlenmez."
        )
        form.addRow("Korunan klasörler", self.protected)

        self.scheduled = QCheckBox("Zamanlanmış tarama")
        self.scheduled.setChecked(settings.scheduled_scan_enabled)
        form.addRow(self.scheduled)

        self.scan_days = QSpinBox()
        self.scan_days.setRange(1, 90)
        self.scan_days.setValue(settings.scheduled_scan_days)
        form.addRow("Tarama aralığı (gün)", self.scan_days)

        self.minimize_tray = QCheckBox("Kapatınca tepsiye küçült")
        self.minimize_tray.setChecked(settings.minimize_to_tray)
        form.addRow(self.minimize_tray)

        if not image_libs_available():
            form.addRow(
                QLabel(
                    "Görsel benzerlik: pip install -r requirements-optional.txt"
                )
            )

        layout.addLayout(form)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def apply_to(self, settings: AppSettings) -> None:
        settings.min_size_kb = self.min_size.value()
        settings.exclude_extensions = self.extensions.text().strip()
        settings.skip_hidden = self.skip_hidden.isChecked()
        settings.skip_system_dirs = self.skip_system.isChecked()
        settings.use_scan_cache = self.use_cache.isChecked()
        settings.hash_workers = self.hash_workers.value()
        settings.results_page_size = self.page_size.value()
        settings.keep_strategy = self.strategy.currentData()
        settings.protected_folders = self.protected.text().strip()
        settings.scheduled_scan_enabled = self.scheduled.isChecked()
        settings.scheduled_scan_days = self.scan_days.value()
        settings.minimize_to_tray = self.minimize_tray.isChecked()
        settings.follow_symlinks = self.follow_symlinks.isChecked()
        settings.compact_list_threshold = self.compact_threshold.value()
