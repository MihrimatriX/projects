"""Design tokens — design/brand-spec.md + metadata-temizleyici-prototype.html."""

BG_APP = "#0f1419"
BG_PANEL = "#1a2332"
BG_DROP = "#15202b"
BG_INPUT = "#243447"
BG_HOVER = "#243447"
BG_SIDEBAR = "#161d27"
BG_SELECTED = "rgba(30, 155, 240, 0.15)"
BORDER = "#38444d"
TEXT_PRIMARY = "#e7e9ea"
TEXT_SECONDARY = "#8b98a5"
TEXT_MUTED = "#6e767d"
TEXT_SUBTLE = "#7a8694"
ACCENT = "#1e9bf0"
ACCENT_HOVER = "#1a8cd8"
ACCENT_TEXT = "#0a1628"
ACCENT_SOFT = "rgba(30, 155, 240, 0.08)"
ACCENT_SOFT_DRAG = "rgba(30, 155, 240, 0.12)"
SUCCESS = "#00ba7c"
WARNING = "#ffad20"
DANGER = "#f4212e"
DANGER_BG = "rgba(244, 33, 46, 0.14)"
SUCCESS_BG = "rgba(0, 186, 124, 0.14)"
WARNING_BG = "rgba(255, 173, 32, 0.14)"

PANEL_RADIUS = 12
INPUT_RADIUS = 8

FONT_UI = '"Inter", "Segoe UI", system-ui, sans-serif'
FONT_MONO = '"JetBrains Mono", "Consolas", ui-monospace, monospace'

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
    background-color: {BG_SIDEBAR};
    border-right: 1px solid {BORDER};
}}

QLabel#AppTitle {{
    font-size: 18px;
    font-weight: 600;
    color: {TEXT_PRIMARY};
}}

QLabel#AppSubtitle {{
    font-size: 12px;
    color: {TEXT_MUTED};
}}

QLabel#ViewTitle {{
    font-size: 18px;
    font-weight: 600;
    color: {TEXT_PRIMARY};
}}

QLabel#ViewDescription {{
    font-size: 12px;
    color: {TEXT_MUTED};
}}

QLabel#PanelTitle {{
    font-size: 16px;
    font-weight: 600;
    color: {TEXT_PRIMARY};
}}

QLabel#PanelSubtitle {{
    font-size: 12px;
    color: {TEXT_MUTED};
}}

QLabel#FileName {{
    font-family: {FONT_MONO};
    font-size: 12px;
    color: {ACCENT};
}}

QLabel#Pill {{
    padding: 5px 9px;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 600;
    color: {TEXT_MUTED};
    background: {BG_DROP};
    border: 1px solid {BORDER};
}}

QLabel#PillSuccess {{
    padding: 5px 9px;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 600;
    color: {SUCCESS};
    background: {SUCCESS_BG};
    border: 1px solid rgba(0, 186, 124, 0.38);
}}

QLabel#PillWarn {{
    padding: 5px 9px;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 600;
    color: {WARNING};
    background: {WARNING_BG};
    border: 1px solid rgba(255, 173, 32, 0.35);
}}

QFrame#TitleBar, QFrame#Panel, QFrame#SideCard {{
    background-color: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: {PANEL_RADIUS}px;
}}

QFrame#DropZone {{
    background-color: {BG_DROP};
    border: 2px dashed {BORDER};
    border-radius: {PANEL_RADIUS}px;
}}

QFrame#DropZone[dragOver="true"] {{
    border-color: {ACCENT};
    background-color: {ACCENT_SOFT_DRAG};
}}

QFrame#DropZone:hover {{
    border-color: {ACCENT};
    background-color: {ACCENT_SOFT};
}}

QLabel#DropTitle {{
    color: {TEXT_PRIMARY};
    font-size: 17px;
    font-weight: 600;
}}

QLabel#DropHint {{
    color: {TEXT_SUBTLE};
    font-size: 12px;
}}

QFrame#FolderStrip, QFrame#StateNote {{
    background-color: {BG_DROP};
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
}}

QPushButton#NavButton {{
    min-height: 44px;
    text-align: left;
    padding: 0 12px;
    border: none;
    border-radius: {INPUT_RADIUS}px;
    color: {TEXT_MUTED};
    font-weight: 550;
    background: transparent;
}}

QPushButton#NavButton:hover {{
    background: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}

QPushButton#NavButton:checked {{
    background: {BG_INPUT};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
}}

QPushButton#ChipButton {{
    min-height: 36px;
    padding: 0 12px;
    border-radius: 999px;
    color: {TEXT_MUTED};
    background: {BG_DROP};
    border: 1px solid {BORDER};
    font-weight: 550;
}}

QPushButton#ChipButton:hover {{
    color: {TEXT_PRIMARY};
    background: {BG_INPUT};
}}

QPushButton#ChipButton:checked {{
    color: {TEXT_PRIMARY};
    border-color: {ACCENT};
    background: rgba(30, 155, 240, 0.1);
}}

QPushButton {{
    min-height: 40px;
    padding: 0 14px;
    border-radius: {INPUT_RADIUS}px;
    color: {TEXT_SECONDARY};
    background: transparent;
    border: 1px solid {BORDER};
    font-weight: 600;
}}

QPushButton:hover {{
    background: {BG_INPUT};
    color: {TEXT_PRIMARY};
}}

QPushButton#PrimaryButton {{
    min-height: 44px;
    background: {ACCENT};
    color: {ACCENT_TEXT};
    border: none;
}}

QPushButton#PrimaryButton:hover {{
    background: {ACCENT_HOVER};
}}

QPushButton#PrimaryButton:disabled {{
    background: {BG_INPUT};
    color: {TEXT_MUTED};
}}

QPushButton#SecondaryButton {{
    color: {TEXT_PRIMARY};
    background: {BG_INPUT};
}}

QPushButton#GhostButton {{
    background: transparent;
}}

QTableWidget#MetadataTable, QTableWidget#BatchTable {{
    background: {BG_DROP};
    border: 1px solid {BORDER};
    border-radius: {PANEL_RADIUS}px;
    gridline-color: {BORDER};
    color: {TEXT_PRIMARY};
    selection-background-color: {BG_SELECTED};
}}

QTableWidget#MetadataTable::item, QTableWidget#BatchTable::item {{
    padding: 6px 10px;
    height: 40px;
}}

QHeaderView::section {{
    background: {BG_PANEL};
    color: {TEXT_MUTED};
    border: none;
    border-bottom: 1px solid {BORDER};
    padding: 8px 12px;
    font-size: 11px;
    font-weight: 600;
}}

QLineEdit#SearchInput {{
    min-height: 36px;
    padding: 0 11px;
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
    color: {TEXT_PRIMARY};
    background: {BG_INPUT};
}}

QCheckBox {{
    color: {TEXT_SECONDARY};
    spacing: 9px;
    font-weight: 550;
}}

QCheckBox::indicator {{
    width: 16px;
    height: 16px;
    border-radius: 4px;
    border: 1px solid {BORDER};
    background: {BG_DROP};
}}

QCheckBox::indicator:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}

QCheckBox#ToggleSwitch::indicator {{
    width: 42px;
    height: 24px;
    border-radius: 12px;
    background: {BG_INPUT};
    border: 1px solid {BORDER};
}}

QCheckBox#ToggleSwitch::indicator:checked {{
    background: rgba(0, 186, 124, 0.14);
    border-color: rgba(0, 186, 124, 0.4);
}}

QProgressBar {{
    background: {BG_INPUT};
    border: none;
    border-radius: 999px;
    min-height: 8px;
    max-height: 8px;
    text-visible: false;
}}

QProgressBar::chunk {{
    background: {ACCENT};
    border-radius: 999px;
}}

QTextEdit#QueueLog, QPlainTextEdit#AuditPreview {{
    background: {BG_DROP};
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
    color: {TEXT_PRIMARY};
    font-family: {FONT_MONO};
    font-size: 11px;
}}

QFrame#QueueItem {{
    background: {BG_DROP};
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
}}

QStatusBar {{
    color: {TEXT_MUTED};
    background: {BG_APP};
}}

QScrollBar:vertical {{
    background: {BG_DROP};
    width: 10px;
    border-radius: 5px;
}}

QScrollBar::handle:vertical {{
    background: {BORDER};
    border-radius: 5px;
    min-height: 24px;
}}

QScrollArea {{
    border: none;
    background: transparent;
}}

QMessageBox {{
    background: {BG_PANEL};
}}

QMessageBox QLabel {{
    color: {TEXT_PRIMARY};
}}

QComboBox {{
    background: {BG_DROP};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
    padding: 8px 12px;
}}
"""
