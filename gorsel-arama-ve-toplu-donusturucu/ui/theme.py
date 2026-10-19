"""Yumuşak koyu tema — düşük kontrast, geniş radius, hafif tipografi."""
from __future__ import annotations

BG_APP = "#121820"
BG_PANEL = "#1a2230"
BG_LIST = "#161d28"
BG_DROP = "#141b26"
BG_HOVER = "rgba(148, 163, 184, 0.09)"
BG_SELECTED = "rgba(96, 165, 250, 0.14)"
BG_ERROR = "rgba(248, 113, 113, 0.08)"
BG_PROGRESS = "#243044"
BG_INPUT = "#1c2533"
BG_THUMB = "#2d3a4d"
BORDER = "rgba(148, 163, 184, 0.14)"
BORDER_DROP = "rgba(148, 163, 184, 0.22)"
TEXT_PRIMARY = "#e8edf4"
TEXT_SECONDARY = "#a8b4c4"
TEXT_MUTED = "#7a8799"
ACCENT = "#eab676"
ACCENT_HOVER = "#dfaa62"
ACCENT_SOFT = "rgba(234, 182, 118, 0.14)"
ACCENT_ON = "#1a1510"
SUCCESS = "#6ee7b7"
ERROR = "#fca5a5"
WARNING = "#fcd34d"
PROCESSING = "#93c5fd"

RADIUS_LG = 14
RADIUS_MD = 10
RADIUS_SM = 7
PROGRESS_HEIGHT = 5

FONT_UI = '"Segoe UI Variable", "Segoe UI", system-ui, sans-serif'
FONT_MONO = '"Cascadia Mono", "Consolas", ui-monospace, monospace'

APP_STYLE = f"""
* {{
    font-family: {FONT_UI};
    font-size: 13px;
}}

QMainWindow, QWidget#CentralWidget {{
    background-color: {BG_APP};
    color: {TEXT_SECONDARY};
}}

QFrame#Sidebar {{
    background-color: {BG_PANEL};
    border-right: 1px solid {BORDER};
}}

QFrame#MainPanel {{
    background-color: {BG_LIST};
}}

QFrame#Toolbar {{
    background-color: {BG_LIST};
    border-bottom: 1px solid {BORDER};
}}

QFrame#BatchBar {{
    background-color: {BG_PANEL};
    border-top: 1px solid {BORDER};
}}

QLabel {{
    background: transparent;
}}

QLabel#SidebarTitle {{
    color: {TEXT_PRIMARY};
    font-size: 14px;
    font-weight: 500;
    letter-spacing: -0.01em;
}}

QLabel#FieldLabel {{
    color: {TEXT_MUTED};
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.02em;
}}

QLabel#QualityValue {{
    color: {TEXT_PRIMARY};
    font-family: {FONT_MONO};
    font-size: 12px;
    font-weight: 500;
    min-width: 36px;
}}

QLabel#FileCount {{
    color: {TEXT_MUTED};
    font-size: 12px;
}}

QLabel#StatusMsg {{
    color: {TEXT_SECONDARY};
    font-weight: 500;
}}

QLabel#KbdHint {{
    color: {TEXT_MUTED};
    font-size: 11px;
}}

QLineEdit, QComboBox {{
    background-color: {BG_INPUT};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 8px 12px;
    min-height: 24px;
    selection-background-color: {BG_SELECTED};
}}

QLineEdit:focus, QComboBox:focus {{
    border-color: rgba(234, 182, 118, 0.55);
    background-color: #1e2836;
}}

QLineEdit:disabled, QComboBox:disabled {{
    color: {TEXT_MUTED};
    background-color: {BG_DROP};
}}

QComboBox::drop-down {{
    border: none;
    width: 26px;
}}

QComboBox QAbstractItemView {{
    background-color: {BG_PANEL};
    color: {TEXT_PRIMARY};
    selection-background-color: {BG_SELECTED};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 4px;
    outline: none;
}}

QSlider::groove:horizontal {{
    background: {BG_PROGRESS};
    height: 5px;
    border-radius: 3px;
}}

QSlider::handle:horizontal {{
    background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
        stop:0 #f0c88a, stop:1 {ACCENT});
    width: 16px;
    height: 16px;
    margin: -6px 0;
    border-radius: 8px;
    border: 2px solid {BG_PANEL};
}}

QSlider:disabled::handle:horizontal {{
    background: {TEXT_MUTED};
    border-color: {BG_DROP};
}}

QPushButton#ConvertBtn {{
    background-color: {ACCENT};
    color: {ACCENT_ON};
    border: none;
    border-radius: {RADIUS_MD}px;
    padding: 11px 18px;
    font-weight: 500;
    font-size: 13px;
    min-height: 42px;
}}

QPushButton#ConvertBtn:hover:!disabled {{
    background-color: {ACCENT_HOVER};
}}

QPushButton#ConvertBtn:disabled {{
    background-color: rgba(234, 182, 118, 0.35);
    color: rgba(26, 21, 16, 0.55);
}}

QPushButton#ConvertBtn[running="true"] {{
    background-color: rgba(234, 182, 118, 0.55);
    color: {TEXT_PRIMARY};
}}

QPushButton#PresetBtn {{
    background-color: {BG_INPUT};
    color: {TEXT_SECONDARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 7px 11px;
    font-size: 12px;
    font-weight: 500;
    min-height: 34px;
}}

QPushButton#PresetBtn:hover:!disabled {{
    background-color: rgba(148, 163, 184, 0.1);
    color: {TEXT_PRIMARY};
    border-color: rgba(148, 163, 184, 0.22);
}}

QPushButton#PresetBtn:checked {{
    color: {ACCENT};
    border-color: rgba(234, 182, 118, 0.45);
    background-color: {ACCENT_SOFT};
}}

QPushButton#PresetBtn:disabled {{
    opacity: 0.45;
}}

QPushButton#SecondaryBtn {{
    background: rgba(148, 163, 184, 0.04);
    color: {TEXT_SECONDARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 7px 13px;
    font-size: 12px;
    font-weight: 500;
}}

QPushButton#SecondaryBtn:hover:!disabled {{
    background-color: rgba(148, 163, 184, 0.1);
    color: {TEXT_PRIMARY};
    border-color: rgba(148, 163, 184, 0.22);
}}

QPushButton#SecondaryBtn:disabled {{
    opacity: 0.45;
}}

QPushButton#FolderBtn {{
    background-color: {BG_INPUT};
    color: {TEXT_MUTED};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    min-width: 38px;
    max-width: 38px;
    min-height: 38px;
    max-height: 38px;
    padding: 0;
    font-size: 14px;
}}

QPushButton#FolderBtn:hover:!disabled {{
    background-color: rgba(148, 163, 184, 0.1);
    color: {TEXT_PRIMARY};
}}

QPushButton#CancelBtn {{
    background: rgba(148, 163, 184, 0.04);
    color: {TEXT_SECONDARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 7px 14px;
    font-size: 11px;
    font-weight: 500;
}}

QPushButton#CancelBtn:hover {{
    border-color: rgba(252, 165, 165, 0.45);
    color: {ERROR};
    background: rgba(252, 165, 165, 0.08);
}}

QFrame#DropZone {{
    background: {BG_DROP};
    border: 2px dashed {BORDER_DROP};
    border-radius: {RADIUS_LG}px;
    margin: 4px 0;
}}

QFrame#DropZone[dragOver="true"] {{
    border-color: rgba(234, 182, 118, 0.45);
    background: {ACCENT_SOFT};
}}

QScrollArea {{
    background: transparent;
    border: none;
}}

QScrollBar:vertical {{
    background: transparent;
    width: 10px;
    margin: 4px 2px;
}}

QScrollBar::handle:vertical {{
    background: rgba(148, 163, 184, 0.22);
    border-radius: 5px;
    min-height: 32px;
}}

QScrollBar::handle:vertical:hover {{
    background: rgba(148, 163, 184, 0.32);
}}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
    height: 0;
}}

QProgressBar#BatchProgress {{
    background: {BG_PROGRESS};
    border: none;
    border-radius: 3px;
    min-height: {PROGRESS_HEIGHT}px;
    max-height: {PROGRESS_HEIGHT}px;
}}

QProgressBar#BatchProgress::chunk {{
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
        stop:0 {ACCENT_HOVER}, stop:1 {ACCENT});
    border-radius: 3px;
}}

QStatusBar {{
    color: {TEXT_MUTED};
    background: {BG_APP};
    border-top: 1px solid {BORDER};
    font-size: 11px;
    padding: 2px 8px;
}}

QCheckBox {{
    color: {TEXT_SECONDARY};
    spacing: 10px;
    font-size: 12px;
}}

QCheckBox::indicator {{
    width: 18px;
    height: 18px;
    border-radius: 5px;
    border: 1px solid {BORDER};
    background: {BG_INPUT};
}}

QCheckBox::indicator:hover {{
    border-color: rgba(148, 163, 184, 0.28);
}}

QCheckBox::indicator:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}

QCheckBox:disabled {{
    color: {TEXT_MUTED};
}}

QWidget#CodecPanel {{
    background: rgba(148, 163, 184, 0.04);
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
}}

/* Klavye odağı görünür olsun (stil sayfası varsayılan odak çerçevesini siliyordu) */
QPushButton:focus, QFrame#DropZone:focus {{
    border: 1px solid rgba(234, 182, 118, 0.75);
}}
QCheckBox:focus {{
    color: {TEXT_PRIMARY};
}}
QCheckBox::indicator:focus, QSlider::handle:horizontal:focus {{
    border-color: {ACCENT};
}}
"""

BADGE_STYLES = {
    "pending": "background: rgba(122, 135, 153, 0.18); color: #9aa8b8;",
    "processing": "background: rgba(147, 197, 253, 0.16); color: #93c5fd;",
    "done": "background: rgba(110, 231, 183, 0.14); color: #6ee7b7;",
    "error": "background: rgba(252, 165, 165, 0.14); color: #fca5a5;",
    "cancelled": "background: rgba(252, 211, 77, 0.14); color: #fcd34d;",
}

BADGE_LABELS = {
    "pending": "Bekliyor",
    "processing": "İşleniyor",
    "done": "Tamam",
    "error": "Hata",
    "cancelled": "İptal",
}
