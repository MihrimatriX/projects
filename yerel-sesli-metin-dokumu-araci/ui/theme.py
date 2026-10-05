"""Design tokens + Qt stylesheet."""

BG_APP = "#0c0c0e"
BG_PANEL = "#161618"
BG_ELEVATED = "#1e1e22"
BG_HOVER = "#2a2a30"
BORDER = "#2e2e36"
BORDER_FOCUS = "#6366f1"
TEXT_PRIMARY = "#f4f4f5"
TEXT_SECONDARY = "#a1a1aa"
TEXT_MUTED = "#71717a"
ACCENT = "#6366f1"
ACCENT_HOVER = "#5558e3"
SUCCESS = "#22c55e"
WARNING = "#eab308"
DANGER = "#ef4444"
WAVE_PLAYED = "#6366f1"
WAVE_UNPLAYED = "#3f3f46"
ONLINE_BANNER = "#422006"

PANEL_RADIUS = 12
INPUT_RADIUS = 8
BTN_HEIGHT = 40

APP_STYLE = f"""
* {{
    font-family: "Segoe UI", "Inter", system-ui, sans-serif;
    font-size: 13px;
}}

QMainWindow, QWidget#AppRoot {{
    background-color: {BG_APP};
    color: {TEXT_SECONDARY};
}}

QLabel {{
    color: {TEXT_PRIMARY};
    background: transparent;
}}

QLineEdit, QTextEdit, QPlainTextEdit, QScrollArea {{
    background-color: {BG_ELEVATED};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
}}

QLineEdit {{
    padding: 0 12px;
    min-height: 36px;
}}

QLineEdit:focus {{
    border-color: {BORDER_FOCUS};
}}

QPushButton {{
    background-color: transparent;
    color: {TEXT_SECONDARY};
    border: 1px solid {BORDER};
    border-radius: {INPUT_RADIUS}px;
    padding: 8px 16px;
    font-weight: 600;
    min-height: {BTN_HEIGHT}px;
}}

QPushButton:hover:!disabled {{
    background-color: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}

QPushButton:disabled {{
    opacity: 0.4;
}}

QPushButton#PrimaryBtn {{
    background-color: {ACCENT};
    border-color: {ACCENT};
    color: {TEXT_PRIMARY};
}}

QPushButton#PrimaryBtn:hover:!disabled {{
    background-color: {ACCENT_HOVER};
}}

QPushButton#ExportBtn {{
    min-height: 32px;
    padding: 0 12px;
    font-size: 13px;
}}

QPushButton#ExportBtnDone {{
    border-color: {SUCCESS};
    color: {SUCCESS};
}}

QPushButton#NavBtn {{
    border: none;
    min-height: 32px;
    padding: 6px 12px;
    font-weight: 500;
}}

QPushButton#NavBtn:checked {{
    background: {BG_ELEVATED};
    color: {TEXT_PRIMARY};
}}

QPushButton#IconBtn {{
    border: none;
    min-width: {BTN_HEIGHT}px;
    max-width: {BTN_HEIGHT}px;
    min-height: {BTN_HEIGHT}px;
    max-height: {BTN_HEIGHT}px;
    padding: 0;
}}

QPushButton#IconBtn:hover {{
    background: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}

QPushButton#TransportBtn {{
    border: none;
    min-width: 44px;
    max-width: 44px;
    min-height: 44px;
    max-height: 44px;
    border-radius: 22px;
    background: {BG_ELEVATED};
    padding: 0;
}}

QPushButton#TransportBtn:hover {{
    background: {BG_HOVER};
}}

QPushButton#TransportPrimary {{
    background: {ACCENT};
    color: {TEXT_PRIMARY};
}}

QPushButton#TransportPrimary:hover {{
    background: {ACCENT_HOVER};
}}

QPushButton#HistoryItem, QPushButton#JobItem {{
    text-align: left;
    border: 1px solid transparent;
    border-radius: {INPUT_RADIUS}px;
    padding: 10px 12px;
    min-height: 0;
    font-weight: normal;
}}

QPushButton#HistoryItem:checked, QPushButton#JobItem:checked {{
    border-color: {ACCENT};
    background: {BG_ELEVATED};
}}

QFrame#Toolbar, QFrame#Panel, QFrame#Sidebar, QFrame#TranscriptPanel {{
    background: {BG_PANEL};
    border: none;
}}

QFrame#Toolbar {{
    border-bottom: 1px solid {BORDER};
    min-height: 48px;
    max-height: 48px;
}}

QFrame#Sidebar {{
    border-right: 1px solid {BORDER};
}}

QFrame#TranscriptPanel {{
    border-left: 1px solid {BORDER};
}}

QFrame#OnlineBanner {{
    background: {ONLINE_BANNER};
    border-bottom: 1px solid rgba(234, 179, 8, 0.3);
}}

QFrame#FileBar, QFrame#SectionBorder {{
    border-bottom: 1px solid {BORDER};
    background: transparent;
}}

QProgressBar {{
    background: {BG_ELEVATED};
    border: none;
    border-radius: 4px;
    min-height: 8px;
    max-height: 8px;
}}

QProgressBar::chunk {{
    background: {ACCENT};
    border-radius: 4px;
}}

QProgressBar#Complete::chunk {{
    background: {SUCCESS};
}}

QScrollArea {{
    border: none;
    background: transparent;
}}

QScrollBar:vertical {{
    background: transparent;
    width: 8px;
}}

QScrollBar::handle:vertical {{
    background: {BORDER};
    border-radius: 4px;
    min-height: 24px;
}}

QStatusBar {{
    color: {TEXT_MUTED};
    background: {BG_APP};
}}

QLabel#Muted {{
    color: {TEXT_MUTED};
}}

QLabel#Secondary {{
    color: {TEXT_SECONDARY};
}}

QLabel#Mono {{
    font-family: "Cascadia Mono", "JetBrains Mono", Consolas, monospace;
    color: {TEXT_MUTED};
}}

QLabel#PhaseBadge {{
    font-family: "Cascadia Mono", Consolas, monospace;
    font-size: 10px;
    color: {WARNING};
    background: rgba(234, 179, 8, 0.12);
    padding: 4px 10px;
    border-radius: 4px;
}}
"""
