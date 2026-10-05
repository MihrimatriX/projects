from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QFrame,
    QMenu,
    QLabel,
    QListWidget,
    QListWidgetItem,
    QPushButton,
    QVBoxLayout,
)

from core.categorizer import cleanup_hint
from core.duplicates import DuplicateGroup
from core.formatters import human_size
from core.history import ScanSnapshot
from core.models import LargeFile, ScanNode, is_same_or_under
from ui.theme import PADDING_PANEL, SIDEBAR_WIDTH
from ui.widgets.legend_bar import LegendBar
from ui.widgets.timeline_bar import TimelineBar


class SidebarPanel(QFrame):
    reveal_requested = Signal(str)
    delete_requested = Signal(str)
    item_selected = Signal(object)
    duplicates_requested = Signal()
    snapshot_selected = Signal(int)

    def __init__(self) -> None:
        super().__init__()
        self.setObjectName("Sidebar")
        self.setFixedWidth(SIDEBAR_WIDTH)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        header = QFrame()
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(PADDING_PANEL, PADDING_PANEL, PADDING_PANEL, PADDING_PANEL)
        self.size_label = QLabel("—")
        self.size_label.setObjectName("SizeDisplay")
        self.path_label = QLabel("")
        self.path_label.setObjectName("PathDisplay")
        self.path_label.setWordWrap(True)
        self.compare_label = QLabel("")
        self.compare_label.setObjectName("MutedLabel")
        self.compare_label.hide()
        header_layout.addWidget(self.size_label)
        header_layout.addWidget(self.path_label)
        header_layout.addWidget(self.compare_label)
        layout.addWidget(header)

        self.cleanup_card = QFrame()
        self.cleanup_card.setObjectName("CleanupCard")
        card_layout = QVBoxLayout(self.cleanup_card)
        card_layout.setContentsMargins(12, 12, 12, 12)
        card_title = QLabel("TEMİZLİK ÖNERİSİ")
        card_title.setObjectName("SectionTitle")
        self.cleanup_text = QLabel("Tarama sonrası öneriler burada görünür.")
        self.cleanup_text.setWordWrap(True)
        self.cleanup_text.setTextFormat(Qt.TextFormat.RichText)
        self.cleanup_text.setStyleSheet("font-size: 12px; line-height: 1.5;")
        self.cleanup_btn = QPushButton("Temizle…")
        self.cleanup_btn.setObjectName("GhostButton")
        self.cleanup_btn.setToolTip("En büyük öneriyi onay sorarak geri dönüşüm kutusuna taşır")
        self.cleanup_btn.clicked.connect(self._on_cleanup)
        card_layout.addWidget(card_title)
        card_layout.addWidget(self.cleanup_text)
        card_layout.addWidget(self.cleanup_btn)
        cleanup_wrap = QVBoxLayout()
        cleanup_wrap.setContentsMargins(PADDING_PANEL, PADDING_PANEL, PADDING_PANEL, 0)
        cleanup_wrap.addWidget(self.cleanup_card)
        layout.addLayout(cleanup_wrap)

        self.large_list = QListWidget()
        self.large_list.setObjectName("FileList")
        self.large_list.setAccessibleName("Büyük dosyalar")
        self.large_list.setToolTip("Çift tık / Enter: Explorer'da göster · Delete: çöpe taşı · sağ tık: menü")
        # Tek tık yalnızca seçer; Explorer'ı çift tık / Enter açar (itemActivated).
        self.large_list.itemActivated.connect(self._large_clicked)
        self.large_list.setContextMenuPolicy(Qt.ContextMenuPolicy.CustomContextMenu)
        self.large_list.customContextMenuRequested.connect(self._large_menu)
        self.large_list.installEventFilter(self)
        layout.addWidget(self.large_list, stretch=1)

        self.legend = LegendBar()
        layout.addWidget(self.legend)

        self.timeline = TimelineBar()
        self.timeline.snapshot_selected.connect(self.snapshot_selected.emit)
        layout.addWidget(self.timeline)

        self._selected: ScanNode | None = None
        self._cleanup_paths: list[str] = []
        self._duplicates: list[DuplicateGroup] = []

    def set_duplicates(self, groups: list[DuplicateGroup]) -> None:
        self._duplicates = groups

    def set_compare_delta(self, text: str) -> None:
        if text:
            self.compare_label.setText(text)
            self.compare_label.show()
        else:
            self.compare_label.hide()

    def set_snapshots(self, snapshots: list[ScanSnapshot], *, current_size: int | None = None) -> None:
        self.timeline.set_snapshots(snapshots, current_size=current_size)

    def set_context(
        self,
        node: ScanNode | None,
        *,
        root_size: int,
        large_files: list[LargeFile] | None = None,
    ) -> None:
        self._selected = node
        self.large_list.clear()
        self._cleanup_paths.clear()

        if not node:
            self.size_label.setText("—")
            self.path_label.setText("Bir segment seçin veya tarama başlatın")
            self.cleanup_card.hide()
            return

        self.size_label.setText(human_size(node.size))
        self.path_label.setText(node.path)
        self._fill_cleanup(node)
        self._fill_large_files(large_files or [], node)

    def _fill_cleanup(self, node: ScanNode) -> None:
        hints: list[tuple[str, str, int]] = []
        for child in node.sorted_children()[:30]:
            hint = cleanup_hint(child.path)
            if hint:
                hints.append((child.name, hint, child.size))

        if not hints:
            self.cleanup_card.hide()
            return

        self.cleanup_card.show()
        total_gain = sum(size for _, _, size in hints[:3])
        names = ", ".join(name for name, _, _ in hints[:3])
        self.cleanup_text.setText(
            f'<span style="color:#3fb950;font-weight:600;">~{human_size(total_gain)}</span> '
            f"kazanç — {names}."
        )
        self._cleanup_paths = [child.path for child in node.sorted_children()[:30] if cleanup_hint(child.path)][:3]
        self.cleanup_btn.setText(f"Temizle: {hints[0][0]}…")

    def _fill_large_files(self, large_files: list[LargeFile], node: ScanNode) -> None:
        # Yalnızca odaktaki klasörün altındakiler (önceden alt klasörde de tüm kökün listesi görünüyordu).
        shown = [lf for lf in large_files if is_same_or_under(lf.path, node.path)][:20]
        if not shown:
            for child in node.sorted_children()[:15]:
                if child.size >= 100 * 1024 * 1024:
                    item = QListWidgetItem(f"{child.name}  ·  {human_size(child.size)}")
                    item.setData(Qt.ItemDataRole.UserRole, child.path)
                    item.setToolTip(child.path)
                    if child.size >= 1024**3:
                        item.setForeground(Qt.GlobalColor.red)
                    self.large_list.addItem(item)
            if self.large_list.count() == 0:
                empty = QListWidgetItem("Bu konumda büyük dosya yok")
                empty.setFlags(Qt.ItemFlag.NoItemFlags)
                empty.setForeground(Qt.GlobalColor.gray)
                self.large_list.addItem(empty)
            return

        for lf in shown:
            item = QListWidgetItem(f"{lf.name}  ·  {human_size(lf.size)}")
            item.setData(Qt.ItemDataRole.UserRole, lf.path)
            item.setToolTip(lf.path)  # aynı adlı dosyalar ayırt edilebilsin
            if lf.size >= 1024**3:
                item.setForeground(Qt.GlobalColor.red)
            self.large_list.addItem(item)

    def _on_cleanup(self) -> None:
        if self._cleanup_paths and self._selected:
            self.delete_requested.emit(self._cleanup_paths[0])

    def _large_menu(self, pos) -> None:
        item = self.large_list.itemAt(pos)
        path = item.data(Qt.ItemDataRole.UserRole) if item else None
        if not path:
            return
        menu = QMenu(self)
        menu.addAction("Explorer'da göster", lambda: self.reveal_requested.emit(path))
        menu.addAction("Çöpe taşı", lambda: self.delete_requested.emit(path))
        menu.exec(self.large_list.viewport().mapToGlobal(pos))

    def eventFilter(self, obj, event) -> bool:  # noqa: N802
        from PySide6.QtCore import QEvent

        if obj is self.large_list and event.type() == QEvent.Type.KeyPress and event.key() == Qt.Key.Key_Delete:
            item = self.large_list.currentItem()
            path = item.data(Qt.ItemDataRole.UserRole) if item else None
            if path:
                self.delete_requested.emit(path)
                return True
        return super().eventFilter(obj, event)

    def _large_clicked(self, item: QListWidgetItem) -> None:
        path = item.data(Qt.ItemDataRole.UserRole)
        if path:
            self.reveal_requested.emit(path)
