from __future__ import annotations

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QDialog, QHBoxLayout, QLabel, QListWidget, QListWidgetItem, QPushButton, QVBoxLayout

from core.duplicates import DuplicateGroup
from core.export import reveal_in_explorer
from core.formatters import human_size
from core.tekrarlanan_bridge import open_in_tekrarlanan_bulucu


class DuplicatesDialog(QDialog):
    def __init__(self, groups: list[DuplicateGroup], parent=None) -> None:
        super().__init__(parent)
        self._groups = groups
        self.setWindowTitle("Tekrar adayları")
        self.resize(560, 480)
        layout = QVBoxLayout(self)
        layout.addWidget(
            QLabel(
                "Aynı boyuta sahip dosya grupları. İçerikleri karşılaştırılmadı — kesin kopya değildir.\n"
                "İçerik (SHA-256) doğrulaması için Tekrarlanan Dosya Bulucu'da açın."
            )
        )
        self.list = QListWidget()
        self.list.setAccessibleName("Tekrar adayı dosyalar")
        for group in groups:
            header = QListWidgetItem(
                f"⚠ {human_size(group.size)} × {group.count} dosya"
            )
            header.setFlags(Qt.ItemFlag.NoItemFlags)
            self.list.addItem(header)
            for path in group.paths[:8]:
                item = QListWidgetItem(f"  {path}")
                item.setData(Qt.ItemDataRole.UserRole, path)
                self.list.addItem(item)
            if group.count > 8:
                more = QListWidgetItem(f"  … ve {group.count - 8} dosya daha")
                more.setFlags(Qt.ItemFlag.NoItemFlags)
                self.list.addItem(more)
        self.list.itemActivated.connect(self._open)  # çift tık + Enter
        layout.addWidget(self.list)

        row = QHBoxLayout()
        open_btn = QPushButton("Seçileni göster")
        self.open_btn = open_btn
        open_btn.clicked.connect(self._open_selected)
        deep_btn = QPushButton("Tekrarlanan Dosya Bulucu'da aç")
        self.deep_btn = deep_btn
        deep_btn.clicked.connect(self._open_deep_scan)
        close_btn = QPushButton("Kapat")
        close_btn.clicked.connect(self.accept)
        for btn in (open_btn, deep_btn, close_btn):
            # Listede Enter yalnızca öğeyi açsın; varsayılan düğmeyi de tetikleyip iki kez açmasın.
            btn.setAutoDefault(False)
        row.addWidget(open_btn)
        row.addWidget(deep_btn)
        row.addStretch()
        row.addWidget(close_btn)
        layout.addLayout(row)

    def _open(self, item: QListWidgetItem) -> None:
        path = item.data(Qt.ItemDataRole.UserRole)
        if path:
            reveal_in_explorer(path)

    def _open_selected(self) -> None:
        item = self.list.currentItem()
        if item:
            self._open(item)

    def _open_deep_scan(self) -> None:
        from PySide6.QtWidgets import QMessageBox

        ok, message = open_in_tekrarlanan_bulucu(self._groups)
        if not ok:
            QMessageBox.warning(self, "Tekrarlanan Dosya Bulucu", message)
        else:
            # IPC ile aktarıldıysa sessiz kapan; soğuk başlatmada bilgi ver
            if "aktarıldı" in message.lower():
                self.accept()
            else:
                QMessageBox.information(self, "Tekrarlanan Dosya Bulucu", message)
                self.accept()
