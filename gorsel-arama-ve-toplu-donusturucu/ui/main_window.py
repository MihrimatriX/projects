from __future__ import annotations

import os
import time
from dataclasses import asdict, dataclass
from pathlib import Path

from PySide6.QtCore import Qt, QThread, Signal
from PySide6.QtGui import QDragEnterEvent, QDropEvent, QImageReader, QKeySequence, QPixmap, QShortcut
from PySide6.QtWidgets import (
    QCheckBox,
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
    QSlider,
    QStatusBar,
    QVBoxLayout,
    QWidget,
)

from ui.theme import (
    APP_STYLE,
    BADGE_LABELS,
    BADGE_STYLES,
    BG_ERROR,
    BG_HOVER,
    BG_SELECTED,
    BG_THUMB,
    ERROR,
    RADIUS_MD,
    RADIUS_SM,
    TEXT_MUTED,
    TEXT_PRIMARY,
    TEXT_SECONDARY,
)
from utils.config import (
    DEFAULT_MAX_HEIGHT,
    DEFAULT_MAX_WIDTH,
    DEFAULT_OUTPUT,
    DEFAULT_QUALITY,
    FORMATS,
    HEIGHT_PRESETS,
    MIN_HEIGHT,
    MIN_WIDTH,
    SIDEBAR_WIDTH,
    WIDTH_PRESETS,
    load_settings,
    save_settings,
)
from utils.convert_options import ConvertOptions
from utils.image_convert import collect_images, common_root, convert_batch, format_meta, target_path


@dataclass
class Job:
    path: str
    status: str = "pending"
    meta: str = ""
    error: str = ""


class ConvertWorker(QThread):
    # Dönüştürme arka plan thread'inde çalışır; sonuçlar sinyallerle (kuyruklu bağlantı)
    # GUI thread'ine taşınır, Job listesi yalnızca GUI thread'inde değiştirilir.
    file_done = Signal(int, str, str)
    progress = Signal(int, int)
    finished_ok = Signal(int, int)
    finished_cancelled = Signal(int)

    def __init__(
        self, sources: list[str], output_dir: str, opts: ConvertOptions, parent=None
    ) -> None:
        super().__init__(parent)
        self._sources = sources
        self._output_dir = output_dir
        self._opts = opts
        self._cancel = False

    def cancel(self) -> None:
        self._cancel = True

    def run(self) -> None:
        converted, errors = convert_batch(
            self._sources,
            self._output_dir,
            self._opts,
            on_file=lambda idx, dest, err: self.file_done.emit(idx, dest or "", err or ""),
            on_progress=lambda cur, tot: self.progress.emit(cur, tot),
            cancel_check=lambda: self._cancel,
        )
        if self._cancel:
            self.finished_cancelled.emit(len(converted))
        else:
            self.finished_ok.emit(len(converted), len(errors))


class DropZone(QFrame):
    activated = Signal()
    paths_dropped = Signal(list)

    def __init__(self, parent=None) -> None:
        super().__init__(parent)
        self.setObjectName("DropZone")
        self.setAcceptDrops(True)
        self.setMinimumHeight(120)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
        self.setAccessibleName("Dosya ekle: tıklayın, Enter'a basın veya dosya/klasör bırakın")
        lay = QVBoxLayout(self)
        lay.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title = QLabel("Dosya veya klasör bırakın")
        title.setStyleSheet(f"color: {TEXT_PRIMARY}; font-size: 14px; font-weight: 500; background: transparent;")
        hint = QLabel("JPEG, PNG, WebP, AVIF, TIFF · Ctrl+O")
        hint.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 12px; background: transparent;")
        lay.addWidget(title, alignment=Qt.AlignmentFlag.AlignCenter)
        lay.addWidget(hint, alignment=Qt.AlignmentFlag.AlignCenter)

    def mousePressEvent(self, event) -> None:
        self.activated.emit()

    def keyPressEvent(self, event) -> None:
        # Odaklanabilir ama klavyeyle etkinleştirilemiyordu
        if event.key() in (Qt.Key.Key_Return, Qt.Key.Key_Enter, Qt.Key.Key_Space):
            self.activated.emit()
        else:
            super().keyPressEvent(event)

    def dragEnterEvent(self, event: QDragEnterEvent) -> None:
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            self.setProperty("dragOver", True)
            self.style().unpolish(self)
            self.style().polish(self)

    def dragLeaveEvent(self, event) -> None:
        self.setProperty("dragOver", False)
        self.style().unpolish(self)
        self.style().polish(self)
        super().dragLeaveEvent(event)

    def dropEvent(self, event: QDropEvent) -> None:
        self.setProperty("dragOver", False)
        self.style().unpolish(self)
        self.style().polish(self)
        paths = [url.toLocalFile() for url in event.mimeData().urls() if url.toLocalFile()]
        event.acceptProposedAction()
        if paths:
            self.paths_dropped.emit(paths)
        else:
            self.activated.emit()


_THUMBS: dict[str, QPixmap] = {}


def _thumbnail(path: str) -> QPixmap:
    """Küçük resim; her yeniden çizimde tam boyutlu görseli tekrar okumamak için önbellekli."""
    # ponytail: sınırsız önbellek (dosya başına ~20 KB); binlerce dosyada LRU'ya geçilebilir
    pix = _THUMBS.get(path)
    if pix is None:
        reader = QImageReader(path)
        reader.setAutoTransform(True)
        size = reader.size()
        if size.isValid() and min(size.width(), size.height()) > 72:
            reader.setScaledSize(size * (72 / min(size.width(), size.height())))
        pix = QPixmap.fromImage(reader.read())
        _THUMBS[path] = pix
    return pix


class JobRow(QFrame):
    clicked = Signal(int)

    def __init__(self, job: Job, index: int, selected: bool, parent=None) -> None:
        super().__init__(parent)
        self._index = index
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setMinimumHeight(48)
        self._selected = selected
        self._error = job.status == "error"
        self._apply_bg(selected, self._error)
        lay = QHBoxLayout(self)
        lay.setContentsMargins(12, 10, 12, 10)
        lay.setSpacing(14)
        thumb = QLabel()
        thumb.setFixedSize(36, 36)
        thumb.setStyleSheet(f"background: {BG_THUMB}; border-radius: {RADIUS_SM}px;")
        pix = _thumbnail(job.path)
        if not pix.isNull():
            thumb.setPixmap(
                pix.scaled(36, 36, Qt.AspectRatioMode.KeepAspectRatioByExpanding,
                           Qt.TransformationMode.SmoothTransformation)
            )
            thumb.setScaledContents(True)
        lay.addWidget(thumb)
        info = QVBoxLayout()
        info.setSpacing(2)
        name = QLabel(Path(job.path).name)
        name.setStyleSheet(f"color: {TEXT_PRIMARY}; font-size: 13px; font-weight: 500; background: transparent;")
        meta = QLabel(job.meta or job.error or "…")
        meta_color = ERROR if job.status == "error" else TEXT_MUTED
        meta.setStyleSheet(
            f"color: {meta_color}; font-size: 11px; font-family: Cascadia Mono, Consolas, monospace; background: transparent;"
        )
        info.addWidget(name)
        info.addWidget(meta)
        lay.addLayout(info, stretch=1)
        badge = QLabel(BADGE_LABELS.get(job.status, job.status))
        self.setAccessibleName(f"{name.text()}: {badge.text()}")
        badge.setStyleSheet(
            BADGE_STYLES.get(job.status, BADGE_STYLES["pending"])
            + f" font-size: 10px; font-weight: 500; padding: 4px 10px; border-radius: {RADIUS_MD}px;"
        )
        lay.addWidget(badge)

    def _apply_bg(self, selected: bool, error: bool) -> None:
        if error:
            bg = BG_ERROR
        elif selected:
            bg = BG_SELECTED
        else:
            bg = "transparent"
        self.setStyleSheet(f"JobRow {{ background: {bg}; border-radius: {RADIUS_MD}px; }}")

    def mousePressEvent(self, event) -> None:
        self.clicked.emit(self._index)
        super().mousePressEvent(event)

    def enterEvent(self, event) -> None:
        if not (self._selected or self._error):
            self.setStyleSheet(f"JobRow {{ background: {BG_HOVER}; border-radius: {RADIUS_MD}px; }}")
        super().enterEvent(event)

    def leaveEvent(self, event) -> None:
        # Vurgu fare çıkınca kalkmıyordu
        self._apply_bg(self._selected, self._error)
        super().leaveEvent(event)


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("Görsel Arama ve Toplu Dönüştürücü")
        self.setMinimumSize(MIN_WIDTH, MIN_HEIGHT)
        self.resize(980, 680)
        self.setStyleSheet(APP_STYLE)
        self.setAcceptDrops(True)

        self._jobs: list[Job] = []
        self._selected = -1
        self._max_width = DEFAULT_MAX_WIDTH
        self._max_height = DEFAULT_MAX_HEIGHT
        self._output_dir = str(DEFAULT_OUTPUT)
        self._worker: ConvertWorker | None = None
        self._batch_start = 0.0
        self._batch_running = False

        root = QWidget()
        root.setObjectName("CentralWidget")
        body = QHBoxLayout(root)
        body.setContentsMargins(0, 0, 0, 0)
        body.setSpacing(0)
        body.addWidget(self._build_sidebar())
        body.addWidget(self._build_main(), stretch=1)
        self.setCentralWidget(root)
        self._build_statusbar()
        self._bind_shortcuts()
        self._webp_lossless.toggled.connect(self._sync_codec_panel)
        self._apply_settings(load_settings())
        self._sync_codec_panel()
        self._sync_ui()

    def _build_sidebar(self) -> QFrame:
        side = QFrame()
        side.setObjectName("Sidebar")
        side.setFixedWidth(SIDEBAR_WIDTH)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        inner = QWidget()
        lay = QVBoxLayout(inner)
        lay.setContentsMargins(18, 20, 18, 20)
        lay.setSpacing(16)

        title = QLabel("Dönüştürme Ayarları")
        title.setObjectName("SidebarTitle")
        lay.addWidget(title)

        lay.addWidget(self._field_label("Codec / Format"))
        self._fmt = QComboBox()
        self._fmt.addItems(FORMATS)
        self._fmt.setAccessibleName("Çıktı formatı")
        self._fmt.currentTextChanged.connect(self._on_format_changed)
        lay.addWidget(self._fmt)

        lay.addWidget(self._field_label("Max Genişlik"))
        self._width_btn_list: list[QPushButton] = []
        lay.addLayout(self._preset_row(WIDTH_PRESETS, DEFAULT_MAX_WIDTH, self._set_width, self._width_btn_list, "Max genişlik"))

        lay.addWidget(self._field_label("Max Yükseklik"))
        self._height_btn_list: list[QPushButton] = []
        lay.addLayout(self._preset_row(HEIGHT_PRESETS, DEFAULT_MAX_HEIGHT, self._set_height, self._height_btn_list, "Max yükseklik"))

        lay.addWidget(self._field_label("Kalite"))
        qual_row = QHBoxLayout()
        self._quality = QSlider(Qt.Orientation.Horizontal)
        self._quality.setRange(1, 100)
        self._quality.setValue(DEFAULT_QUALITY)
        self._quality.setAccessibleName("Kalite")
        self._quality.valueChanged.connect(lambda v: self._quality_label.setText(f"%{v}"))
        self._quality_label = QLabel(f"%{DEFAULT_QUALITY}")
        self._quality_label.setObjectName("QualityValue")
        qual_row.addWidget(self._quality, stretch=1)
        qual_row.addWidget(self._quality_label)
        lay.addLayout(qual_row)

        self._codec_panel = QWidget()
        self._codec_panel.setObjectName("CodecPanel")
        cp = QVBoxLayout(self._codec_panel)
        cp.setContentsMargins(12, 12, 12, 12)
        cp.setSpacing(10)
        self._codec_title = QLabel("Codec ayarları")
        self._codec_title.setObjectName("FieldLabel")
        cp.addWidget(self._codec_title)

        self._webp_lossless = QCheckBox("WebP kayıpsız")
        self._webp_method = self._slider_row("WebP method", 0, 6, 4)
        self._jpeg_progressive = QCheckBox("JPEG progressive")
        self._jpeg_progressive.setChecked(True)
        self._jpeg_optimize = QCheckBox("JPEG optimize")
        self._jpeg_optimize.setChecked(True)
        self._jpeg_sub = QComboBox()
        self._jpeg_sub.setAccessibleName("JPEG subsampling")
        self._jpeg_sub.addItem("Subsampling: otomatik", -1)
        self._jpeg_sub.addItem("4:4:4 (en iyi)", 0)
        self._jpeg_sub.addItem("4:2:0 (küçük dosya)", 2)
        self._png_compress = self._slider_row("PNG sıkıştırma", 0, 9, 6)
        self._png_optimize = QCheckBox("PNG optimize")
        self._png_optimize.setChecked(True)

        for w in (
            self._webp_lossless, self._webp_method[0], self._jpeg_progressive,
            self._jpeg_optimize, self._jpeg_sub, self._png_compress[0], self._png_optimize,
        ):
            cp.addWidget(w)
        lay.addWidget(self._codec_panel)

        lay.addWidget(self._field_label("Genel"))
        self._exif_rotate = QCheckBox("EXIF otomatik döndür")
        self._exif_rotate.setChecked(True)
        self._strip_meta = QCheckBox("Metadata temizle (EXIF/GPS)")
        self._grayscale = QCheckBox("Gri ton")
        self._strip_meta.setToolTip("Kapalıyken EXIF (GPS dahil) çıktıya kopyalanır; renk profili her zaman korunur.")
        self._preserve_tree = QCheckBox("Klasör yapısını koru")
        self._overwrite = QCheckBox("Aynı adlı dosyaların üzerine yaz")
        self._overwrite.setToolTip(
            "Kapalıyken çakışan dosyalar \"ad (1).uzantı\" olarak kaydedilir; hiçbir dosya ezilmez."
        )
        for w in (self._exif_rotate, self._strip_meta, self._grayscale, self._preserve_tree, self._overwrite):
            lay.addWidget(w)

        lay.addWidget(self._field_label("Çıktı Klasörü"))
        folder_row = QHBoxLayout()
        folder_row.setSpacing(6)
        self._out_edit = QLineEdit(self._output_dir)
        self._out_edit.setReadOnly(True)
        pick = QPushButton("…")
        pick.setObjectName("FolderBtn")
        pick.setToolTip("Klasör seç")
        pick.setAccessibleName("Çıktı klasörü seç")
        self._out_edit.setAccessibleName("Çıktı klasörü")
        pick.clicked.connect(self._pick_output)
        folder_row.addWidget(self._out_edit, stretch=1)
        folder_row.addWidget(pick)
        lay.addLayout(folder_row)

        lay.addStretch()
        self._convert_btn = QPushButton("Dosya ekleyin")
        self._convert_btn.setObjectName("ConvertBtn")
        self._convert_btn.clicked.connect(self._start_convert)
        lay.addWidget(self._convert_btn)

        scroll.setWidget(inner)
        outer = QVBoxLayout(side)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.addWidget(scroll)
        return side

    def _preset_row(
        self, presets, default, handler, store: list[QPushButton], name: str
    ) -> QHBoxLayout:
        row = QHBoxLayout()
        row.setSpacing(6)
        for value, label in presets:
            btn = QPushButton(label)
            btn.setObjectName("PresetBtn")
            btn.setCheckable(True)
            btn.setProperty("presetValue", value)
            btn.setAccessibleName(f"{name} {label}")
            btn.clicked.connect(lambda _c, v=value: handler(v))
            if value == default:
                btn.setChecked(True)
            store.append(btn)
            row.addWidget(btn)
        return row

    def _slider_row(self, label: str, lo: int, hi: int, val: int) -> tuple[QWidget, QSlider, QLabel]:
        wrap = QWidget()
        lay = QHBoxLayout(wrap)
        lay.setContentsMargins(0, 0, 0, 0)
        lbl = QLabel(label)
        lbl.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 11px; min-width: 90px;")
        slider = QSlider(Qt.Orientation.Horizontal)
        slider.setRange(lo, hi)
        slider.setValue(val)
        slider.setAccessibleName(label)
        val_lbl = QLabel(str(val))
        val_lbl.setObjectName("QualityValue")
        slider.valueChanged.connect(lambda v: val_lbl.setText(str(v)))
        lay.addWidget(lbl)
        lay.addWidget(slider, stretch=1)
        lay.addWidget(val_lbl)
        return wrap, slider, val_lbl

    def _build_main(self) -> QFrame:
        panel = QFrame()
        panel.setObjectName("MainPanel")
        lay = QVBoxLayout(panel)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(0)

        toolbar = QFrame()
        toolbar.setObjectName("Toolbar")
        tlay = QHBoxLayout(toolbar)
        tlay.setContentsMargins(16, 14, 18, 14)
        tlay.setSpacing(10)

        self._search = QLineEdit()
        self._search.setPlaceholderText("Dosya adına göre ara…")
        self._search.setAccessibleName("Kuyrukta ara")
        self._search.setClearButtonEnabled(True)
        self._search.textChanged.connect(self._render_queue)
        tlay.addWidget(self._search, stretch=1)

        self._file_count = QLabel("0 dosya")
        self._file_count.setObjectName("FileCount")
        tlay.addWidget(self._file_count)

        for label, slot in (
            ("Hataları tekrarla", self._retry_errors),
            ("Tamamlananları sil", self._remove_done),
            ("Kuyruğu temizle", self._clear_queue),
        ):
            btn = QPushButton(label)
            btn.setObjectName("SecondaryBtn")
            btn.clicked.connect(slot)
            tlay.addWidget(btn)

        add_btn = QPushButton("+ Ekle")
        add_btn.setObjectName("SecondaryBtn")
        add_btn.setToolTip("Görsel dosyası ekle (Ctrl+O)")
        add_btn.clicked.connect(self._add_files)
        self._add_btn = add_btn
        tlay.addWidget(add_btn)
        # Klasör yalnızca sürükle-bırakla eklenebiliyordu
        folder_btn = QPushButton("+ Klasör")
        folder_btn.setObjectName("SecondaryBtn")
        folder_btn.setToolTip("Klasördeki tüm görselleri alt klasörlerle ekle (Ctrl+Shift+O)")
        folder_btn.clicked.connect(self._add_folder)
        self._add_folder_btn = folder_btn
        tlay.addWidget(folder_btn)
        lay.addWidget(toolbar)

        self._drop = DropZone()
        self._drop.activated.connect(self._add_files)
        self._drop.paths_dropped.connect(self._add_paths)
        lay.addWidget(self._drop)

        self._scroll = QScrollArea()
        self._scroll.setWidgetResizable(True)
        self._queue_host = QWidget()
        self._queue_lay = QVBoxLayout(self._queue_host)
        self._queue_lay.setContentsMargins(18, 4, 18, 18)
        self._queue_lay.setSpacing(4)
        self._queue_lay.addStretch()
        self._scroll.setWidget(self._queue_host)
        lay.addWidget(self._scroll, stretch=1)

        batch = QFrame()
        batch.setObjectName("BatchBar")
        blay = QVBoxLayout(batch)
        blay.setContentsMargins(16, 10, 16, 10)
        top = QHBoxLayout()
        self._batch_label = QLabel("Dönüştürülüyor… 0 / 0")
        self._batch_label.setStyleSheet(f"color: {TEXT_PRIMARY}; font-size: 12px; font-weight: 500;")
        self._batch_eta = QLabel("")
        self._batch_eta.setStyleSheet(f"color: {TEXT_MUTED}; font-size: 11px; font-family: Cascadia Mono, Consolas, monospace;")
        top.addWidget(self._batch_label)
        top.addStretch()
        top.addWidget(self._batch_eta)
        blay.addLayout(top)
        self._batch_bar = QProgressBar()
        self._batch_bar.setObjectName("BatchProgress")
        self._batch_bar.setTextVisible(False)
        blay.addWidget(self._batch_bar)
        cancel = QPushButton("■ İptal")
        cancel.setObjectName("CancelBtn")
        cancel.clicked.connect(self._cancel_convert)
        self._cancel_btn = cancel
        actions = QHBoxLayout()
        actions.addStretch()
        actions.addWidget(cancel)
        blay.addLayout(actions)
        self._batch_frame = batch
        self._batch_frame.setVisible(False)
        lay.addWidget(batch)
        return panel

    def _build_statusbar(self) -> None:
        bar = QStatusBar()
        self.setStatusBar(bar)
        for text in ("Ctrl+Enter başlat", "Esc iptal", "Del kaldır"):
            lbl = QLabel(text.replace(" ", "  "))
            lbl.setObjectName("KbdHint")
            bar.addWidget(lbl)
        self._status_msg = QLabel("Hazır")
        self._status_msg.setObjectName("StatusMsg")
        bar.addPermanentWidget(self._status_msg, stretch=1)

    def _bind_shortcuts(self) -> None:
        QShortcut(QKeySequence("Ctrl+Return"), self, self._start_convert)
        QShortcut(QKeySequence("Ctrl+Enter"), self, self._start_convert)
        QShortcut(QKeySequence("Escape"), self, self._cancel_convert)
        QShortcut(QKeySequence("Delete"), self, self._remove_selected)
        QShortcut(QKeySequence("Ctrl+F"), self, lambda: self._search.setFocus())
        QShortcut(QKeySequence("Ctrl+O"), self, self._add_files)
        QShortcut(QKeySequence("Ctrl+Shift+O"), self, self._add_folder)

    @staticmethod
    def _field_label(text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setObjectName("FieldLabel")
        return lbl

    def _current_options(self) -> ConvertOptions:
        paths = [j.path for j in self._jobs]
        return ConvertOptions(
            fmt=self._fmt.currentText(),
            max_width=self._max_width,
            max_height=self._max_height,
            quality=self._quality.value(),
            exif_rotate=self._exif_rotate.isChecked(),
            strip_metadata=self._strip_meta.isChecked(),
            grayscale=self._grayscale.isChecked(),
            jpeg_progressive=self._jpeg_progressive.isChecked(),
            jpeg_optimize=self._jpeg_optimize.isChecked(),
            jpeg_subsampling=int(self._jpeg_sub.currentData()),
            webp_method=self._webp_method[1].value(),
            webp_lossless=self._webp_lossless.isChecked(),
            png_compress=self._png_compress[1].value(),
            png_optimize=self._png_optimize.isChecked(),
            preserve_tree=self._preserve_tree.isChecked(),
            source_root=common_root(paths),
            overwrite=self._overwrite.isChecked(),
        )

    def _apply_settings(self, data: dict) -> None:
        """Kayıtlı ayarları pencereye uygular; bilinmeyen/bozuk değerler yok sayılır."""
        defaults = ConvertOptions()
        o = {k: data.get(k, v) for k, v in asdict(defaults).items()}
        try:
            if o["fmt"] in FORMATS:
                self._fmt.setCurrentText(o["fmt"])
            self._set_width(int(o["max_width"]))
            self._set_height(int(o["max_height"]))
            self._quality.setValue(int(o["quality"]))
            for box, key in (
                (self._exif_rotate, "exif_rotate"), (self._strip_meta, "strip_metadata"),
                (self._grayscale, "grayscale"), (self._preserve_tree, "preserve_tree"),
                (self._overwrite, "overwrite"), (self._webp_lossless, "webp_lossless"),
                (self._jpeg_progressive, "jpeg_progressive"), (self._jpeg_optimize, "jpeg_optimize"),
                (self._png_optimize, "png_optimize"),
            ):
                box.setChecked(bool(o[key]))
            self._webp_method[1].setValue(int(o["webp_method"]))
            self._png_compress[1].setValue(int(o["png_compress"]))
            idx = self._jpeg_sub.findData(int(o["jpeg_subsampling"]))
            if idx >= 0:
                self._jpeg_sub.setCurrentIndex(idx)
        except (TypeError, ValueError):
            pass
        out = data.get("output_dir")
        if isinstance(out, str) and out.strip():
            self._output_dir = out
            self._out_edit.setText(out)

    def _settings_dict(self) -> dict:
        data = asdict(self._current_options())
        data.pop("source_root", None)
        data["output_dir"] = self._output_dir
        return data

    def _set_width(self, value: int) -> None:
        if self._batch_running:
            return
        self._max_width = value
        for btn in self._width_btn_list:
            btn.setChecked(btn.property("presetValue") == value)
        self._refresh_job_meta()

    def _set_height(self, value: int) -> None:
        if self._batch_running:
            return
        self._max_height = value
        for btn in self._height_btn_list:
            btn.setChecked(btn.property("presetValue") == value)
        self._refresh_job_meta()

    def _on_format_changed(self) -> None:
        self._sync_codec_panel()
        self._refresh_job_meta()

    def _sync_codec_panel(self) -> None:
        fmt = self._fmt.currentText()
        lossy = fmt in ("jpeg", "webp", "avif") and not (
            fmt == "webp" and self._webp_lossless.isChecked()
        )
        self._quality.setEnabled(lossy and not self._batch_running)
        self._quality_label.setText("—" if not lossy else f"%{self._quality.value()}")

        for w, show in (
            (self._webp_lossless, fmt == "webp"),
            (self._webp_method[0], fmt == "webp"),
            (self._jpeg_progressive, fmt == "jpeg"),
            (self._jpeg_optimize, fmt == "jpeg"),
            (self._jpeg_sub, fmt == "jpeg"),
            (self._png_compress[0], fmt == "png"),
            (self._png_optimize, fmt == "png"),
        ):
            w.setVisible(show)
        self._codec_title.setText(
            {"webp": "WebP", "jpeg": "JPEG", "png": "PNG", "avif": "AVIF"}.get(fmt, fmt)
            + " codec"
        )

    def _refresh_job_meta(self) -> None:
        opts = self._current_options()
        for job in self._jobs:
            if job.status in ("pending", "cancelled", "error"):
                try:
                    job.meta = format_meta(job.path, opts).replace(
                        f" · {opts.fmt.upper()}", " · bekliyor"
                    )
                except OSError:
                    job.meta = "okunamadı"
        self._render_queue()

    def _filtered_jobs(self) -> list[tuple[int, Job]]:
        q = self._search.text().strip().lower()
        return [(i, j) for i, j in enumerate(self._jobs) if not q or Path(j.path).name.lower().find(q) >= 0]

    def _render_queue(self) -> None:
        while self._queue_lay.count() > 1:
            item = self._queue_lay.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        total = len(self._jobs)
        visible = self._filtered_jobs()
        if total == 0:
            self._file_count.setText("0 dosya")
            self._drop.setVisible(True)
            self._scroll.setVisible(False)
            return
        self._drop.setVisible(False)
        self._scroll.setVisible(True)
        suffix = f" ({len(visible)} gösteriliyor)" if len(visible) != total else ""
        self._file_count.setText(f"{total} dosya{suffix}")
        if not visible:
            empty = QLabel("Sonuç bulunamadı")
            empty.setAlignment(Qt.AlignmentFlag.AlignCenter)
            empty.setStyleSheet(f"color: {TEXT_MUTED}; padding: 48px; background: transparent;")
            self._queue_lay.insertWidget(0, empty)
            return
        for idx, (orig_i, job) in enumerate(visible):
            row = JobRow(job, orig_i, orig_i == self._selected)
            row.clicked.connect(self._select_job)
            self._queue_lay.insertWidget(idx, row)

    def _select_job(self, index: int) -> None:
        self._selected = index
        if 0 <= index < len(self._jobs):
            self._status_msg.setText(f"Seçili: {Path(self._jobs[index].path).name}")
        self._render_queue()

    def _remove_selected(self) -> None:
        if self._batch_running or not (0 <= self._selected < len(self._jobs)):
            return
        job = self._jobs[self._selected]
        if job.status == "processing":
            return
        name = Path(job.path).name
        del self._jobs[self._selected]
        self._selected = min(self._selected, len(self._jobs) - 1) if self._jobs else -1
        self._sync_ui()
        self._status_msg.setText(f"Kaldırıldı: {name}")

    def _retry_errors(self) -> None:
        if self._batch_running:
            return
        n = 0
        for job in self._jobs:
            if job.status == "error":
                job.status = "pending"
                job.error = ""
                n += 1
        if n:
            self._refresh_job_meta()
            self._sync_ui()
            self._status_msg.setText(f"{n} hatalı dosya kuyruğa alındı")

    def _remove_done(self) -> None:
        if self._batch_running:
            return
        before = len(self._jobs)
        self._jobs = [j for j in self._jobs if j.status != "done"]
        removed = before - len(self._jobs)
        self._selected = -1
        self._sync_ui()
        if removed:
            self._status_msg.setText(f"{removed} tamamlanan dosya silindi")

    def _clear_queue(self) -> None:
        if self._batch_running:
            return
        if not self._jobs:
            return
        if QMessageBox.question(self, "Kuyruk", "Tüm dosyalar kuyruktan kaldırılsın mı?") != QMessageBox.StandardButton.Yes:
            return
        self._jobs.clear()
        self._selected = -1
        self._sync_ui()
        self._status_msg.setText("Kuyruk temizlendi")

    def _add_paths(self, paths: list[str]) -> None:
        new_files = collect_images(paths)
        existing = {j.path for j in self._jobs}
        opts = self._current_options()
        added = 0
        for path in new_files:
            if path in existing:
                continue
            try:
                meta = format_meta(path, opts).replace(f" · {opts.fmt.upper()}", " · bekliyor")
            except OSError:
                meta = "okunamadı"
            self._jobs.append(Job(path=path, meta=meta))
            existing.add(path)
            added += 1
        if added:
            self._status_msg.setText(f"{added} dosya eklendi")
        elif new_files:
            self._status_msg.setText("Seçilen görseller zaten kuyrukta")
        else:
            self._status_msg.setText("Desteklenen görsel bulunamadı")
        self._sync_ui()

    def _add_files(self) -> None:
        if self._batch_running:
            return
        files, _ = QFileDialog.getOpenFileNames(
            self, "Görsel ekle", "",
            "Görseller (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.tiff *.tif *.avif *.heic);;Tümü (*.*)",
        )
        if files:
            self._add_paths(files)

    def _add_folder(self) -> None:
        if self._batch_running:
            return
        folder = QFileDialog.getExistingDirectory(self, "Klasör ekle")
        if folder:
            self._add_paths([folder])

    def _pick_output(self) -> None:
        if self._batch_running:
            return
        folder = QFileDialog.getExistingDirectory(self, "Çıktı klasörü", self._output_dir)
        if folder:
            self._output_dir = folder
            self._out_edit.setText(folder)

    def dragEnterEvent(self, event: QDragEnterEvent) -> None:
        if event.mimeData().hasUrls():
            event.acceptProposedAction()

    def dropEvent(self, event: QDropEvent) -> None:
        paths = [url.toLocalFile() for url in event.mimeData().urls() if url.toLocalFile()]
        if paths and not self._batch_running:
            self._add_paths(paths)
        event.acceptProposedAction()

    def _pending_indices(self) -> list[int]:
        return [i for i, j in enumerate(self._jobs) if j.status in ("pending", "error", "cancelled")]

    def _set_batch_controls_enabled(self, enabled: bool) -> None:
        self._fmt.setEnabled(enabled)
        self._add_btn.setEnabled(enabled)
        self._add_folder_btn.setEnabled(enabled)
        for btn in self._width_btn_list + self._height_btn_list:
            btn.setEnabled(enabled)
        for w in (
            self._exif_rotate, self._strip_meta, self._grayscale, self._preserve_tree,
            self._overwrite, self._webp_lossless, self._jpeg_progressive, self._jpeg_optimize, self._jpeg_sub,
            self._png_optimize,
        ):
            w.setEnabled(enabled)
        for slider in (self._quality, self._webp_method[1], self._png_compress[1]):
            slider.setEnabled(enabled)
        self._sync_codec_panel()

    def _sync_ui(self) -> None:
        count = len(self._jobs)
        pending = len(self._pending_indices())
        self._convert_btn.setEnabled(count > 0 and pending > 0 and not self._batch_running)
        self._convert_btn.setProperty("running", self._batch_running)
        self._convert_btn.style().unpolish(self._convert_btn)
        self._convert_btn.style().polish(self._convert_btn)
        self._convert_btn.setText(
            "Dönüştürülüyor…" if self._batch_running
            else "Dosya ekleyin" if count == 0
            else f"{pending} Dosyayı Dönüştür"
        )
        self._set_batch_controls_enabled(not self._batch_running)
        self._render_queue()

    def _start_convert(self) -> None:
        if self._batch_running:
            return
        indices = self._pending_indices()
        if not indices:
            return
        out = self._output_dir.strip()
        if not out:
            self._status_msg.setText("Çıktı klasörü seçin")
            return
        try:
            Path(out).mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            self._status_msg.setText(f"Çıktı klasörü oluşturulamadı: {exc}")
            return

        opts = self._current_options()
        sources = [self._jobs[i].path for i in indices]
        if opts.overwrite:
            hits = [s for s in sources if os.path.normcase(str(target_path(Path(s), Path(out), opts)))
                    == os.path.normcase(s)]
            if hits and QMessageBox.question(
                self, "Orijinallerin üzerine yazılacak",
                f"{len(hits)} orijinal dosya, dönüştürülmüş haliyle değiştirilecek ve geri alınamaz.\n"
                "Devam edilsin mi?",
            ) != QMessageBox.StandardButton.Yes:
                return
        index_map = {src: i for i, src in zip(indices, sources)}

        self._batch_running = True
        self._batch_start = time.monotonic()
        self._batch_frame.setVisible(True)
        self._batch_bar.setMaximum(len(sources))
        self._batch_bar.setValue(0)
        self._batch_label.setText(f"Dönüştürülüyor… 0 / {len(sources)}")
        self._sync_ui()

        for i in indices:
            self._jobs[i].status = "pending"
            self._jobs[i].error = ""

        self._worker = ConvertWorker(sources, out, opts, self)

        def on_file(idx: int, dest: str, err: str) -> None:
            job = self._jobs[index_map[sources[idx]]]
            if err:
                job.status = "error"
                job.error = job.meta = err
            else:
                job.status = "done"
                try:
                    job.meta = format_meta(job.path, opts)
                except OSError:
                    job.meta = Path(dest).name

        self._worker.file_done.connect(on_file)

        def on_progress(cur: int, tot: int) -> None:
            self._batch_bar.setValue(cur)
            self._batch_label.setText(f"Dönüştürülüyor… {cur} / {tot}")
            if 0 < cur < tot:
                eta = int((time.monotonic() - self._batch_start) / cur * (tot - cur))
                self._batch_eta.setText(f"~{eta} sn kaldı" if eta > 0 else "Tamamlanıyor…")
            # cur. dosya bitti (file_done önce geldi); sıradaki dosyayı "işleniyor" yap
            if cur < len(sources):
                self._jobs[index_map[sources[cur]]].status = "processing"
            self._render_queue()

        self._worker.progress.connect(on_progress)
        self._worker.finished_ok.connect(self._on_done)
        self._worker.finished_cancelled.connect(self._on_cancelled)
        self._worker.start()
        self._status_msg.setText("Dönüştürülüyor…")

    def _finish_batch(self) -> None:
        self._batch_running = False
        self._batch_frame.setVisible(False)
        self._worker = None
        self._sync_ui()

    def _on_done(self, converted: int, errors: int) -> None:
        self._finish_batch()
        msg = f"Batch tamamlandı — {converted} dosya"
        if errors:
            msg += f", {errors} hata"
        self._status_msg.setText(msg)

    def _on_cancelled(self, completed: int) -> None:
        for job in self._jobs:
            if job.status in ("pending", "processing"):
                job.status = "cancelled"
                job.meta = "iptal edildi"
        self._finish_batch()
        self._status_msg.setText(f"Batch iptal edildi — {completed} dosya tamamlandı")

    def _cancel_convert(self) -> None:
        if not self._worker or not self._worker.isRunning():
            return
        if QMessageBox.question(
            self, "İptal",
            "Dönüştürmeyi iptal etmek istiyor musunuz? Kısmi çıktılar korunur.",
        ) != QMessageBox.StandardButton.Yes:
            return
        # Soru açıkken toplu iş bitmiş olabilir (_worker None olur)
        if not self._worker or not self._worker.isRunning():
            return
        self._worker.cancel()
        self._status_msg.setText("İptal isteniyor…")

    def closeEvent(self, event) -> None:
        # Çalışan QThread yok edilirse uygulama çöker; önce iptal edip bitmesini bekle
        if self._worker and self._worker.isRunning():
            self._worker.cancel()
            self._worker.wait()
        save_settings(self._settings_dict())
        super().closeEvent(event)
