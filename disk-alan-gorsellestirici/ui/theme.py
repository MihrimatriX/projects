"""Design tokens — design/desktop-*.html CSS variables."""

BG_APP = "#0d1117"
BG_PANEL = "#161b22"
BG_HOVER = "#21262d"
BG_SELECTED = "#1f3a5f"
BORDER = "#30363d"
TEXT_PRIMARY = "#f0f6fc"
TEXT_SECONDARY = "#8b949e"
TEXT_MUTED = "#484f58"
ACCENT = "#58a6ff"
ACCENT_HOVER = "#79b8ff"
SUCCESS = "#3fb950"
WARNING = "#d29922"
DANGER = "#f85149"
DANGER_BG = "rgba(248, 81, 73, 0.14)"
DANGER_BORDER = "rgba(248, 81, 73, 0.45)"
DANGER_TEXT = "#ffb4af"

SEG_VIDEO = "#a371f7"
SEG_IMAGE = "#db61a2"
SEG_AUDIO = "#79c0ff"
SEG_CODE = "#58a6ff"
SEG_DOC = "#ffa657"
SEG_ARCHIVE = "#8b949e"
SEG_SYSTEM = "#6e7681"
SEG_CLOUD = "#39d353"
SEG_OTHER = "#484f58"

CATEGORY_COLORS: dict[str, str] = {
    "video": SEG_VIDEO,
    "image": SEG_IMAGE,
    "audio": SEG_AUDIO,
    "code": SEG_CODE,
    "document": SEG_DOC,
    "archive": SEG_ARCHIVE,
    "system": SEG_SYSTEM,
    "cloud": SEG_CLOUD,
    "default": SEG_OTHER,
}

FALLBACK_PALETTE = [
    SEG_CODE, SEG_VIDEO, SEG_IMAGE, SEG_CLOUD, SEG_DOC,
    WARNING, SEG_AUDIO, "#bc8cff", "#ff7b72", "#56d364",
]

SIDEBAR_WIDTH = 320
TOOLBAR_HEIGHT = 48
PANEL_RADIUS = 8
PADDING_PANEL = 16
ROW_HEIGHT = 36

FONT_UI = '"Segoe UI", "Inter", system-ui, sans-serif'
FONT_DISPLAY = '"Segoe UI", "Inter", system-ui, sans-serif'
FONT_MONO = '"Cascadia Mono", "JetBrains Mono", ui-monospace, monospace'

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
    border-left: 1px solid {BORDER};
}}

QLabel#SizeDisplay {{
    font-size: 28px;
    font-weight: 700;
    color: {TEXT_PRIMARY};
}}

QLabel#PathDisplay {{
    font-family: {FONT_MONO};
    font-size: 11px;
    color: {TEXT_MUTED};
}}

QLabel#MutedLabel, QLabel#SectionTitle {{
    color: {TEXT_MUTED};
    font-size: 11px;
    letter-spacing: 0.06em;
}}

QLabel#SectionTitle {{
    font-weight: 600;
    text-transform: uppercase;
}}

QLabel#ToolbarBrand {{
    font-size: 14px;
    font-weight: 600;
    color: {TEXT_PRIMARY};
}}

QLabel#ScanStatus {{
    font-family: {FONT_MONO};
    font-size: 11px;
    color: {TEXT_MUTED};
}}

QPushButton#BreadcrumbLink {{
    color: {TEXT_SECONDARY};
    background: transparent;
    border: none;
    border-bottom: 1px solid transparent;
    padding: 2px 0;
    font-weight: 500;
}}
QPushButton#BreadcrumbLink:hover {{
    color: {TEXT_PRIMARY};
    border-bottom-color: {TEXT_PRIMARY};
}}

QPushButton#BreadcrumbCurrent {{
    color: {TEXT_PRIMARY};
    background: transparent;
    border: none;
    padding: 2px 0;
    font-weight: 500;
}}

QFrame#Toolbar {{
    background-color: {BG_PANEL};
    border-bottom: 1px solid {BORDER};
    min-height: {TOOLBAR_HEIGHT}px;
}}

QPushButton {{
    background-color: {BG_HOVER};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 6px 12px;
    font-weight: 500;
    min-height: 32px;
}}

QPushButton:hover {{
    background-color: #2a3139;
}}

QPushButton#PrimaryButton {{
    background-color: {ACCENT};
    border-color: {ACCENT};
    color: #ffffff;
}}
QPushButton#PrimaryButton:hover {{
    background-color: {ACCENT_HOVER};
    border-color: {ACCENT_HOVER};
}}

QPushButton#GhostButton {{
    background: transparent;
    border: 1px solid {BORDER};
}}
QPushButton#GhostButton:hover {{
    background: {BG_HOVER};
}}

QPushButton#DangerButton {{
    background: {DANGER_BG};
    border-color: {DANGER_BORDER};
    color: {DANGER_TEXT};
}}
QPushButton#DangerButton:hover {{
    background: rgba(248, 81, 73, 0.22);
    border-color: {DANGER};
}}

QPushButton#ChipButton,
QToolButton#ChipButton {{
    font-size: 11px;
    font-weight: 500;
    padding: 3px 8px;
    min-height: 24px;
    border-radius: 999px;
}}

QPushButton#ChipWarning {{
    font-size: 11px;
    font-weight: 500;
    padding: 3px 8px;
    min-height: 24px;
    border-radius: 999px;
    border-color: rgba(210, 153, 34, 0.4);
    background: rgba(210, 153, 34, 0.12);
    color: {WARNING};
}}
QPushButton#ChipWarning:hover {{
    background: rgba(210, 153, 34, 0.2);
}}

QLabel#ChipLabel {{
    font-size: 11px;
    font-weight: 500;
    padding: 3px 8px;
    border-radius: 999px;
    border: 1px solid {BORDER};
    color: {TEXT_SECONDARY};
}}

QFrame#ViewToggle {{
    background: {BG_PANEL};
    border: 1px solid {BORDER};
    border-radius: 8px;
}}

QPushButton#ViewToggleBtn {{
    padding: 6px 14px;
    font-size: 12px;
    font-weight: 500;
    border: none;
    background: transparent;
    color: {TEXT_SECONDARY};
    min-height: 28px;
}}
QPushButton#ViewToggleBtn:hover {{
    background: transparent;
    color: {TEXT_PRIMARY};
}}
QPushButton#ViewToggleActive {{
    padding: 6px 14px;
    font-size: 12px;
    font-weight: 500;
    border: none;
    border-radius: 6px;
    background: {BG_HOVER};
    color: {TEXT_PRIMARY};
    min-height: 28px;
}}

QFrame#StateBanner {{
    background: rgba(88, 166, 255, 0.08);
    border-bottom: 1px solid rgba(88, 166, 255, 0.32);
    min-height: 36px;
}}
QFrame#StateBannerSuccess {{
    background: rgba(63, 185, 80, 0.1);
    border-bottom: 1px solid rgba(63, 185, 80, 0.35);
}}
QFrame#StateBannerWarning {{
    background: rgba(210, 153, 34, 0.1);
    border-bottom: 1px solid rgba(210, 153, 34, 0.38);
}}
QFrame#StateBannerDanger {{
    background: rgba(248, 81, 73, 0.12);
    border-bottom: 1px solid rgba(248, 81, 73, 0.42);
}}

QLabel#BannerTitle {{
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: {TEXT_PRIMARY};
}}

QFrame#CleanupCard {{
    background: {BG_APP};
    border: 1px solid {BORDER};
    border-radius: {PANEL_RADIUS}px;
}}

QLabel#CleanupGain {{
    color: {SUCCESS};
    font-weight: 600;
}}

QProgressBar {{
    background: {BORDER};
    border: none;
    max-height: 3px;
}}
QProgressBar::chunk {{
    background: {ACCENT};
}}

QListWidget#FileList {{
    background: transparent;
    border: none;
    outline: none;
}}
QListWidget#FileList::item {{
    min-height: {ROW_HEIGHT}px;
    padding: 0 {PADDING_PANEL}px;
    border-bottom: 1px solid {BORDER};
    color: {TEXT_PRIMARY};
}}
QListWidget#FileList::item:hover {{
    background: {BG_HOVER};
}}
QListWidget#FileList::item:selected {{
    background: {BG_SELECTED};
}}

QStatusBar {{
    background: {BG_PANEL};
    color: {TEXT_MUTED};
    border-top: 1px solid {BORDER};
}}

QMenu {{
    background: {BG_PANEL};
    border: 1px solid {BORDER};
    color: {TEXT_PRIMARY};
    padding: 4px;
}}
QMenu::item {{
    padding: 8px 24px;
    border-radius: 4px;
}}
QMenu::item:selected {{
    background: {BG_HOVER};
}}

QToolTip {{
    background: {BG_PANEL};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    padding: 8px 10px;
}}

QFrame#TimelineBar {{
    background: transparent;
    border-top: 1px solid {BORDER};
}}

QPushButton#TimelineDot {{
    min-height: 6px;
    max-height: 6px;
    border-radius: 3px;
    background: {BORDER};
    border: none;
    padding: 0;
}}
QPushButton#TimelineDot:hover {{
    background: {TEXT_MUTED};
}}
QPushButton#TimelineActive {{
    min-height: 6px;
    max-height: 6px;
    border-radius: 3px;
    background: {ACCENT};
    border: none;
    padding: 0;
}}

QComboBox {{
    background-color: {BG_HOVER};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 6px 10px;
}}

QLineEdit {{
    background-color: {BG_HOVER};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 6px 10px;
}}

QDialog {{
    background-color: {BG_APP};
    color: {TEXT_SECONDARY};
}}
"""
