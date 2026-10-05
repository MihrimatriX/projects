from __future__ import annotations

from copy import deepcopy

from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QCheckBox,
    QComboBox,
    QFrame,
    QGridLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QScrollArea,
    QSizePolicy,
    QSpinBox,
    QVBoxLayout,
    QWidget,
)

from core.models import CaseMode, ExifNamingMode, Rule, RuleType
from core.presets import PRESETS
from ui.theme import FONT_MONO, PANEL_WIDTH

RULE_TYPE_LABELS = [
    "Bul / Değiştir",
    "Numaralandır",
    "Büyük / küçük harf",
    "Uzantı değiştir",
    "EXIF tarih",
]

PRESET_LABELS: dict[str, str] = {
    "Fotoğraf tarihi (EXIF)": "Fotoğraf Tarihi",
    "EXIF + mtime birleşik": "EXIF + Tarih",
    "Türkçe karakter düzelt": "Türkçe Karakter",
    "Sıra numarası": "Sıra Numarası",
    "Boşluk → alt çizgi": "Boşluk → _",
}


class RuleCard(QFrame):
    changed = Signal()
    remove_requested = Signal(object)
    move_up_requested = Signal(object)
    move_down_requested = Signal(object)

    def __init__(self, rule: Rule, index: int) -> None:
        super().__init__()
        self.rule = rule
        self._index = index
        self.setObjectName("RuleCard")
        self._build()

    def _build(self) -> None:
        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(6)

        header = QHBoxLayout()
        header.setSpacing(8)
        drag = QLabel("⋮⋮")
        drag.setObjectName("DragHandle")
        drag.setToolTip("Sırayı ↑ / ↓ düğmeleriyle değiştirin")
        drag.setFixedWidth(14)
        self.title = QLabel(f"{self._index + 1} · {self.rule.label()}")
        self.title.setObjectName("RuleTypeLabel")
        self.title.setWordWrap(True)
        self.enable_cb = QCheckBox()
        self.enable_cb.setChecked(self.rule.enabled)
        self.enable_cb.setToolTip("Kural aktif")
        self.enable_cb.setAccessibleName("Kural aktif")
        self.enable_cb.toggled.connect(self._on_enable)
        up_btn = QPushButton("↑")
        up_btn.setObjectName("SmallButton")
        up_btn.setToolTip("Yukarı taşı")
        up_btn.setAccessibleName("Kuralı yukarı taşı")
        up_btn.clicked.connect(lambda: self.move_up_requested.emit(self))
        down_btn = QPushButton("↓")
        down_btn.setObjectName("SmallButton")
        down_btn.setToolTip("Aşağı taşı")
        down_btn.setAccessibleName("Kuralı aşağı taşı")
        down_btn.clicked.connect(lambda: self.move_down_requested.emit(self))
        remove_btn = QPushButton("✕")
        remove_btn.setObjectName("SmallButton")
        remove_btn.setToolTip("Kuralı kaldır")
        remove_btn.setAccessibleName("Kuralı kaldır")
        self.up_btn, self.down_btn, self.remove_btn = up_btn, down_btn, remove_btn
        remove_btn.clicked.connect(lambda: self.remove_requested.emit(self))
        header.addWidget(drag, 0, Qt.AlignmentFlag.AlignTop)
        header.addWidget(self.title, stretch=1)
        header.addWidget(self.enable_cb, 0, Qt.AlignmentFlag.AlignTop)
        header.addWidget(up_btn, 0, Qt.AlignmentFlag.AlignTop)
        header.addWidget(down_btn, 0, Qt.AlignmentFlag.AlignTop)
        header.addWidget(remove_btn, 0, Qt.AlignmentFlag.AlignTop)
        layout.addLayout(header)

        type_lbl = QLabel("Tip")
        type_lbl.setObjectName("FieldLabel")
        layout.addWidget(type_lbl)
        self.type_combo = QComboBox()
        self.type_combo.addItems(RULE_TYPE_LABELS)
        self.type_combo.setAccessibleName("Kural tipi")
        self.type_combo.setCurrentIndex(list(RuleType).index(self.rule.rule_type))
        self.type_combo.currentIndexChanged.connect(self._on_type_changed)
        layout.addWidget(self.type_combo)

        cond_lbl = QLabel("Yalnızca şu uzantılar:")
        cond_lbl.setObjectName("FieldLabel")
        layout.addWidget(cond_lbl)
        self.condition_edit = QLineEdit(self.rule.condition_ext)
        self.condition_edit.setPlaceholderText("jpg,png (boş = hepsi)")
        self.condition_edit.setAccessibleName("Koşul uzantıları")
        self.condition_edit.textChanged.connect(lambda t: self._set("condition_ext", t))
        layout.addWidget(self.condition_edit)

        self.fields = QWidget()
        self.fields_layout = QVBoxLayout(self.fields)
        self.fields_layout.setContentsMargins(0, 0, 0, 0)
        self.fields_layout.setSpacing(6)
        layout.addWidget(self.fields)

        self.error_label = QLabel("")
        self.error_label.setObjectName("FieldError")
        self.error_label.setWordWrap(True)
        self.error_label.hide()
        layout.addWidget(self.error_label)

        self._rebuild_fields()
        self._on_enable(self.rule.enabled)
        self._fit_combos()

    def _mono_font(self) -> QFont:
        return QFont(FONT_MONO, 10)

    def _on_enable(self, checked: bool) -> None:
        self.rule.enabled = checked
        self.setProperty("active", "true" if checked else "false")
        self.style().unpolish(self)
        self.style().polish(self)
        self.changed.emit()

    def _on_type_changed(self, index: int) -> None:
        self.rule.rule_type = list(RuleType)[index]
        self.title.setText(f"{self._index + 1} · {self.rule.label()}")
        self._rebuild_fields()
        self._fit_combos()
        self.changed.emit()

    def _rebuild_fields(self) -> None:
        while self.fields_layout.count():
            item = self.fields_layout.takeAt(0)
            if item.widget():
                item.widget().hide()  # deleteLater'a kadar eski alanlar üst üste çizilmesin
                item.widget().deleteLater()

        if self.rule.rule_type == RuleType.FIND_REPLACE:
            self._add_line("Ara", "pattern", self.rule.pattern, mono=True)
            self._add_line("Değiştir", "replacement", self.rule.replacement, mono=True)
            self.regex_cb = QCheckBox("Regex kullan")
            self.regex_cb.setChecked(self.rule.use_regex)
            self.regex_cb.toggled.connect(self._toggle_regex)
            self.fields_layout.addWidget(self.regex_cb)
            self.case_cb = QCheckBox("Büyük/küçük harf duyarsız")
            self.case_cb.setChecked(self.rule.ignore_case)
            self.case_cb.toggled.connect(self._on_ignore_case)
            self.fields_layout.addWidget(self.case_cb)
        elif self.rule.rule_type == RuleType.NUMBERING:
            lbl = QLabel("Mod")
            lbl.setObjectName("FieldLabel")
            self.fields_layout.addWidget(lbl)
            pos = QComboBox()
            pos.addItems(["Başa ekle: 001_", "Sona ekle: _001"])
            pos.setAccessibleName("Numara konumu")
            pos.setCurrentIndex(0 if self.rule.number_position == "prefix" else 1)
            pos.currentIndexChanged.connect(
                lambda i: self._set("number_position", "prefix" if i == 0 else "suffix")
            )
            self.fields_layout.addWidget(pos)
            row = QGridLayout()
            row.setContentsMargins(0, 0, 0, 0)
            start = QSpinBox()
            start.setRange(0, 999999)
            start.setValue(self.rule.start)
            start.setAccessibleName("Başlangıç numarası")
            start.valueChanged.connect(lambda v: self._set("start", v))
            pad = QSpinBox()
            pad.setRange(1, 8)
            pad.setValue(self.rule.pad)
            pad.setAccessibleName("Hane sayısı")
            pad.valueChanged.connect(lambda v: self._set("pad", v))
            # Etiketler üstte (2x2): tek satır kartı panelden geniş yapıp düğmeleri kırpıyordu.
            row.addWidget(QLabel("Başlangıç"), 0, 0)
            row.addWidget(QLabel("Hane"), 0, 1)
            row.addWidget(start, 1, 0)
            row.addWidget(pad, 1, 1)
            wrap = QWidget()
            wrap.setLayout(row)
            self.fields_layout.addWidget(wrap)
        elif self.rule.rule_type == RuleType.CASE:
            lbl = QLabel("Mod")
            lbl.setObjectName("FieldLabel")
            self.fields_layout.addWidget(lbl)
            mode = QComboBox()
            mode.addItems(["küçük harf", "BÜYÜK HARF", "Başlık", "İlk harf büyük"])
            mode.setAccessibleName("Harf modu")
            mode.setCurrentIndex(list(CaseMode).index(self.rule.case_mode))
            mode.currentIndexChanged.connect(
                lambda i: self._set("case_mode", list(CaseMode)[i])
            )
            self.fields_layout.addWidget(mode)
        elif self.rule.rule_type == RuleType.EXTENSION:
            self._add_line("Eski uzantı", "old_ext", self.rule.old_ext)
            self._add_line("Yeni uzantı", "new_ext", self.rule.new_ext)
        elif self.rule.rule_type == RuleType.EXIF_DATE:
            lbl = QLabel("Mod")
            lbl.setObjectName("FieldLabel")
            self.fields_layout.addWidget(lbl)
            mode = QComboBox()
            # Sıra ExifNamingMode ile aynı; ham enum adları yerine anlaşılır metin.
            mode.addItems(
                [
                    "EXIF, yoksa değiştirme tarihi",
                    "Yalnızca EXIF",
                    "Yalnızca değiştirme tarihi",
                    "EXIF + değiştirme tarihi",
                ]
            )
            mode.setAccessibleName("EXIF ad modu")
            mode.setCurrentIndex(list(ExifNamingMode).index(self.rule.exif_naming_mode))
            mode.currentIndexChanged.connect(
                lambda i: self._set("exif_naming_mode", list(ExifNamingMode)[i])
            )
            self.fields_layout.addWidget(mode)
            self._add_line("EXIF format", "exif_format", self.rule.exif_format, mono=True)
            self._add_line("Değiştirme tarihi formatı", "mtime_format", self.rule.mtime_format, mono=True)
            self._add_line("Ayırıcı", "exif_mtime_separator", self.rule.exif_mtime_separator)
            keep = QCheckBox("Orijinal uzantıyı koru")
            keep.setChecked(self.rule.keep_original_ext)
            keep.toggled.connect(lambda v: self._set("keep_original_ext", v))
            self.fields_layout.addWidget(keep)

    def _fit_combos(self) -> None:
        # Combo'lar en uzun öğe kadar genişliyor, kart panelden taşıp ↓ / ✕ düğmeleri
        # görünmez oluyordu; kısa minimum genişlik + açılır listede tam metin.
        for combo in self.findChildren(QComboBox):
            combo.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
            combo.setMinimumContentsLength(8)

    def _add_line(
        self, label: str, attr: str, value: str, *, mono: bool = False
    ) -> None:
        lbl = QLabel(label)
        lbl.setObjectName("FieldLabel")
        self.fields_layout.addWidget(lbl)
        edit = QLineEdit(value)
        edit.setAccessibleName(label)
        lbl.setBuddy(edit)
        if mono:
            edit.setFont(self._mono_font())
        edit.textChanged.connect(lambda t, a=attr: self._set(a, t))
        self.fields_layout.addWidget(edit)

    def _toggle_regex(self, checked: bool) -> None:
        self._set("use_regex", checked)
        self.changed.emit()

    def _on_ignore_case(self, checked: bool) -> None:
        self.rule.ignore_case = checked
        self.changed.emit()

    def _set(self, attr: str, value) -> None:
        setattr(self.rule, attr, value)
        if attr == "condition_ext":
            self.title.setText(f"{self._index + 1} · {self.rule.label()}")
        self.changed.emit()

    def set_index(self, index: int) -> None:
        self._index = index
        self.title.setText(f"{index + 1} · {self.rule.label()}")

    def show_regex_error(self, message: str | None) -> None:
        has_error = bool(message)
        self.setProperty("error", "true" if has_error else "false")
        self.style().unpolish(self)
        self.style().polish(self)
        if message:
            self.error_label.setText(message)
            self.error_label.show()
        else:
            self.error_label.hide()


class RulesPanel(QFrame):
    rules_changed = Signal()

    def __init__(self) -> None:
        super().__init__()
        self.setObjectName("RulesPanel")
        self.setMinimumWidth(320)
        self.setMaximumWidth(400)
        self.resize(PANEL_WIDTH, self.height())
        self.rules: list[Rule] = [
            Rule(
                rule_type=RuleType.FIND_REPLACE,
                pattern="",
                replacement="",
                use_regex=False,
            )
        ]
        self._cards: list[RuleCard] = []
        self._build()

    def _build(self) -> None:
        outer = QVBoxLayout(self)
        outer.setContentsMargins(16, 16, 16, 16)
        outer.setSpacing(12)

        title = QLabel("KURAL ZİNCİRİ")
        title.setObjectName("SectionTitle")
        outer.addWidget(title)

        scroll = QScrollArea()
        scroll.setObjectName("RulesScroll")
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFrameShape(QFrame.Shape.NoFrame)

        self._cards_host = QWidget()
        self._cards_host.setSizePolicy(
            QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Minimum
        )
        self._cards_layout = QVBoxLayout(self._cards_host)
        self._cards_layout.setContentsMargins(0, 0, 4, 0)
        self._cards_layout.setSpacing(8)
        self._cards_layout.addStretch()
        scroll.setWidget(self._cards_host)
        outer.addWidget(scroll, stretch=1)

        add_btn = QPushButton("+ Kural Ekle")
        self.add_btn = add_btn
        add_btn.setObjectName("GhostButton")
        add_btn.clicked.connect(self._add_rule)
        outer.addWidget(add_btn)

        preset_title = QLabel("PRESET GALERİSİ")
        preset_title.setObjectName("SectionTitle")
        outer.addWidget(preset_title)

        chips = QWidget()
        grid = QGridLayout(chips)
        grid.setContentsMargins(0, 0, 0, 0)
        grid.setHorizontalSpacing(6)
        grid.setVerticalSpacing(6)
        names = list(PRESETS.keys())
        for i, name in enumerate(names):
            label = PRESET_LABELS.get(name, name)
            btn = QPushButton(label)
            btn.setObjectName("ChipButton")
            btn.setToolTip(f"Hazır kural seti: {name} (mevcut kuralların yerine geçer)")
            btn.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
            btn.clicked.connect(lambda _=False, n=name: self._apply_preset(n))
            grid.addWidget(btn, i // 2, i % 2)
        outer.addWidget(chips)

        self._rebuild_cards()

    def _rebuild_cards(self) -> None:
        while self._cards_layout.count() > 1:
            item = self._cards_layout.takeAt(0)
            if item.widget():
                item.widget().hide()
                item.widget().deleteLater()
        self._cards.clear()

        for i, rule in enumerate(self.rules):
            card = RuleCard(rule, i)
            card.changed.connect(self.rules_changed.emit)
            card.remove_requested.connect(self._remove_card)
            card.move_up_requested.connect(self._move_up)
            card.move_down_requested.connect(self._move_down)
            self._cards.append(card)
            self._cards_layout.insertWidget(i, card)

    def _card_index(self, card: RuleCard) -> int:
        # Kimlikle ara: aynı alanlara sahip iki kural (ör. iki boş kural) eşit sayılıyor,
        # list.index yanlış kartı taşıyor/siliyordu.
        return next((i for i, r in enumerate(self.rules) if r is card.rule), -1)

    def _move_up(self, card: RuleCard) -> None:
        idx = self._card_index(card)
        if idx <= 0:
            return
        self.rules[idx - 1], self.rules[idx] = self.rules[idx], self.rules[idx - 1]
        self._rebuild_cards()
        self.rules_changed.emit()

    def _move_down(self, card: RuleCard) -> None:
        idx = self._card_index(card)
        if idx < 0 or idx >= len(self.rules) - 1:
            return
        self.rules[idx + 1], self.rules[idx] = self.rules[idx], self.rules[idx + 1]
        self._rebuild_cards()
        self.rules_changed.emit()

    def _add_rule(self) -> None:
        self.rules.append(Rule())
        self._rebuild_cards()
        self.rules_changed.emit()

    def _remove_card(self, card: RuleCard) -> None:
        if len(self.rules) <= 1:
            return
        idx = self._card_index(card)
        if idx >= 0:
            del self.rules[idx]
        self._rebuild_cards()
        self.rules_changed.emit()

    def _apply_preset(self, name: str) -> None:
        self.rules = deepcopy(PRESETS.get(name, []))
        if not self.rules:
            self.rules = [Rule()]
        self._rebuild_cards()
        self.rules_changed.emit()

    def set_rules(self, rules: list[Rule]) -> None:
        self.rules = rules or [Rule()]
        self._rebuild_cards()
