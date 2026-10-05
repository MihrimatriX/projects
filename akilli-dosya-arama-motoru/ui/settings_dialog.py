from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import Qt
from PySide6.QtWidgets import (
    QCheckBox,
    QDialog,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QSpinBox,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

from ui import theme as T
from ui.icons import folder_icon
from ui.window_chrome import WinTitleBar
from utils.actions import IndexBuildWorker
from utils.everything_bridge import everything_status
from utils.index_backend import active_backend_name, backend_status, export_index, get_index_stats, import_index
from utils.search_history import clear_history, history_stats
from utils.settings import (
    background_scan_enabled,
    content_search_enabled,
    everything_bridge_enabled,
    everything_filter_to_roots,
    fuzzy_search_enabled,
    load_settings,
    save_settings,
    scheduled_reindex_enabled,
    scheduled_reindex_hour,
    snippets_enabled,
    tantivy_primary_enabled,
    watcher_enabled,
)


def _row_frame(edge: str = "bottom") -> QFrame:
    """Ayraç çizgili satır; seçici sayesinde çizgi alt etiketlere/düğmelere sızmaz."""
    row = QFrame()
    row.setObjectName("SettingsRow")
    row.setStyleSheet(
        f"QFrame#SettingsRow {{ border: none; border-{edge}: 1px solid {T.BORDER}; background: transparent; }}"
    )
    return row


class _FolderRow(QFrame):
    def __init__(self, path: str, full_path: str, on_remove, parent=None) -> None:
        super().__init__(parent)
        self._path = path
        self.setToolTip(full_path)
        self.setObjectName("FolderRow")
        self.setStyleSheet(
            f"QFrame#FolderRow {{ background: transparent; border-bottom: 1px solid {T.BORDER}; }}"
            f"QFrame#FolderRow:hover {{ background: {T.BG_HOVER}; }}"
        )
        lay = QHBoxLayout(self)
        lay.setContentsMargins(16, 12, 16, 12)
        lay.setSpacing(10)

        icon = QLabel()
        icon.setPixmap(folder_icon(16))
        icon.setFixedSize(32, 32)
        icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon.setStyleSheet(
            f"background: {T.ACCENT_DIM}; border: 1px solid rgba(69, 184, 106, 0.25); "
            f"border-radius: {T.RADIUS_MD}px;"
        )

        path_lbl = QLabel(path)
        path_lbl.setStyleSheet(
            f"color: {T.TEXT_SECONDARY}; font-size: 14px; font-weight: 500; background: transparent;"
        )
        # Klasör yoksa (silinmiş/çıkarılmış sürücü) arama sessizce atlamasın diye görünür uyarı.
        if not Path(full_path).expanduser().is_dir():
            path_lbl.setText(f"{path}  (bulunamadı)")
            path_lbl.setStyleSheet(path_lbl.styleSheet() + f"color: {T.WARNING};")

        remove = QPushButton("Kaldır")
        remove.setObjectName("RemoveFolder")
        remove.setAccessibleName(f"Kaldır: {path}")
        remove.setCursor(Qt.CursorShape.PointingHandCursor)
        remove.clicked.connect(lambda: on_remove(path))

        lay.addWidget(icon)
        lay.addWidget(path_lbl, stretch=1)
        lay.addWidget(remove)


class SettingsDialog(QDialog):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("SettingsDialog")
        self.setWindowFlags(
            Qt.WindowType.Dialog
            | Qt.WindowType.FramelessWindowHint
            | Qt.WindowType.WindowSystemMenuHint
        )
        self.setModal(True)
        self.setMinimumWidth(T.SETTINGS_WIDTH)
        self.setStyleSheet(
            T.GLOBAL_STYLESHEET + T.SETTINGS_DIALOG_STYLESHEET + T.SETTINGS_STYLESHEET
        )

        self._folders: list[str] = []
        self._folder_rows_host: QWidget | None = None
        self._folder_rows_layout: QVBoxLayout | None = None
        self._index_worker: IndexBuildWorker | None = None

        data = load_settings()

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        outer.addWidget(
            WinTitleBar(
                "İndeks Ayarları — Akıllı Dosya Arama",
                self,
                on_close=self.reject,
            )
        )

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        body = QWidget()
        body_lay = QVBoxLayout(body)
        body_lay.setContentsMargins(24, 32, 24, 24)
        body_lay.setSpacing(16)

        back_hint = QLabel("← Arama paletine dön (Esc / İptal)")
        back_hint.setStyleSheet(f"color: {T.ACCENT}; font-size: 13px; background: transparent;")
        body_lay.addWidget(back_hint)

        title = QLabel("İndeks Ayarları")
        title.setStyleSheet(
            f"color: {T.TEXT_PRIMARY}; font-size: 22px; font-weight: 600; background: transparent;"
        )
        subtitle = QLabel(
            "Taranacak dizinleri, hariç tutma kurallarını ve arama davranışını yönetin."
        )
        subtitle.setWordWrap(True)
        subtitle.setStyleSheet(
            f"color: {T.TEXT_MUTED}; font-size: 14px; background: transparent;"
        )
        body_lay.addWidget(title)
        body_lay.addWidget(subtitle)

        body_lay.addWidget(self._section_dirs(data))
        body_lay.addWidget(self._section_exclude(data))
        body_lay.addWidget(self._section_toggles(data))
        body_lay.addWidget(self._section_faz3(data))
        body_lay.addWidget(self._section_hotkeys())
        body_lay.addWidget(self._section_reindex())

        scroll.setWidget(body)
        outer.addWidget(scroll, stretch=1)

        save_bar = QFrame()
        save_bar.setStyleSheet(
            f"QFrame {{ background: {T.BG_PANEL}; border-top: 1px solid {T.BORDER}; }}"
        )
        bar_lay = QHBoxLayout(save_bar)
        bar_lay.setContentsMargins(24, 12, 24, 12)
        bar_lay.addStretch()
        cancel = QPushButton("İptal")
        cancel.setObjectName("Secondary")
        cancel.clicked.connect(self.reject)
        save = QPushButton("Kaydet")
        save.setObjectName("Primary")
        save.clicked.connect(self._save)
        bar_lay.addWidget(cancel)
        bar_lay.addWidget(save)
        outer.addWidget(save_bar)

        self._folders = list(data.get("search_roots", []))
        self._render_folders()

    def _section_dirs(self, data: dict) -> QFrame:
        sec = QFrame()
        sec.setObjectName("Section")
        lay = QVBoxLayout(sec)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)

        heading = QLabel("TARANAN DİZİNLER")
        heading.setObjectName("SectionTitle")
        lay.addWidget(heading)

        self._folder_rows_host = QWidget()
        self._folder_rows_layout = QVBoxLayout(self._folder_rows_host)
        self._folder_rows_layout.setContentsMargins(0, 0, 0, 0)
        self._folder_rows_layout.setSpacing(0)
        lay.addWidget(self._folder_rows_host)

        add_row = _row_frame("top")
        add_lay = QHBoxLayout(add_row)
        add_lay.setContentsMargins(16, 12, 16, 12)
        add_btn = QPushButton("+ Dizin ekle")
        add_btn.setObjectName("AddFolder")
        add_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        add_btn.clicked.connect(self._add_folder)
        add_lay.addWidget(add_btn)
        add_lay.addStretch()
        lay.addWidget(add_row)
        return sec

    def _section_exclude(self, data: dict) -> QFrame:
        sec = QFrame()
        sec.setObjectName("Section")
        lay = QVBoxLayout(sec)
        lay.setContentsMargins(0, 0, 0, 0)

        heading = QLabel("HARİÇ TUTMA")
        heading.setObjectName("SectionTitle")
        lay.addWidget(heading)

        field = QWidget()
        field_lay = QVBoxLayout(field)
        field_lay.setContentsMargins(16, 14, 16, 14)
        lbl = QLabel("Glob desenleri (satır başına bir)")
        lbl.setStyleSheet(f"color: {T.TEXT_SECONDARY}; font-size: 13px; background: transparent;")
        self._exclude_edit = QTextEdit()
        self._exclude_edit.setObjectName("ExcludePatterns")
        self._exclude_edit.setPlainText("\n".join(data.get("exclude_patterns", [])))
        self._exclude_edit.setFixedHeight(88)
        hint = QLabel("Bu desenlere uyan dosyalar indekse alınmaz.")
        hint.setStyleSheet(f"color: {T.TEXT_MUTED}; font-size: 11px; background: transparent;")
        field_lay.addWidget(lbl)
        field_lay.addWidget(self._exclude_edit)
        field_lay.addWidget(hint)
        lay.addWidget(field)
        return sec

    def _section_toggles(self, data: dict) -> QFrame:
        sec = QFrame()
        sec.setObjectName("Section")
        lay = QVBoxLayout(sec)
        lay.setContentsMargins(0, 0, 0, 0)

        heading = QLabel("ARAMA")
        heading.setObjectName("SectionTitle")
        lay.addWidget(heading)

        self._snippets_cb = QCheckBox()
        self._snippets_cb.setChecked(snippets_enabled())
        lay.addWidget(self._toggle_row("İçerik snippet'leri", "Arama sonuçlarında metin önizlemesi göster", self._snippets_cb))

        self._content_cb = QCheckBox()
        self._content_cb.setChecked(content_search_enabled())
        lay.addWidget(self._toggle_row("Dosya içinde ara", "Metin ve kod dosyalarında tam metin arama (FTS5)", self._content_cb))

        self._bg_cb = QCheckBox()
        self._bg_cb.setChecked(background_scan_enabled())
        lay.addWidget(self._toggle_row("Arka planda tara", "Sistem kaynaklarını düşük öncelikle kullan", self._bg_cb))

        self._watcher_cb = QCheckBox()
        self._watcher_cb.setChecked(watcher_enabled())
        lay.addWidget(self._toggle_row(
            "Canlı indeks (FS watcher)",
            "Dosya değişikliklerini otomatik FTS5 indeksine yansıt",
            self._watcher_cb,
        ))

        self._fuzzy_cb = QCheckBox()
        self._fuzzy_cb.setChecked(fuzzy_search_enabled())
        lay.addWidget(self._toggle_row(
            "Bulanık arama",
            "Yazım hatalarında rapidfuzz ile dosya adı eşleştir",
            self._fuzzy_cb,
        ))

        self._tantivy_cb = QCheckBox()
        self._tantivy_cb.setChecked(tantivy_primary_enabled())
        self._tantivy_cb.setEnabled(backend_status().get("tantivy", False))
        lay.addWidget(self._toggle_row(
            "Tantivy birincil indeks",
            "Arama Tantivy + canlı güncelleme FTS5 (Windows uyumlu); tam indeks için yeniden indeksle",
            self._tantivy_cb,
        ))
        return sec

    def _section_faz3(self, data: dict) -> QFrame:
        sec = QFrame()
        sec.setObjectName("Section")
        lay = QVBoxLayout(sec)
        lay.setContentsMargins(0, 0, 0, 0)

        heading = QLabel("GELİŞMİŞ (FAZ 3)")
        heading.setObjectName("SectionTitle")
        lay.addWidget(heading)

        self._everything_cb = QCheckBox()
        self._everything_cb.setChecked(everything_bridge_enabled())
        lay.addWidget(self._toggle_row(
            "Everything köprüsü",
            "Windows Everything indeksinden anlık dosya adı araması (Everything çalışıyor olmalı)",
            self._everything_cb,
        ))

        self._everything_filter_cb = QCheckBox()
        self._everything_filter_cb.setChecked(everything_filter_to_roots())
        lay.addWidget(self._toggle_row(
            "Everything sonuçlarını köklere filtrele",
            "Yalnızca taranan dizinler altındaki dosyaları göster",
            self._everything_filter_cb,
        ))

        ev_status = everything_status()
        ev_color = T.ACCENT if ev_status.get("available") else T.TEXT_MUTED
        self._everything_status = QLabel(ev_status.get("message", ""))
        self._everything_status.setStyleSheet(
            f"color: {ev_color}; font-size: 12px; padding: 0 16px 12px; background: transparent;"
        )
        lay.addWidget(self._everything_status)

        self._scheduled_cb = QCheckBox()
        self._scheduled_cb.setChecked(scheduled_reindex_enabled())
        scheduled_row = _row_frame("bottom")
        sr_lay = QHBoxLayout(scheduled_row)
        sr_lay.setContentsMargins(16, 14, 16, 14)
        sched_text = QVBoxLayout()
        t1 = QLabel("Zamanlanmış yeniden indeks")
        t1.setStyleSheet(f"color: {T.TEXT_SECONDARY}; font-size: 14px; background: transparent;")
        t2 = QLabel("Her gün belirlenen saatte tam FTS5 indeksi oluştur")
        t2.setStyleSheet(f"color: {T.TEXT_MUTED}; font-size: 12px; background: transparent;")
        sched_text.addWidget(t1)
        sched_text.addWidget(t2)
        self._scheduled_hour = QSpinBox()
        self._scheduled_hour.setRange(0, 23)
        self._scheduled_hour.setValue(scheduled_reindex_hour())
        self._scheduled_hour.setSuffix(":00")
        self._scheduled_hour.setFixedWidth(72)
        self._scheduled_hour.setAccessibleName("Yeniden indeks saati")
        self._scheduled_cb.setAccessibleName("Zamanlanmış yeniden indeks")
        self._scheduled_cb.setStyleSheet(f"QCheckBox {{ color: {T.TEXT_SECONDARY}; }}")
        sr_lay.addLayout(sched_text, stretch=1)
        sr_lay.addWidget(self._scheduled_hour)
        sr_lay.addWidget(self._scheduled_cb)
        lay.addWidget(scheduled_row)

        stats = history_stats()
        hist_row = _row_frame("bottom")
        hr_lay = QHBoxLayout(hist_row)
        hr_lay.setContentsMargins(16, 14, 16, 14)
        hist_info = QVBoxLayout()
        h1 = QLabel("Arama geçmişi")
        h1.setStyleSheet(f"color: {T.TEXT_SECONDARY}; font-size: 14px; background: transparent;")
        self._history_label = QLabel(f"{stats.get('total', 0)} sorgu kayıtlı (yerel)")
        self._history_label.setStyleSheet(f"color: {T.TEXT_MUTED}; font-size: 12px; background: transparent;")
        hist_info.addWidget(h1)
        hist_info.addWidget(self._history_label)
        clear_hist = QPushButton("Temizle")
        clear_hist.setObjectName("Secondary")
        clear_hist.clicked.connect(self._clear_search_history)
        hr_lay.addLayout(hist_info, stretch=1)
        hr_lay.addWidget(clear_hist)
        lay.addWidget(hist_row)

        backend = backend_status()
        active = backend.get("active", "fts5")
        fts_ok = "hazır" if backend.get("fts5") else "henüz yok"
        tantivy = "yüklü" if backend.get("tantivy") else "yok"
        tav_ok = "hazır" if backend.get("tantivy_ready") else "henüz yok"
        backend_lbl = QLabel(
            f"Birincil backend: {active.upper()} · FTS5 ({fts_ok}) · Tantivy ({tantivy}, indeks {tav_ok}) — "
            f"{backend.get('tantivy_note', '')}"
        )
        backend_lbl.setWordWrap(True)
        backend_lbl.setStyleSheet(
            f"color: {T.TEXT_MUTED}; font-size: 11px; padding: 8px 16px 14px; background: transparent;"
        )
        lay.addWidget(backend_lbl)
        return sec

    def _clear_search_history(self) -> None:
        clear_history()
        self._history_label.setText("0 sorgu kayıtlı (yerel)")

    def _toggle_row(self, label: str, desc: str, checkbox: QCheckBox) -> QWidget:
        row = _row_frame("bottom")
        lay = QHBoxLayout(row)
        lay.setContentsMargins(16, 14, 16, 14)
        text = QVBoxLayout()
        t1 = QLabel(label)
        t1.setStyleSheet(f"color: {T.TEXT_SECONDARY}; font-size: 14px; background: transparent;")
        t2 = QLabel(desc)
        t2.setStyleSheet(f"color: {T.TEXT_MUTED}; font-size: 12px; background: transparent;")
        text.addWidget(t1)
        text.addWidget(t2)
        checkbox.setStyleSheet(f"QCheckBox {{ color: {T.TEXT_SECONDARY}; }}")
        # Etiket ayrı QLabel; ekran okuyucu onay kutusunu adıyla duyursun.
        checkbox.setAccessibleName(label)
        checkbox.setAccessibleDescription(desc)
        lay.addLayout(text, stretch=1)
        lay.addWidget(checkbox)
        return row

    def _section_hotkeys(self) -> QFrame:
        sec = QFrame()
        sec.setObjectName("Section")
        lay = QVBoxLayout(sec)
        lay.setContentsMargins(0, 0, 0, 0)

        heading = QLabel("KISAYOLLAR")
        heading.setObjectName("SectionTitle")
        lay.addWidget(heading)

        for label, keys in (
            ("Arama paletini aç / kapat", "Ctrl+Space"),
            ("Ayarlar", "Ctrl+,"),
            ("Klasörde göster", "Ctrl+Enter"),
            ("Yolu kopyala", "Ctrl+Shift+C"),
            ("Filtre: Tümü / Belgeler / Kod / Resimler", "Ctrl+1 … Ctrl+4"),
        ):
            row = _row_frame("bottom")
            rl = QHBoxLayout(row)
            rl.setContentsMargins(16, 12, 16, 12)
            lbl = QLabel(label)
            lbl.setStyleSheet(f"color: {T.TEXT_SECONDARY}; font-size: 14px; background: transparent;")
            keys_lbl = QLabel(keys)
            keys_lbl.setStyleSheet(
                f"color: {T.TEXT_MUTED}; font-family: {T.FONT_MONO}; font-size: 11px; background: transparent;"
            )
            rl.addWidget(lbl)
            rl.addStretch()
            rl.addWidget(keys_lbl)
            lay.addWidget(row)
        return sec

    def _section_reindex(self) -> QFrame:
        sec = QFrame()
        sec.setObjectName("Section")
        lay = QVBoxLayout(sec)
        lay.setContentsMargins(0, 0, 0, 0)

        row = QWidget()
        rl = QHBoxLayout(row)
        rl.setContentsMargins(16, 16, 16, 16)
        info = QVBoxLayout()
        h = QLabel("Tam yeniden indeksleme")
        h.setStyleSheet(f"color: {T.TEXT_SECONDARY}; font-size: 14px; font-weight: 500; background: transparent;")
        stats = get_index_stats()
        self._index_label = QLabel(self._format_index_label(stats))
        self._index_label.setStyleSheet(f"color: {T.TEXT_MUTED}; font-size: 12px; background: transparent;")
        info.addWidget(h)
        info.addWidget(self._index_label)
        self._rebuild_btn = QPushButton("Yeniden indeksle")
        self._rebuild_btn.setObjectName("Primary")
        self._rebuild_btn.clicked.connect(self._rebuild_index)
        rl.addLayout(info, stretch=1)
        rl.addWidget(self._rebuild_btn)
        lay.addWidget(row)

        backup_row = QWidget()
        br_lay = QHBoxLayout(backup_row)
        br_lay.setContentsMargins(16, 0, 16, 16)
        export_btn = QPushButton("İndeksi dışa aktar")
        export_btn.setObjectName("Secondary")
        export_btn.clicked.connect(self._export_index)
        import_btn = QPushButton("İndeksi içe aktar")
        import_btn.setObjectName("Secondary")
        import_btn.clicked.connect(self._import_index)
        br_lay.addWidget(export_btn)
        br_lay.addWidget(import_btn)
        br_lay.addStretch()
        lay.addWidget(backup_row)

        self._index_progress = QProgressBar()
        self._index_progress.setVisible(False)
        self._index_progress.setTextVisible(False)
        self._index_progress.setFixedHeight(3)
        prog_wrap = QWidget()
        pw = QVBoxLayout(prog_wrap)
        pw.setContentsMargins(16, 0, 16, 16)
        pw.addWidget(self._index_progress)
        lay.addWidget(prog_wrap)

        self._status_line = QLabel()
        self._status_line.setStyleSheet(
            f"color: {T.TEXT_MUTED}; font-family: {T.FONT_MONO}; font-size: 11px; "
            f"padding: 0 16px 14px; background: transparent;"
        )
        self._status_line.hide()
        lay.addWidget(self._status_line)
        return sec

    def _render_folders(self) -> None:
        if not self._folder_rows_layout:
            return
        while self._folder_rows_layout.count():
            item = self._folder_rows_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        for path in self._folders:
            short = path
            try:
                short = "~/" + Path(path).expanduser().resolve().relative_to(Path.home()).as_posix()
            except ValueError:
                pass
            row = _FolderRow(short, path, self._remove_folder)
            self._folder_rows_layout.addWidget(row)

    def _add_folder(self) -> None:
        folder = QFileDialog.getExistingDirectory(self, "Klasör seçin")
        if not folder:
            return
        norm = str(Path(folder).resolve())
        if norm in self._folders:
            return
        self._folders.append(norm)
        self._render_folders()

    def _remove_folder(self, path: str) -> None:
        if len(self._folders) <= 1:
            QMessageBox.warning(self, "Uyarı", "En az bir dizin kalmalı.")
            return
        for p in list(self._folders):
            try:
                short = "~/" + Path(p).expanduser().resolve().relative_to(Path.home()).as_posix()
            except ValueError:
                short = p
            if short == path or p == path:
                self._folders.remove(p)
                self._render_folders()
                return

    @staticmethod
    def _format_index_label(stats: dict) -> str:
        count = stats.get("count", 0)
        built = stats.get("built_at") or "henüz yok"
        count_str = f"{count:,}".replace(",", ".")
        return f"Son indeks: {built} · {count_str} dosya"

    def _rebuild_index(self) -> None:
        roots = [Path(p) for p in self._folders]
        if not roots:
            QMessageBox.warning(self, "Uyarı", "Önce en az bir klasör ekleyin.")
            return
        if self._index_worker is not None and self._index_worker.isRunning():
            return
        self._rebuild_btn.setEnabled(False)
        self._index_progress.setVisible(True)
        self._index_progress.setRange(0, 0)
        self._status_line.setText("Taranıyor…")
        self._status_line.show()
        self._index_worker = IndexBuildWorker(roots, self)
        self._index_worker.progress.connect(
            lambda n: self._status_line.setText(f"Taranıyor… {n} dosya")
        )
        self._index_worker.finished_count.connect(self._on_index_done)
        self._index_worker.failed.connect(self._on_index_failed)
        self._index_worker.start()

    def done(self, result: int) -> None:
        # İndeks sürerken kapatılırsa çalışan QThread yok edilip uygulama çökmesin.
        if self._index_worker is not None and self._index_worker.isRunning():
            self._index_worker.cancel()
            self._index_worker.wait(5000)
        super().done(result)

    def _on_index_done(self, count: int) -> None:
        self._rebuild_btn.setEnabled(True)
        self._index_progress.setVisible(False)
        self._status_line.hide()
        self._index_label.setText(self._format_index_label(get_index_stats()))
        QMessageBox.information(self, "İndeks", f"{count:,}".replace(",", ".") + " dosya indekslendi.")
        self._index_worker = None

    def _on_index_failed(self, msg: str) -> None:
        self._rebuild_btn.setEnabled(True)
        self._index_progress.setVisible(False)
        self._status_line.setText("Hata: " + msg)
        QMessageBox.warning(self, "İndeks hatası", msg)
        self._index_worker = None

    def _export_index(self) -> None:
        backend = active_backend_name()
        if backend == "tantivy":
            path, _ = QFileDialog.getSaveFileName(
                self,
                "Tantivy indeks yedeğini kaydet",
                str(Path.home() / "tantivy_index_backup.zip"),
                "Zip arşivi (*.zip);;Tüm dosyalar (*)",
            )
        else:
            path, _ = QFileDialog.getSaveFileName(
                self,
                "İndeks yedeğini kaydet",
                str(Path.home() / "fts_index_backup.db"),
                "SQLite (*.db);;Tüm dosyalar (*)",
            )
        if not path:
            return
        try:
            dest = export_index(Path(path))
            QMessageBox.information(self, "Dışa aktarma", f"İndeks kaydedildi:\n{dest}")
        except OSError as exc:
            QMessageBox.warning(self, "Hata", str(exc))

    def _import_index(self) -> None:
        backend = active_backend_name()
        if backend == "tantivy":
            path, _ = QFileDialog.getOpenFileName(
                self,
                "Tantivy indeks yedeğini seç",
                str(Path.home()),
                "Zip arşivi (*.zip);;Tüm dosyalar (*)",
            )
        else:
            path, _ = QFileDialog.getOpenFileName(
                self,
                "İndeks yedeğini seç",
                str(Path.home()),
                "SQLite (*.db);;Tüm dosyalar (*)",
            )
        if not path:
            return
        reply = QMessageBox.question(
            self,
            "İçe aktarma",
            "Mevcut indeks üzerine yazılacak. Devam edilsin mi?",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
        )
        if reply != QMessageBox.StandardButton.Yes:
            return
        try:
            import_index(Path(path))
            self._index_label.setText(self._format_index_label(get_index_stats()))
            QMessageBox.information(self, "İçe aktarma", "İndeks geri yüklendi.")
        except OSError as exc:
            QMessageBox.warning(self, "Hata", str(exc))

    def _save(self) -> None:
        if not self._folders:
            QMessageBox.warning(self, "Uyarı", "En az bir klasör ekleyin.")
            return
        patterns = [
            line.strip()
            for line in self._exclude_edit.toPlainText().splitlines()
            if line.strip()
        ]
        save_settings({
            "search_roots": self._folders,
            "search_in_content": self._content_cb.isChecked(),
            "show_snippets": self._snippets_cb.isChecked(),
            "background_scan": self._bg_cb.isChecked(),
            "watcher_enabled": self._watcher_cb.isChecked(),
            "fuzzy_search_enabled": self._fuzzy_cb.isChecked(),
            "tantivy_primary": self._tantivy_cb.isChecked(),
            "everything_bridge_enabled": self._everything_cb.isChecked(),
            "everything_filter_to_roots": self._everything_filter_cb.isChecked(),
            "scheduled_reindex_enabled": self._scheduled_cb.isChecked(),
            "scheduled_reindex_hour": self._scheduled_hour.value(),
            "exclude_patterns": patterns,
        })
        self.accept()
