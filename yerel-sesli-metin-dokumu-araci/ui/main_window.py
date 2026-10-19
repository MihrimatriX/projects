from __future__ import annotations

from pathlib import Path

from PySide6.QtCore import QSettings, QThread, QTimer, QUrl, Qt, Signal
from PySide6.QtGui import QKeySequence, QShortcut
from PySide6.QtMultimedia import QAudioOutput, QMediaPlayer
from PySide6.QtWidgets import (
    QComboBox,
    QFileDialog,
    QFrame,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QProgressBar,
    QPushButton,
    QScrollArea,
    QStackedWidget,
    QStatusBar,
    QVBoxLayout,
    QWidget,
)

from ui.theme import APP_STYLE, TEXT_PRIMARY, TEXT_SECONDARY
from ui.widgets import InfoBanner, NavToolbar, SegmentRow, WaveformWidget
from utils.job_history import add_job, delete_job, list_jobs
from utils.time_fmt import format_duration, format_job_date
from utils.transcribe import DEFAULT_MODEL, EXPORTERS, MODELS, Cancelled, TranscriptResult, app_dir, is_model_ready, transcribe_file

AUDIO_FILTER = "Ses (*.mp3 *.wav *.m4a *.ogg *.opus *.flac *.webm *.mp4);;Tüm (*.*)"


def _settings() -> QSettings:
    return QSettings(str(app_dir() / "settings.ini"), QSettings.Format.IniFormat)


class TranscribeWorker(QThread):
    # Çözme + ağ isteği GUI'yi dondurmasın diye ayrı thread'de; sonuç sinyalle döner
    progress = Signal(str, int)
    finished_ok = Signal(object)
    failed = Signal(str)

    def __init__(self, path: str, model: str, parent=None) -> None:
        super().__init__(parent)
        self._path = path
        self._model = model

    def run(self) -> None:
        try:
            result = transcribe_file(
                self._path,
                model=self._model,
                on_progress=lambda msg, pct: self.progress.emit(msg, pct),
                should_stop=self.isInterruptionRequested,
            )
            self.finished_ok.emit(result)
        except Cancelled:
            self.failed.emit("İptal edildi")
        except Exception as exc:
            self.failed.emit(str(exc))


class WorkspacePage(QWidget):
    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._result: TranscriptResult | None = None
        self._worker: TranscribeWorker | None = None
        self._segment_rows: list[SegmentRow] = []
        self._active_seg = 0

        self._player = QMediaPlayer(self)
        self._audio = QAudioOutput(self)
        self._player.setAudioOutput(self._audio)
        self._player.positionChanged.connect(self._on_position)
        self._player.durationChanged.connect(self._on_duration)
        self._player.playbackStateChanged.connect(self._on_play_state)

        root = QHBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        self._sidebar = QFrame()
        self._sidebar.setObjectName("Sidebar")
        self._sidebar.setFixedWidth(260)
        sb = QVBoxLayout(self._sidebar)
        sb.setContentsMargins(0, 0, 0, 0)
        hdr = QHBoxLayout()
        hdr.setContentsMargins(16, 16, 16, 16)
        title = QLabel("GEÇMİŞ")
        title.setStyleSheet(f"color: {TEXT_SECONDARY}; font-weight: 600; font-size: 13px;")
        hdr.addWidget(title)
        hdr.addStretch()
        sb.addLayout(hdr)
        self._history_box = QVBoxLayout()
        self._history_box.setContentsMargins(8, 8, 8, 8)
        self._history_box.setSpacing(4)
        hist_scroll = QScrollArea()
        hist_scroll.setWidgetResizable(True)
        hist_host = QWidget()
        hist_host.setLayout(self._history_box)
        hist_scroll.setWidget(hist_host)
        sb.addWidget(hist_scroll, stretch=1)
        root.addWidget(self._sidebar)

        center = QVBoxLayout()
        center.setSpacing(0)
        center_w = QWidget()
        center_w.setLayout(center)

        file_bar = QFrame()
        file_bar.setObjectName("FileBar")
        fb = QHBoxLayout(file_bar)
        fb.setContentsMargins(20, 12, 20, 12)
        self._filename = QLabel("Ses dosyası seçin")
        self._filename.setStyleSheet("font-weight: 500;")
        self._duration_l = QLabel("")
        self._duration_l.setObjectName("Mono")
        self._model_combo = QComboBox()
        self._model_combo.setToolTip("Yerel Whisper modeli — büyük model daha doğru ama daha yavaş")
        for size, mb in MODELS.items():
            self._model_combo.addItem(f"{size} (~{mb} MB)", size)
        saved = str(_settings().value("model", DEFAULT_MODEL))
        self._model_combo.setCurrentIndex(max(0, self._model_combo.findData(saved)))
        self._model_combo.currentIndexChanged.connect(self._on_model_changed)
        fb.addWidget(self._filename, stretch=1)
        fb.addWidget(self._model_combo)
        fb.addWidget(self._duration_l)
        center.addWidget(file_bar)

        wave_wrap = QVBoxLayout()
        wave_wrap.setContentsMargins(20, 24, 20, 16)
        self._wave = WaveformWidget()
        self._wave.seek_requested.connect(self._seek_ratio)
        wave_wrap.addWidget(self._wave)
        time_row = QHBoxLayout()
        self._cur_time = QLabel("00:00")
        self._cur_time.setObjectName("Mono")
        self._end_time = QLabel("00:00")
        self._end_time.setObjectName("Mono")
        time_row.addWidget(self._cur_time)
        time_row.addStretch()
        time_row.addWidget(self._end_time)
        wave_wrap.addLayout(time_row)
        wave_host = QWidget()
        wave_host.setLayout(wave_wrap)
        center.addWidget(wave_host)

        transport = QFrame()
        transport.setObjectName("SectionBorder")
        tr = QHBoxLayout(transport)
        tr.setContentsMargins(20, 12, 20, 12)
        self._back_btn = QPushButton("⏮")
        self._back_btn.setObjectName("TransportBtn")
        self._back_btn.clicked.connect(lambda: self._skip(-5))
        self._play_btn = QPushButton("▶")
        self._play_btn.setObjectName("TransportPrimary")
        self._play_btn.clicked.connect(self._toggle_play)
        self._fwd_btn = QPushButton("⏭")
        self._fwd_btn.setObjectName("TransportBtn")
        self._fwd_btn.clicked.connect(lambda: self._skip(5))
        tr.addWidget(self._back_btn)
        tr.addWidget(self._play_btn)
        tr.addWidget(self._fwd_btn)
        tr.addStretch()
        hint = QLabel("Space · ← →")
        hint.setObjectName("Mono")
        tr.addWidget(hint)
        center.addWidget(transport)

        prog_sec = QVBoxLayout()
        prog_sec.setContentsMargins(20, 16, 20, 16)
        prog_l = QLabel("Transkripsiyon ilerlemesi")
        prog_l.setObjectName("Secondary")
        prog_l.setStyleSheet(f"color: {TEXT_SECONDARY}; font-size: 12px;")
        self._progress = QProgressBar()
        self._progress.setVisible(False)
        self._prog_meta = QLabel("")
        self._prog_meta.setObjectName("Mono")
        prog_sec.addWidget(prog_l)
        prog_sec.addWidget(self._progress)
        prog_sec.addWidget(self._prog_meta)
        prog_host = QWidget()
        prog_host.setLayout(prog_sec)
        center.addWidget(prog_host, stretch=1)
        root.addWidget(center_w, stretch=1)

        self._transcript = QFrame()
        self._transcript.setObjectName("TranscriptPanel")
        self._transcript.setFixedWidth(360)
        tp = QVBoxLayout(self._transcript)
        tp.setContentsMargins(0, 0, 0, 0)
        th = QHBoxLayout()
        th.setContentsMargins(20, 16, 20, 16)
        th.addWidget(QLabel("Transkript"))
        th.itemAt(0).widget().setStyleSheet("font-size: 15px; font-weight: 600;")
        th.addStretch()
        self._export_btns: dict[str, QPushButton] = {}
        for fmt in EXPORTERS:
            btn = QPushButton(f".{fmt}")
            btn.setObjectName("ExportBtn")
            btn.setEnabled(False)
            th.addWidget(btn)
            self._export_btns[fmt] = btn
        tp.addLayout(th)
        self._segments_scroll = QScrollArea()
        self._segments_scroll.setWidgetResizable(True)
        self._segments_host = QWidget()
        self._segments_layout = QVBoxLayout(self._segments_host)
        self._segments_layout.setContentsMargins(0, 8, 0, 8)
        self._segments_layout.addStretch()
        self._segments_scroll.setWidget(self._segments_host)
        tp.addWidget(self._segments_scroll, stretch=1)
        root.addWidget(self._transcript)

        self._duration_ms = 0

    def bind(self, window: QMainWindow) -> None:
        self._window = window
        for fmt, btn in self._export_btns.items():
            btn.clicked.connect(lambda _=False, f=fmt: self._export(f))
        QShortcut(QKeySequence("Space"), self, self._toggle_play)
        QShortcut(QKeySequence("Left"), self, lambda: self._skip(-5))
        QShortcut(QKeySequence("Right"), self, lambda: self._skip(5))

    def refresh_history(self) -> None:
        while self._history_box.count():
            item = self._history_box.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        for job in list_jobs():
            btn = QPushButton()
            btn.setObjectName("HistoryItem")
            btn.setCheckable(True)
            btn.setText(f"{job['file_name']}\n{format_job_date(job['created_at'])}")
            path = job.get("file_path") or ""
            btn.clicked.connect(lambda _=False, p=path: self.load_file(p) if p and Path(p).exists() else None)
            self._history_box.addWidget(btn)

    def open_import(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self._window, "Ses dosyası", filter=AUDIO_FILTER)
        if path:
            self.load_file(path)

    def load_file(self, path: str) -> None:
        if self._worker and self._worker.isRunning():
            # Eski iş bitince sonucu yeni dosyanın üzerine yazmasın
            self._window.statusBar().showMessage("Önceki transkripsiyon sürüyor — bitmesini bekleyin")
            return
        self._filename.setText(Path(path).name)
        self._player.setSource(QUrl.fromLocalFile(path))
        self._start_transcribe(path)

    def _start_transcribe(self, path: str) -> None:
        self._progress.setVisible(True)
        self._progress.setObjectName("")
        self._progress.setRange(0, 100)
        self._progress.setValue(0)
        self._prog_meta.setText("Başlatılıyor…")
        self._clear_segments()
        self._result = None
        self._wave.set_peaks([])
        for btn in self._export_btns.values():
            btn.setEnabled(False)

        self._worker = TranscribeWorker(path, self._model_combo.currentData(), self)
        self._worker.progress.connect(self._on_progress)
        self._worker.finished_ok.connect(self._on_done)
        self._worker.failed.connect(self._on_failed)
        self._worker.start()

    def _on_progress(self, message: str, percent: int) -> None:
        self._progress.setValue(percent)
        self._prog_meta.setText(message)
        self._window.statusBar().showMessage(message)

    def _on_done(self, result: TranscriptResult) -> None:
        self._progress.setValue(100)
        self._progress.setObjectName("Complete")
        self._progress.style().unpolish(self._progress)
        self._progress.style().polish(self._progress)
        self._prog_meta.setText("Tamamlandı")
        self._result = result
        self._duration_l.setText(format_duration(result.duration_sec))
        self._end_time.setText(format_duration(result.duration_sec))
        self._render_segments(result.segments)
        self._wave.set_peaks(result.peaks)
        add_job(result.file_path, result.duration_sec)
        self.refresh_history()
        for btn in self._export_btns.values():
            btn.setEnabled(bool(result.segments))
        self._window.statusBar().showMessage("Transkripsiyon tamamlandı")
        self._worker = None

    def _on_failed(self, msg: str) -> None:
        self._progress.setVisible(False)
        self._prog_meta.setText(f"Hata: {msg}")
        self._window.statusBar().showMessage("Transkripsiyon başarısız")
        self._worker = None

    def _clear_segments(self) -> None:
        while self._segments_layout.count() > 1:
            item = self._segments_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self._segment_rows.clear()

    def _on_model_changed(self) -> None:
        size = self._model_combo.currentData()
        _settings().setValue("model", size)
        if not is_model_ready(size):
            self._window.statusBar().showMessage(f"'{size}' modeli ilk transkripsiyonda indirilecek (~{MODELS[size]} MB)")

    def _render_segments(self, segments: list[tuple[float, float, str]]) -> None:
        self._clear_segments()
        if not segments:
            empty = QLabel("Konuşma algılanmadı.")
            empty.setObjectName("Muted")
            empty.setContentsMargins(20, 10, 20, 10)
            self._segments_layout.insertWidget(0, empty)
        for i, (start, _end, text) in enumerate(segments):
            row = SegmentRow(start, text)
            row.clicked.connect(self._seek_seconds)
            row.set_active(i == 0)
            self._segments_layout.insertWidget(i, row)
            self._segment_rows.append(row)
        self._active_seg = 0

    def _on_duration(self, ms: int) -> None:
        self._duration_ms = ms
        self._end_time.setText(format_duration(ms / 1000))

    def _on_position(self, ms: int) -> None:
        if self._duration_ms > 0:
            ratio = ms / self._duration_ms
            self._wave.set_progress(ratio)
        self._cur_time.setText(format_duration(ms / 1000))
        sec = ms / 1000
        idx = 0
        if self._result:
            for i, (start, _, _) in enumerate(self._result.segments):
                if sec >= start:
                    idx = i
        if idx != self._active_seg:
            self._active_seg = idx
            for i, row in enumerate(self._segment_rows):
                row.set_active(i == idx)

    def _on_play_state(self) -> None:
        playing = self._player.playbackState() == QMediaPlayer.PlaybackState.PlayingState
        self._play_btn.setText("⏸" if playing else "▶")

    def _toggle_play(self) -> None:
        if self._player.playbackState() == QMediaPlayer.PlaybackState.PlayingState:
            self._player.pause()
        elif self._player.source().isValid():
            self._player.play()

    def _skip(self, delta: int) -> None:
        self._player.setPosition(max(0, self._player.position() + delta * 1000))

    def _seek_ratio(self, ratio: float) -> None:
        if self._duration_ms > 0:
            self._player.setPosition(int(ratio * self._duration_ms))

    def _seek_seconds(self, sec: float) -> None:
        self._player.setPosition(int(sec * 1000))

    def _export(self, fmt: str) -> None:
        if not self._result:
            return
        default = str(Path(self._result.file_path).with_suffix(f".{fmt}"))
        path, _ = QFileDialog.getSaveFileName(self._window, f"{fmt.upper()} kaydet", default, f"{fmt.upper()} (*.{fmt})")
        if not path:
            return
        try:
            Path(path).write_text(EXPORTERS[fmt](self._result.segments), encoding="utf-8")
        except OSError as exc:
            QMessageBox.warning(self._window, "Kaydedilemedi", f"Dosya kaydedilemedi:\n{path}\n\n{exc}")
            return
        self._flash_export(self._export_btns[fmt])
        self._window.statusBar().showMessage(f"Kaydedildi: {path}")

    def _flash_export(self, btn: QPushButton) -> None:
        original = btn.text()
        btn.setText("✓")
        btn.setObjectName("ExportBtnDone")
        btn.style().unpolish(btn)
        btn.style().polish(btn)

        def reset() -> None:
            btn.setObjectName("ExportBtn")
            btn.setText(original)
            btn.style().unpolish(btn)
            btn.style().polish(btn)

        QTimer.singleShot(2000, reset)


class HistoryPage(QWidget):
    open_in_workspace = Signal(str)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self._jobs: list[dict] = []
        self._selected_id: int | None = None

        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        left = QFrame()
        left.setObjectName("Sidebar")
        left.setFixedWidth(420)
        ll = QVBoxLayout(left)
        ll.setContentsMargins(0, 0, 0, 0)
        hdr = QVBoxLayout()
        hdr.setContentsMargins(20, 20, 20, 12)
        h1 = QLabel("İş geçmişi")
        h1.setStyleSheet("font-size: 18px; font-weight: 600;")
        sub = QLabel("Son 50 kayıt · ~/.yerel-sesli-metin-dokumu/")
        sub.setObjectName("Muted")
        hdr.addWidget(h1)
        hdr.addWidget(sub)
        ll.addLayout(hdr)

        self._search = QLineEdit()
        self._search.setPlaceholderText("Dosya adında ara…")
        search_row = QHBoxLayout()
        search_row.setContentsMargins(16, 0, 16, 12)
        search_row.addWidget(self._search)
        ll.addLayout(search_row)

        self._job_box = QVBoxLayout()
        self._job_box.setContentsMargins(8, 0, 8, 8)
        self._job_box.setSpacing(4)
        job_scroll = QScrollArea()
        job_scroll.setWidgetResizable(True)
        job_host = QWidget()
        job_host.setLayout(self._job_box)
        job_scroll.setWidget(job_host)
        ll.addWidget(job_scroll, stretch=1)

        note = QLabel("SQLite · transkript loglanmaz")
        note.setObjectName("Mono")
        note.setContentsMargins(16, 12, 16, 12)
        ll.addWidget(note)
        layout.addWidget(left)

        detail = QWidget()
        dl = QVBoxLayout(detail)
        dl.setContentsMargins(28, 24, 28, 16)
        self._detail_title = QLabel("Kayıt seçin")
        self._detail_title.setStyleSheet("font-size: 20px; font-weight: 600;")
        self._detail_meta = QLabel("")
        self._detail_meta.setObjectName("Mono")
        dl.addWidget(self._detail_title)
        dl.addWidget(self._detail_meta)
        self._detail_body = QLabel("Sol panelden bir iş seçin.")
        self._detail_body.setWordWrap(True)
        self._detail_body.setObjectName("Secondary")
        dl.addWidget(self._detail_body, stretch=1)

        actions = QHBoxLayout()
        self._load_btn = QPushButton("Ana alanda aç")
        self._load_btn.setObjectName("PrimaryBtn")
        self._load_btn.setEnabled(False)
        self._delete_btn = QPushButton("Sil")
        self._delete_btn.setEnabled(False)
        actions.addWidget(self._load_btn)
        actions.addWidget(self._delete_btn)
        actions.addStretch()
        dl.addLayout(actions)
        layout.addWidget(detail, stretch=1)

        self._search.textChanged.connect(self._filter_jobs)
        self._load_btn.clicked.connect(self._load_selected)
        self._delete_btn.clicked.connect(self._delete_selected)

    def refresh(self) -> None:
        self._jobs = list_jobs()
        self._render_jobs(self._jobs)

    def _filter_jobs(self, text: str) -> None:
        q = text.lower()
        filtered = [j for j in self._jobs if q in j["file_name"].lower()]
        self._render_jobs(filtered)

    def _render_jobs(self, jobs: list[dict]) -> None:
        while self._job_box.count():
            item = self._job_box.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        for job in jobs:
            btn = QPushButton()
            btn.setObjectName("JobItem")
            btn.setCheckable(True)
            dur = format_duration(job.get("duration_sec"))
            btn.setText(f"{job['file_name']}\n{format_job_date(job['created_at'])} · {dur}")
            btn.clicked.connect(lambda _=False, j=job: self._select_job(j))
            self._job_box.addWidget(btn)
        if jobs:
            self._select_job(jobs[0])

    def _select_job(self, job: dict) -> None:
        self._selected_id = job["id"]
        self._detail_title.setText(job["file_name"])
        dur = format_duration(job.get("duration_sec"))
        self._detail_meta.setText(f"{format_job_date(job['created_at'])} · {dur} · Yerel Whisper")
        path = job.get("file_path") or ""
        exists = path and Path(path).exists()
        self._detail_body.setText(
            f"Dosya yolu:\n{path or '—'}\n\n"
            + ("Dosya mevcut — ana alanda açabilirsiniz." if exists else "Dosya artık bu konumda yok.")
        )
        self._load_btn.setEnabled(bool(exists))
        self._delete_btn.setEnabled(True)

    def _load_selected(self) -> None:
        job = next((j for j in self._jobs if j["id"] == self._selected_id), None)
        if job and job.get("file_path"):
            self.open_in_workspace.emit(job["file_path"])

    def _delete_selected(self) -> None:
        if self._selected_id is None:
            return
        if QMessageBox.question(self, "Sil", "Bu kaydı silmek istiyor musunuz?") != QMessageBox.StandardButton.Yes:
            return
        delete_job(self._selected_id)
        self.refresh()


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Sesli Metin Dökümü")
        self.resize(1280, 800)
        self.setStyleSheet(APP_STYLE)

        root = QWidget()
        root.setObjectName("AppRoot")
        layout = QVBoxLayout(root)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        self._banner = InfoBanner()
        layout.addWidget(self._banner)

        self._toolbar = NavToolbar()
        self._toolbar.page_changed.connect(self._on_page)
        self._toolbar.open_file.connect(self._open_file)
        self._toolbar.toggle_sidebar.connect(self._toggle_sidebar)
        layout.addWidget(self._toolbar)

        self._stack = QStackedWidget()
        self._workspace = WorkspacePage()
        self._workspace.bind(self)
        self._history = HistoryPage()
        self._stack.addWidget(self._workspace)
        self._stack.addWidget(self._history)
        layout.addWidget(self._stack, stretch=1)

        self.setCentralWidget(root)
        self.setStatusBar(QStatusBar())
        self.statusBar().showMessage("Hazır — ses dosyası seçin (Ctrl+O)")

        self._history.open_in_workspace.connect(self._open_job_in_workspace)
        self._workspace.refresh_history()
        self._history.refresh()

        QShortcut(QKeySequence("Ctrl+O"), self, self._open_file)
        QShortcut(QKeySequence("Ctrl+H"), self, self._toggle_sidebar)

    def _on_page(self, idx: int) -> None:
        self._stack.setCurrentIndex(idx)
        if idx == 1:
            self._history.refresh()

    def _open_file(self) -> None:
        self._stack.setCurrentIndex(0)
        self._toolbar.set_page(0)
        self._workspace.open_import()

    def _toggle_sidebar(self) -> None:
        self._stack.setCurrentIndex(0)
        self._toolbar.set_page(0)
        self._workspace._sidebar.setVisible(not self._workspace._sidebar.isVisible())

    def _open_job_in_workspace(self, path: str) -> None:
        self._stack.setCurrentIndex(0)
        self._toolbar.set_page(0)
        self._workspace.load_file(path)

    def closeEvent(self, event) -> None:
        # Çalışan QThread yok edilirse uygulama çöker; transkripsiyonun bitmesini bekle
        worker = self._workspace._worker
        if worker and worker.isRunning():
            self.statusBar().showMessage("Transkripsiyon iptal ediliyor…")
            worker.requestInterruption()
            worker.wait()
        super().closeEvent(event)
