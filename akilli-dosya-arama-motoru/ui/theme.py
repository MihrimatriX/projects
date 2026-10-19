"""Tasarım token'ları — design/css/tokens.css ile birebir."""

BG_APP = "#0a0c10"
BG_PANEL = "#12151a"
BG_ELEVATED = "#1a1e24"
BG_HOVER = "#1a1e24"
BG_SELECTED = "rgba(69, 184, 106, 0.15)"
BG_INPUT = "#1a1e24"
BORDER = "#2a2f38"
TEXT_PRIMARY = "#f2f4f7"
TEXT_SECONDARY = "#d0d4dc"
TEXT_MUTED = "#949aa6"
ACCENT = "#45b86a"
ACCENT_HOVER = "#58c97d"
ACCENT_DIM = "rgba(69, 184, 106, 0.15)"
ACCENT_TEXT = "#0a120e"
SUCCESS = "#45b86a"
WARNING = "#d4a843"
DANGER = "#d94545"
OVERLAY_SCRIM = "rgba(26, 29, 36, 0.72)"
WIN_TITLEBAR = "#1a1e24"
WIN_BORDER = "#2a2f38"

PANEL_WIDTH = 640
SETTINGS_WIDTH = 560
PANEL_RADIUS = 12
RADIUS_MD = 8
RADIUS_SM = 4
ROW_HEIGHT = 52
RESULTS_MAX_HEIGHT = 520
RESULTS_MIN_HEIGHT = 360

FONT_UI = '"Segoe UI", "Segoe UI Variable Text", sans-serif'
FONT_DISPLAY = '"Segoe UI", "Segoe UI Variable Display", sans-serif'
FONT_MONO = '"Cascadia Mono", "Consolas", monospace'

PANEL_SHADOW_BLUR = 48
PANEL_SHADOW_OFFSET_Y = 20
PANEL_SHADOW_ALPHA = 160

TRAY_MENU_STYLESHEET = f"""
QMenu {{
    background: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
    padding: 4px 0;
}}
QMenu::item {{
    padding: 10px 14px;
    color: {TEXT_SECONDARY};
    font-size: 13px;
}}
QMenu::item:selected {{
    background: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}
QMenu::item:disabled {{
    color: {TEXT_MUTED};
    background: transparent;
}}
QMenu::separator {{
    height: 1px;
    background: {BORDER};
    margin: 2px 0;
}}
"""

BASE_STYLESHEET = f"""
QWidget {{
    background-color: transparent;
    color: {TEXT_SECONDARY};
    font-family: {FONT_UI};
    font-size: 13px;
}}
QLabel {{
    background: transparent;
}}
QLineEdit {{
    background: transparent;
    color: {TEXT_PRIMARY};
    border: none;
    selection-background-color: {ACCENT};
    selection-color: {ACCENT_TEXT};
}}
QToolButton {{
    background: transparent;
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    color: {TEXT_MUTED};
    padding: 4px;
}}
QToolButton:hover {{
    background: {BG_ELEVATED};
    color: {ACCENT};
}}
QToolButton:pressed {{
    background: {BORDER};
}}
QCheckBox {{
    spacing: 8px;
    color: {TEXT_SECONDARY};
}}
QCheckBox::indicator {{
    width: 18px;
    height: 18px;
    border-radius: {RADIUS_SM}px;
    border: 1px solid {BORDER};
    background: {BG_INPUT};
}}
QCheckBox::indicator:hover {{
    border-color: {ACCENT};
}}
QCheckBox::indicator:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}
QCheckBox::indicator:focus {{
    border: 2px solid {TEXT_PRIMARY};
}}
QSpinBox {{
    background: {BG_INPUT};
    color: {TEXT_SECONDARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 4px 8px;
    min-height: 24px;
}}
QSpinBox:focus {{
    border-color: {ACCENT};
}}
QSpinBox::up-button, QSpinBox::down-button {{
    width: 18px;
    border: none;
    background: transparent;
}}
QSpinBox::up-button:hover, QSpinBox::down-button:hover {{
    background: {BG_HOVER};
}}
"""

APP_STYLESHEET = f"""
QMainWindow {{
    background-color: {BG_APP};
}}
QScrollArea {{
    background: transparent;
    border: none;
}}
QScrollArea > QWidget > QWidget {{
    background: transparent;
}}
QScrollBar:vertical {{
    background: transparent;
    width: 8px;
    margin: 0;
}}
QScrollBar::handle:vertical {{
    background: {BORDER};
    border-radius: 4px;
    min-height: 24px;
}}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
    height: 0;
    border: none;
    background: none;
}}
QDialog {{
    background: {BG_APP};
    color: {TEXT_SECONDARY};
}}
"""

PANEL_STYLESHEET = f"""
QFrame#SearchPanel {{
    background: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: {PANEL_RADIUS}px;
}}
QFrame#ResultRow {{
    border: none;
}}
"""

GLOBAL_STYLESHEET = APP_STYLESHEET + BASE_STYLESHEET + PANEL_STYLESHEET

SETTINGS_DIALOG_STYLESHEET = f"""
QDialog#SettingsDialog {{
    background: {BG_APP};
    border: 1px solid {WIN_BORDER};
}}
"""

SETTINGS_STYLESHEET = f"""
QFrame#Section {{
    background: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: {PANEL_RADIUS}px;
}}
QLabel#SectionTitle {{
    color: {TEXT_MUTED};
    font-size: 12px;
    font-weight: 600;
    padding: 12px 16px;
    border-bottom: 1px solid {BORDER};
    background: transparent;
    letter-spacing: 0.06em;
}}
QPushButton#Primary {{
    background: {ACCENT};
    color: {ACCENT_TEXT};
    border: none;
    border-radius: {RADIUS_MD}px;
    padding: 7px 14px;
    font-weight: 600;
}}
QPushButton#Primary:hover {{
    background: {ACCENT_HOVER};
}}
QPushButton#Primary:disabled {{
    background: rgba(69, 184, 106, 0.35);
    color: rgba(10, 18, 14, 0.55);
}}
QPushButton#Secondary {{
    background: {BG_ELEVATED};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
    padding: 7px 14px;
}}
QPushButton#Secondary:hover {{
    background: {BORDER};
}}
QPushButton#AddFolder {{
    background: transparent;
    color: {ACCENT};
    border: 1px dashed {BORDER};
    border-radius: {RADIUS_MD}px;
    padding: 8px 14px;
}}
QPushButton#AddFolder:hover {{
    background: {BG_HOVER};
    border-color: {ACCENT};
}}
QPushButton#RemoveFolder {{
    background: {BG_ELEVATED};
    color: {TEXT_MUTED};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_SM}px;
    padding: 5px 10px;
    font-size: 12px;
}}
QPushButton#RemoveFolder:hover {{
    color: {DANGER};
    border-color: rgba(217, 69, 69, 0.35);
    background: rgba(217, 69, 69, 0.12);
}}
QTextEdit#ExcludePatterns {{
    background: {BG_INPUT};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_MD}px;
    padding: 8px 12px;
    font-family: {FONT_MONO};
    font-size: 12px;
}}
QTextEdit#ExcludePatterns:focus {{
    border-color: {ACCENT};
}}
QProgressBar {{
    background: {BORDER};
    border: none;
    border-radius: 2px;
    height: 3px;
}}
QProgressBar::chunk {{
    background: {ACCENT};
    border-radius: 2px;
}}
"""