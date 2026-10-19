from __future__ import annotations

from PySide6.QtWidgets import QDialog, QLabel, QListWidget, QPushButton, QVBoxLayout

from utils.scan_history import load_history


class ScanHistoryDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setWindowTitle("Tarama geçmişi")
        self.resize(520, 360)
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Son taramalar (yerel kayıt):"))
        self.list = QListWidget()
        for entry in load_history():
            roots = ", ".join(entry.get("roots", [])[:2])
            if len(entry.get("roots", [])) > 2:
                roots += " …"
            line = (
                f"{entry.get('at', '')[:16]} · {entry.get('scan_type', '?')} · "
                f"{entry.get('group_count', 0)} grup · {entry.get('wasted_human', '?')} · {roots}"
            )
            if entry.get("from_cache"):
                line += " (önbellek)"
            self.list.addItem(line)
        if self.list.count() == 0:
            self.list.addItem("Henüz kayıt yok.")
        layout.addWidget(self.list)
        btn = QPushButton("Kapat")
        btn.clicked.connect(self.accept)
        layout.addWidget(btn)
