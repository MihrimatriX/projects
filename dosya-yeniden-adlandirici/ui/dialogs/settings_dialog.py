from __future__ import annotations

from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QComboBox,
    QFormLayout,
    QSpinBox,
    QVBoxLayout,
)

from core.exif_meta import pillow_available
from core.settings import SettingsStore
from ui.theme import TEXT_MUTED


class SettingsDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Ayarlar")
        self.setMinimumWidth(420)
        store = SettingsStore.instance()
        s = store.settings

        layout = QVBoxLayout(self)
        form = QFormLayout()

        self.theme_combo = QComboBox()
        self.theme_combo.addItems(["Koyu", "Açık"])
        self.theme_combo.setCurrentIndex(0 if s.theme != "light" else 1)
        form.addRow("Tema", self.theme_combo)

        self.recursive_cb = QCheckBox("Klasör açılışında alt klasörleri tara")
        self.recursive_cb.setChecked(s.recursive)
        form.addRow(self.recursive_cb)

        self.hidden_cb = QCheckBox("Gizli dosyaları dahil et")
        self.hidden_cb.setChecked(s.include_hidden)
        form.addRow(self.hidden_cb)

        self.filter_cb = QCheckBox("Önizlemede yalnızca değişenleri göster")
        self.filter_cb.setChecked(s.filter_changed_only)
        form.addRow(self.filter_cb)

        self.exif_mtime_cb = QCheckBox("EXIF yoksa değiştirme tarihini kullan (varsayılan)")
        self.exif_mtime_cb.setChecked(s.exif_mtime_fallback_default)
        form.addRow(self.exif_mtime_cb)

        self.undo_spin = QSpinBox()
        self.undo_spin.setRange(1, 100)
        self.undo_spin.setValue(s.undo_stack_max)
        form.addRow("Geri al yığını (adım)", self.undo_spin)

        self.async_spin = QSpinBox()
        self.async_spin.setRange(20, 5000)
        self.async_spin.setValue(s.preview_async_threshold)
        form.addRow("Arka plan önizleme (dosya ≥)", self.async_spin)

        layout.addLayout(form)

        exif_status = "kurulu ✓" if pillow_available() else "yok — değiştirme tarihi kullanılabilir"
        from PySide6.QtWidgets import QLabel

        layout.addWidget(QLabel(f"<b>Pillow (EXIF):</b> {exif_status}"))
        layout.addWidget(
            QLabel(
                f"<p style='color:{TEXT_MUTED};font-size:12px'>"
                "Tüm kısayollar: Yardım → Kullanım (F1)"
                "</p>"
            )
        )

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def apply(self) -> None:
        store = SettingsStore.instance()
        store.settings.theme = "light" if self.theme_combo.currentIndex() == 1 else "dark"
        store.settings.recursive = self.recursive_cb.isChecked()
        store.settings.include_hidden = self.hidden_cb.isChecked()
        store.settings.filter_changed_only = self.filter_cb.isChecked()
        store.settings.exif_mtime_fallback_default = self.exif_mtime_cb.isChecked()
        store.settings.undo_stack_max = self.undo_spin.value()
        store.settings.preview_async_threshold = self.async_spin.value()
        store.save()
