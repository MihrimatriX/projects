"""Design tokens — design/*.html CSS variables."""

BG_APP = "#0f1419"
BG_TOOLBAR = "#15202b"
BG_CARD = "#1a2332"
BG_GROUP = "#15202b"
BG_HOVER = "#1e2d3d"
BG_SELECTED = "#1a3050"
BG_INPUT = "#15202b"
BORDER = "#2f3b4a"
BORDER_FOCUS = "#1d9bf0"
TEXT_PRIMARY = "#e7ecf3"
TEXT_SECONDARY = "#aab8c2"
TEXT_MUTED = "#8899a6"
TEXT_DISABLED = "#556677"
ACCENT = "#1d9bf0"
ACCENT_HOVER = "#1a8cd8"
ACCENT_TEXT = "#ffffff"
SAVINGS = "#00ba7c"
SAVINGS_BG = "rgba(0, 186, 124, 0.08)"
SAVINGS_BORDER = "rgba(0, 186, 124, 0.2)"
DANGER = "#f4212e"
DANGER_HOVER = "#dc1e2a"
WARNING = "#ffad1f"
WARNING_BG = "rgba(255, 173, 31, 0.15)"
CACHE_HIT = "#794bc4"

GROUP_RADIUS = 10
SIDEBAR_WIDTH = 220
PROGRESS_HEIGHT = 6

FONT_UI = '"Segoe UI", "Inter", system-ui, sans-serif'
FONT_MONO = '"JetBrains Mono", "Cascadia Mono", Consolas, ui-monospace, monospace'

APP_STYLE = f"""
* {{
    font-family: {FONT_UI};
    font-size: 13px;
}}

QMainWindow, QWidget#CentralWidget, QDialog {{
    background-color: {BG_APP};
    color: {TEXT_PRIMARY};
}}

QFrame#Sidebar {{
    background-color: {BG_TOOLBAR};
    border-right: 1px solid {BORDER};
    min-width: {SIDEBAR_WIDTH}px;
    max-width: {SIDEBAR_WIDTH}px;
}}

QLabel#SidebarHeader, QLabel#SectionHeader {{
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: {TEXT_MUTED};
    padding: 12px 14px 8px;
}}

QFrame#Toolbar {{
    background-color: {BG_TOOLBAR};
    border-bottom: 1px solid {BORDER};
    min-height: 56px;
    max-height: 56px;
}}

QFrame#SavingsBanner {{
    background-color: {SAVINGS_BG};
    border-bottom: 1px solid {SAVINGS_BORDER};
}}

QLabel#SavingsAmount {{
    font-size: 28px;
    font-weight: 700;
    color: {SAVINGS};
}}

QLabel#SavingsMeta {{
    font-size: 13px;
    color: {TEXT_SECONDARY};
}}

QFrame#ActionBar {{
    background-color: {BG_TOOLBAR};
    border-top: 1px solid {BORDER};
    min-height: 48px;
}}

QFrame#ScanProgressPanel {{
    background-color: {BG_TOOLBAR};
    border-bottom: 1px solid {BORDER};
}}

QLabel#ScanningBadge {{
    color: {ACCENT};
    font-weight: 600;
}}

QFrame#EmptyState {{
    background: transparent;
}}

QFrame#DropZone {{
    background-color: {BG_TOOLBAR};
    border: 2px dashed {BORDER};
    border-radius: {GROUP_RADIUS}px;
    max-width: 480px;
}}

QLabel#DropTitle {{
    font-size: 18px;
    font-weight: 600;
}}

QLabel#DropIcon {{
    font-size: 40px;
}}

QFrame#GroupCard {{
    background-color: {BG_CARD};
    border: 1px solid {BORDER};
    border-radius: {GROUP_RADIUS}px;
}}

QFrame#GroupHead {{
    background: transparent;
    border: none;
}}

QFrame#GroupHead:hover {{
    background-color: {BG_HOVER};
}}
QFrame#GroupHead:focus {{
    border: 1px solid {BORDER_FOCUS};
}}

QFrame#FileRowKeep, QFrame#FileRowMarked {{
    background-color: {BG_GROUP};
    border-top: 1px solid {BORDER};
}}

QFrame#FileRowMarked:hover, QFrame#FileRowKeep:hover {{
    background-color: {BG_HOVER};
}}

QLabel#Chevron {{
    color: {TEXT_MUTED};
    min-width: 14px;
}}

QLabel#BadgeWarning {{
    font-size: 10px;
    font-weight: 600;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    padding: 3px 7px;
    border-radius: 4px;
    background: {WARNING_BG};
    color: {WARNING};
}}

QLabel#TagKeep {{
    font-size: 10px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 3px;
    background: rgba(0, 186, 124, 0.15);
    color: {SAVINGS};
}}

QLabel#TagRecommended {{
    font-size: 10px;
    font-weight: 600;
    padding: 2px 6px;
    border-radius: 3px;
    background: rgba(136, 153, 166, 0.2);
    color: {TEXT_MUTED};
}}

QLabel#TitleLabel {{
    font-size: 20px;
    font-weight: 600;
}}

QLabel#MutedLabel {{
    color: {TEXT_MUTED};
    font-size: 12px;
}}

QLabel#MonoLabel {{
    font-family: {FONT_MONO};
    font-size: 12px;
    color: {TEXT_MUTED};
}}

QLabel#SavingsLabel {{
    color: {SAVINGS};
    font-weight: 600;
}}

QLabel#DangerLabel {{
    color: {DANGER};
    font-weight: 600;
}}

QProgressBar {{
    border: none;
    border-radius: 99px;
    background-color: {BG_APP};
    min-height: {PROGRESS_HEIGHT}px;
    max-height: {PROGRESS_HEIGHT}px;
}}

QProgressBar::chunk {{
    background-color: {ACCENT};
    border-radius: 99px;
}}

QLineEdit, QListWidget {{
    background-color: {BG_INPUT};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 8px 10px;
    outline: none;
}}

QListWidget#RootsList {{
    border: none;
    background: transparent;
    padding: 0 8px;
}}

QListWidget#RootsList::item {{
    padding: 8px 10px;
    border-radius: 6px;
    color: {TEXT_SECONDARY};
}}

QListWidget#RootsList::item:selected, QListWidget#RootsList::item:hover {{
    background-color: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}

QPushButton#SidebarAdd {{
    margin: 8px;
    padding: 8px;
    border: 1px dashed {BORDER};
    border-radius: 6px;
    background: transparent;
    color: {TEXT_MUTED};
    font-weight: 500;
}}

QPushButton#SidebarAdd:hover {{
    border-color: {ACCENT};
    color: {ACCENT};
}}

QPushButton#ModeButton {{
    padding: 6px 12px;
    border: none;
    border-radius: 0;
    background: transparent;
    color: {TEXT_MUTED};
    font-weight: 600;
}}

QPushButton#ModeButton:checked {{
    background-color: {BG_SELECTED};
    color: {ACCENT};
}}

QFrame#ModeSelect {{
    background: {BG_APP};
    border: 1px solid {BORDER};
    border-radius: 6px;
}}

QPushButton {{
    background-color: {BG_CARD};
    color: {TEXT_PRIMARY};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 7px 14px;
    font-weight: 600;
}}

QPushButton:hover {{
    background-color: {BG_HOVER};
}}

QPushButton#PrimaryButton {{
    background-color: {ACCENT};
    border-color: {ACCENT};
    color: {ACCENT_TEXT};
}}

QPushButton#PrimaryButton:hover {{
    background-color: {ACCENT_HOVER};
}}

QPushButton#DangerButton {{
    border-color: rgba(244, 33, 46, 0.4);
    color: {DANGER};
    background: transparent;
}}

QPushButton#DangerButton:hover {{
    background: rgba(244, 33, 46, 0.12);
}}

QPushButton#DangerOutlineButton {{
    border-color: rgba(244, 33, 46, 0.4);
    color: {DANGER};
    background: transparent;
}}

QPushButton:disabled {{
    opacity: 0.45;
}}

QStatusBar {{
    color: {TEXT_MUTED};
    background: {BG_APP};
    font-family: {FONT_MONO};
    font-size: 11px;
}}

QMenuBar {{
    background: {BG_APP};
    color: {TEXT_SECONDARY};
    border-bottom: 1px solid {BORDER};
    padding: 0 8px;
    font-size: 12px;
}}

QMenuBar::item:selected {{
    background: {BG_HOVER};
    color: {TEXT_PRIMARY};
}}

QMenu {{
    background: {BG_CARD};
    border: 1px solid {BORDER};
    color: {TEXT_PRIMARY};
}}

QMenu::item:selected {{
    background: {BG_HOVER};
}}

QTreeWidget, QTreeView, QListView {{
    background: {BG_APP};
    border: 1px solid {BORDER};
    border-radius: {GROUP_RADIUS}px;
    color: {TEXT_PRIMARY};
    alternate-background-color: {BG_GROUP};
}}

QHeaderView::section {{
    background: {BG_TOOLBAR};
    color: {TEXT_MUTED};
    border: none;
    border-bottom: 1px solid {BORDER};
    padding: 6px 8px;
}}

QCheckBox::indicator {{
    width: 18px;
    height: 18px;
    border-radius: 4px;
    border: 1px solid {BORDER};
    background: {BG_INPUT};
}}

QCheckBox::indicator:checked {{
    background: {ACCENT};
    border-color: {ACCENT};
}}

QScrollArea {{
    border: none;
    background: transparent;
}}

QComboBox {{
    background: {BG_CARD};
    border: 1px solid {BORDER};
    border-radius: 6px;
    padding: 6px 10px;
    color: {TEXT_PRIMARY};
}}
"""
