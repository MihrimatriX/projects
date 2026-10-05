from pathlib import Path

from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QFileDialog,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QSpinBox,
)

from core.settings import AppSettings


class SettingsDialog(QDialog):
    def __init__(self, settings: AppSettings, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Ayarlar")
        self.setMinimumWidth(420)
        self.result_settings = AppSettings(**settings.__dict__)

        form = QFormLayout(self)
        self.scheduled = QCheckBox("Zamanlanmış tarama")
        self.scheduled.setChecked(settings.scheduled_scan_enabled)
        self.days = QSpinBox()
        self.days.setRange(1, 30)
        self.days.setValue(settings.scheduled_scan_days)
        self.days.setAccessibleName("Zamanlanmış tarama aralığı (gün)")
        self.scan_root = QLineEdit(settings.scheduled_scan_root)
        self.scan_root.setAccessibleName("Zamanlanmış tarama klasörü")
        self.browse_btn = QPushButton("Gözat…")
        self.browse_btn.clicked.connect(self._browse)
        root_row = QHBoxLayout()
        root_row.addWidget(self.scan_root, 1)
        root_row.addWidget(self.browse_btn)
        self.error_label = QLabel("")
        self.error_label.setStyleSheet("color: #f85149;")
        self.error_label.hide()
        self.min_dup = QSpinBox()
        self.min_dup.setRange(1, 500)
        self.min_dup.setValue(settings.min_duplicate_size_mb)
        self.min_dup.setSuffix(" MB")
        self.min_dup.setAccessibleName("Tekrar adayı en küçük dosya boyutu")

        form.addRow(self.scheduled)
        form.addRow("Aralık (gün):", self.days)
        form.addRow("Tarama klasörü:", root_row)
        form.addRow("Tekrar adayı alt sınırı:", self.min_dup)
        form.addRow(self.error_label)

        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(self._save)
        buttons.rejected.connect(self.reject)
        form.addRow(buttons)

    def _browse(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Zamanlanmış tarama klasörü", self.scan_root.text())
        if folder:
            self.scan_root.setText(folder)

    def _save(self) -> None:
        root = self.scan_root.text().strip()
        if self.scheduled.isChecked() and not Path(root).is_dir():
            self.error_label.setText("Zamanlanmış tarama için var olan bir klasör seçin.")
            self.error_label.show()
            self.scan_root.setFocus()
            return
        s = self.result_settings
        s.scheduled_scan_enabled = self.scheduled.isChecked()
        s.scheduled_scan_days = self.days.value()
        s.scheduled_scan_root = self.scan_root.text().strip()
        s.min_duplicate_size_mb = self.min_dup.value()
        self.accept()
