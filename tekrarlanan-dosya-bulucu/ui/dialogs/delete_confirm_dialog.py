from __future__ import annotations

from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QDialogButtonBox,
    QLabel,
    QListWidget,
    QVBoxLayout,
)

from ui.theme import DANGER, TEXT_MUTED
from utils.formatters import human_size


class DeleteConfirmDialog(QDialog):
    def __init__(self, paths: list[str], total_bytes: int, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Güvenli silme onayı")
        self.resize(480, 380)

        layout = QVBoxLayout(self)
        layout.addWidget(QLabel(f"<h3>Güvenli silme onayı</h3>"))
        self._summary_head = (
            f"<span style='color:{DANGER}; font-weight:600'>{len(paths)} dosya</span> "
            f"({human_size(total_bytes)})"
        )
        self.summary = QLabel(f"{self._summary_head} çöp kutusuna taşınacak.")
        layout.addWidget(self.summary)
        layout.addWidget(QLabel("Asıl dosyalar korunur; yalnızca seçili kopyalar silinir."))

        note = QLabel("Dosyalar Geri Dönüşüm Kutusu'na taşınır — kalıcı silme değil; gerekirse oradan geri yükleyebilirsiniz.")
        note.setStyleSheet(f"color: {TEXT_MUTED}; padding: 10px;")
        note.setWordWrap(True)
        layout.addWidget(note)

        self.list = QListWidget()
        for path in paths[:40]:
            self.list.addItem(path)
        if len(paths) > 40:
            self.list.addItem(f"… ve {len(paths) - 40} dosya daha")
        layout.addWidget(self.list)

        self.permanent_cb = QCheckBox("Kalıcı sil (önerilmez — geri alınamaz)")
        self.permanent_cb.setStyleSheet(f"color: {DANGER};")
        layout.addWidget(self.permanent_cb)

        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Cancel | QDialogButtonBox.StandardButton.Ok
        )
        buttons.button(QDialogButtonBox.StandardButton.Cancel).setText("İptal (Esc)")
        self.ok_btn = buttons.button(QDialogButtonBox.StandardButton.Ok)
        self.ok_btn.setText("Çöp kutusuna taşı")
        # Kalıcı sil seçilince düğme/metin hâlâ "çöp kutusu" demesin
        self.permanent_cb.toggled.connect(self._on_permanent_toggled)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def _on_permanent_toggled(self, permanent: bool) -> None:
        self.ok_btn.setText("Kalıcı olarak sil" if permanent else "Çöp kutusuna taşı")
        self.summary.setText(
            f"{self._summary_head} {'kalıcı olarak silinecek' if permanent else 'çöp kutusuna taşınacak'}."
        )

    @property
    def permanent_delete(self) -> bool:
        return self.permanent_cb.isChecked()
