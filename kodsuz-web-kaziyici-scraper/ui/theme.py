"""Design tokens — design/index.html CSS variables."""

BG_APP = "#111827"
BG_PANEL = "#1f2937"
BG_INPUT = "#374151"
BG_TABLE_HEADER = "#1f2937"
BG_TABLE_ROW_ALT = "#1a2332"
BG_HOVER = "#374151"
BG_STEP_ACTIVE = "#1e3a5f"
BORDER = "#374151"
BORDER_FOCUS = "#3b82f6"
TEXT_PRIMARY = "#f9fafb"
TEXT_SECONDARY = "#9ca3af"
TEXT_MUTED = "#6b7280"
ACCENT = "#3b82f6"
ACCENT_HOVER = "#2563eb"
ACCENT_PRESSED = "#1d4ed8"
ACCENT_TEXT = "#ffffff"
SUCCESS = "#10b981"
WARNING = "#f59e0b"
WARNING_BG = "#fef3c7"
WARNING_TEXT = "#92400e"
DANGER = "#ef4444"
CANVAS = "#0a0e14"

SIDEBAR_WIDTH = 360
TOOLBAR_HEIGHT = 48
FORM_PADDING = 16
RADIUS_MD = 8
RADIUS_INPUT = 6
TABLE_ROW_HEIGHT = 36

FONT_UI = '"Inter", "Segoe UI", system-ui, sans-serif'
FONT_MONO = '"JetBrains Mono", Consolas, ui-monospace, monospace'

APP_STYLE = f"""
* {{
    font-family: {FONT_UI};
    font-size: 13px;
}}

QMainWindow, QWidget#AppRoot {{
    background-color: {CANVAS};
    color: {TEXT_SECONDARY};
}}

QLabel {{
    background: transparent;
}}

QLabel[class="primary"] {{
    color: {TEXT_PRIMARY};
}}

QLabel[class="muted"] {{
    color: {TEXT_MUTED};
    font-size: 11px;
}}

QLabel[class="section"] {{
    color: {TEXT_PRIMARY};
    font-size: 14px;
    font-weight: 600;
}}

QLineEdit, QSpinBox, QDoubleSpinBox {{
    background-color: {BG_INPUT};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_INPUT}px;
    padding: 6px 10px;
    min-height: 24px;
}}

QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus {{
    border-color: {BORDER_FOCUS};
}}

QLineEdit:disabled {{
    opacity: 0.55;
}}

QLineEdit[invalid="true"] {{
    border-color: {DANGER};
}}

QLineEdit[mono="true"] {{
    font-family: {FONT_MONO};
    font-size: 12px;
}}

QComboBox {{
    background-color: {BG_INPUT};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_INPUT}px;
    padding: 6px 10px;
    min-height: 24px;
}}

QComboBox::drop-down {{
    border: none;
    width: 24px;
}}

QComboBox QAbstractItemView {{
    background-color: {BG_PANEL};
    color: {TEXT_PRIMARY};
    selection-background-color: {BG_STEP_ACTIVE};
    border: 1px solid {BORDER};
}}

QPushButton {{
    background-color: transparent;
    color: {TEXT_SECONDARY};
    border: 1px solid {BORDER};
    border-radius: {RADIUS_INPUT}px;
    padding: 6px 12px;
    font-weight: 500;
}}

QPushButton:hover {{
    background-color: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}

QPushButton:disabled {{
    opacity: 0.5;
}}

QPushButton[class="primary"] {{
    background-color: {ACCENT};
    color: {ACCENT_TEXT};
    border: none;
    font-weight: 600;
}}

QPushButton[class="primary"]:hover {{
    background-color: {ACCENT_HOVER};
}}

QPushButton[class="primary"]:pressed {{
    background-color: {ACCENT_PRESSED};
}}

QPushButton[class="primary"]:disabled {{
    background-color: {BG_HOVER};
    color: {TEXT_MUTED};
}}

QPushButton[class="ghost"] {{
    background: transparent;
}}

QPushButton[class="icon"] {{
    min-width: 32px;
    max-width: 32px;
    min-height: 32px;
    max-height: 32px;
    padding: 0;
}}

QPushButton[class="tab"] {{
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    color: {TEXT_MUTED};
    font-size: 12px;
    font-weight: 500;
    padding: 8px 0;
}}

QPushButton[class="tab"]:checked {{
    color: {TEXT_PRIMARY};
    border-bottom-color: {ACCENT};
}}

QPushButton[class="chip"] {{
    border-radius: 999px;
    font-size: 11px;
    padding: 4px 10px;
}}

QPushButton[class="chip"]:checked {{
    background-color: {BG_STEP_ACTIVE};
    border-color: rgba(59, 130, 246, 0.35);
    color: {TEXT_PRIMARY};
}}

QPushButton[class="mode"] {{
    border: none;
    border-radius: 4px;
    font-size: 11px;
    min-height: 44px;
}}

QPushButton[class="mode"]:checked {{
    background-color: {BG_STEP_ACTIVE};
    color: {TEXT_PRIMARY};
}}

QPushButton[class="run"] {{
    background-color: {ACCENT};
    color: {ACCENT_TEXT};
    border: none;
    border-radius: {RADIUS_MD}px;
    font-weight: 600;
    min-height: 40px;
}}

QPushButton[class="run"]:hover {{
    background-color: {ACCENT_HOVER};
}}

QPushButton[class="run"]:disabled {{
    background-color: {BG_HOVER};
    color: {TEXT_MUTED};
}}

QFrame#Shell {{
    background-color: {BG_APP};
    border: 1px solid {BORDER};
    border-radius: 10px;
}}

QFrame#Toolbar, QFrame#ResultsToolbar, QFrame#StatusBar, QFrame#Sidebar {{
    background-color: {BG_PANEL};
}}

QFrame#Sidebar {{
    border-right: 1px solid {BORDER};
}}

QFrame#RobotsBanner {{
    background-color: {WARNING_BG};
    border-bottom: 1px solid rgba(146, 64, 14, 0.15);
}}

QLabel#RobotsText {{
    color: {WARNING_TEXT};
    font-size: 12px;
    font-weight: 500;
}}

QPushButton#RobotsAccept {{
    background-color: {WARNING_TEXT};
    color: {WARNING_BG};
    border: none;
    font-weight: 500;
}}

QFrame#TrustChip {{
    background-color: rgba(16, 185, 129, 0.1);
    border: 1px solid rgba(16, 185, 129, 0.22);
    border-radius: 999px;
}}

QFrame#TrustChip[state="warn"] {{
    background-color: rgba(245, 158, 11, 0.1);
    border-color: rgba(245, 158, 11, 0.25);
}}

QFrame#TrustChip[state="blocked"] {{
    background-color: rgba(239, 68, 68, 0.1);
    border-color: rgba(239, 68, 68, 0.25);
}}

QFrame#ActionZone {{
    background-color: rgba(59, 130, 246, 0.035);
    border-top: 1px solid rgba(59, 130, 246, 0.1);
}}

QFrame#ModeSegment {{
    background-color: {BG_INPUT};
    border-radius: {RADIUS_INPUT}px;
}}

QTableWidget {{
    background-color: {BG_APP};
    color: {TEXT_PRIMARY};
    border: none;
    gridline-color: {BORDER};
    alternate-background-color: {BG_TABLE_ROW_ALT};
}}

QHeaderView::section {{
    background-color: {BG_TABLE_HEADER};
    color: {TEXT_MUTED};
    border: none;
    border-bottom: 1px solid {BORDER};
    padding: 8px 10px;
    font-weight: 600;
    font-size: 12px;
}}

QTableWidget::item:selected {{
    background-color: rgba(59, 130, 246, 0.12);
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

QProgressBar {{
    background: {BG_INPUT};
    border: none;
    border-radius: 2px;
    max-height: 4px;
}}

QProgressBar::chunk {{
    background: {ACCENT};
    border-radius: 2px;
}}

QDialog {{
    background-color: {BG_PANEL};
}}

QCheckBox {{
    spacing: 6px;
    color: {TEXT_SECONDARY};
}}

QCheckBox::indicator {{
    width: 14px;
    height: 14px;
    border: 1px solid {BORDER};
    border-radius: 3px;
    background: {BG_INPUT};
}}

QCheckBox::indicator:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}
"""
