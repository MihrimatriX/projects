"""Qt stil sayfası — design/index.html token'ları."""

from __future__ import annotations

from ui.theme import FONT_MONO, FONT_UI, RADIUS, RADIUS_INPUT


def _base(tokens: dict[str, str]) -> str:
    t = tokens
    return f"""
* {{
    font-family: "{FONT_UI}", sans-serif;
    font-size: 13px;
}}

QMainWindow, QWidget#CentralWidget {{
    background-color: {t["bg_app"]};
    color: {t["text_secondary"]};
}}

QFrame#AppToolbar {{
    background-color: {t["bg_panel"]};
    border-bottom: 1px solid {t["border"]};
}}

QFrame#ToolbarSeparator {{
    background-color: {t["border"]};
}}

QFrame#PreviewPane {{
    background-color: {t["bg_app"]};
}}

QFrame#PreviewHeader {{
    background-color: {t["bg_app"]};
    border-bottom: 1px solid {t["border"]};
}}

QFrame#PreviewFooter {{
    background-color: {t["bg_app"]};
    border-top: 1px solid {t["border"]};
}}

QFrame#ProgressRow {{
    background-color: {t["bg_table"]};
    border-bottom: 1px solid {t["border"]};
}}

QLabel#PreviewTitle {{
    color: {t["text_primary"]};
    font-size: 12px;
    font-weight: 600;
}}

QLabel#RuleTypeLabel {{
    color: {t["text_primary"]};
    font-size: 12px;
    font-weight: 600;
}}

QLabel#DragHandle {{
    color: {t["text_muted"]};
    font-size: 14px;
}}

QLabel#FieldError {{
    color: {t["danger"]};
    font-size: 11px;
}}

QLabel#PathLabel {{
    color: {t["text_muted"]};
    font-size: 11px;
    font-family: "{FONT_MONO}", monospace;
}}

QLabel#ShortcutLabel {{
    color: {t["text_muted"]};
    font-size: 12px;
}}

QFrame#RulesPanel {{
    background-color: {t["bg_panel"]};
    border-right: 1px solid {t["border"]};
    min-width: 320px;
    max-width: 400px;
}}

QFrame#RuleCard {{
    background-color: {t["bg_app"]};
    border: 1px solid {t["border"]};
    border-left: 3px solid {t["accent"]};
    border-radius: {RADIUS}px;
    margin-bottom: 8px;
}}

QFrame#RuleCard[active="false"] {{
    border-left-color: {t["border"]};
}}

QFrame#RuleCard[error="true"] {{
    border-color: {t["danger"]};
    border-left-color: {t["danger"]};
}}

QLabel#SectionTitle {{
    color: {t["text_muted"]};
    font-size: 11px;
    font-weight: 600;
    letter-spacing: 0.06em;
}}

QLabel#AppTitle {{
    color: {t["text_primary"]};
    font-size: 15px;
    font-weight: 600;
    letter-spacing: -0.01em;
}}

QLabel#FieldLabel {{
    color: {t["text_muted"]};
    font-size: 11px;
    margin-top: 4px;
}}

QLabel#StatValid {{ color: {t["success"]}; font-size: 12px; font-weight: 600; }}
QLabel#StatConflict {{ color: {t["danger"]}; font-size: 12px; font-weight: 600; }}
QLabel#StatMuted {{ color: {t["text_muted"]}; font-size: 12px; }}

QLabel#EmptyHint {{
    color: {t["text_muted"]};
    font-size: 14px;
}}

QFrame#DropOverlay {{
    background: {t["accent_subtle"]};
    border: 2px solid {t["accent"]};
}}

QLabel#DropHint {{
    color: {t["text_primary"]};
    font-size: 14px;
    font-weight: 600;
}}

QLineEdit, QSpinBox, QComboBox, QTextEdit {{
    background-color: {t["bg_table"]};
    color: {t["text_primary"]};
    border: 1px solid {t["border"]};
    border-radius: {RADIUS_INPUT}px;
    padding: 7px 10px;
    min-height: 18px;
    selection-background-color: {t["accent"]};
}}

QLineEdit:focus, QSpinBox:focus, QComboBox:focus {{
    border-color: {t["accent"]};
}}

QLineEdit[invalid="true"] {{
    border-color: {t["danger"]};
}}

QComboBox::drop-down {{
    border: none;
    width: 20px;
}}

QCheckBox {{
    color: {t["text_primary"]};
    spacing: 6px;
}}

QCheckBox::indicator {{
    width: 16px;
    height: 16px;
    border-radius: 3px;
    border: 1px solid {t["border"]};
    background: {t["bg_table"]};
}}

QCheckBox::indicator:checked {{
    background: {t["accent"]};
    border-color: {t["accent"]};
}}

QListWidget {{
    background: transparent;
    border: none;
    outline: none;
}}

QListWidget::item {{
    background: transparent;
    border: none;
    padding: 0;
    margin-bottom: 4px;
}}

QListWidget::item:selected {{
    background: transparent;
}}

QTableWidget {{
    background-color: {t["bg_table"]};
    color: {t["text_primary"]};
    border: none;
    gridline-color: {t["border"]};
    selection-background-color: {t["bg_hover"]};
    selection-color: {t["text_primary"]};
    alternate-background-color: transparent;
}}

QTableWidget::item {{
    padding: 0 16px;
    border-bottom: 1px solid {t["border"]};
}}

QHeaderView::section {{
    background-color: {t["bg_table"]};
    color: {t["text_muted"]};
    border: none;
    border-bottom: 1px solid {t["border"]};
    padding: 10px 16px;
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
}}

QPushButton#ToolbarButton {{
    background-color: {t["bg_panel"]};
    color: {t["text_primary"]};
    border: 1px solid {t["border"]};
    border-radius: {RADIUS}px;
    padding: 8px 14px;
    font-weight: 600;
    min-height: 20px;
}}

QPushButton#ToolbarButton:hover:enabled {{
    background-color: {t["bg_hover"]};
}}

QPushButton#ToolbarGhostButton {{
    background: transparent;
    border: none;
    color: {t["text_muted"]};
    font-weight: 500;
    padding: 8px 10px;
}}

QPushButton#ToolbarGhostButton:hover {{
    background-color: {t["bg_hover"]};
    color: {t["text_secondary"]};
}}

QToolButton#IconButton {{
    background-color: {t["bg_panel"]};
    color: {t["text_primary"]};
    border: 1px solid {t["border"]};
    border-radius: {RADIUS}px;
    padding: 8px;
    min-width: 36px;
    max-width: 36px;
    min-height: 36px;
}}

QToolButton#IconButton:hover {{
    background-color: {t["bg_hover"]};
}}

QPushButton {{
    background-color: {t["bg_panel"]};
    color: {t["text_primary"]};
    border: 1px solid {t["border"]};
    border-radius: {RADIUS}px;
    padding: 8px 14px;
    font-weight: 600;
}}

QPushButton:hover {{
    background-color: {t["bg_hover"]};
}}

QPushButton:disabled {{
    opacity: 0.45;
}}

QPushButton#PrimaryButton {{
    background-color: {t["accent"]};
    border-color: {t["accent"]};
    color: {t["on_accent"]};
}}

QPushButton#PrimaryButton:hover:enabled {{
    background-color: {t["accent_hover"]};
}}

QPushButton#PrimaryButton:disabled {{
    background-color: {t["bg_hover"]};
    border-color: {t["border"]};
    color: {t["text_muted"]};
}}

QPushButton#GhostButton {{
    background: transparent;
    border: 1px dashed {t["border"]};
    color: {t["accent"]};
    font-weight: 500;
}}

QPushButton#GhostButton:hover {{
    background-color: {t["bg_hover"]};
}}

QPushButton#GhostTextButton {{
    background: transparent;
    border: none;
    color: {t["text_muted"]};
    font-weight: 500;
    font-size: 11px;
    padding: 4px 8px;
}}

QPushButton#GhostTextButton:hover {{
    background-color: {t["bg_hover"]};
    color: {t["text_secondary"]};
}}

QPushButton#GhostTextButton:checked {{
    background-color: {t["accent_subtle"]};
    color: {t["accent"]};
}}

QPushButton#GhostDangerButton {{
    background: transparent;
    border: none;
    color: {t["danger"]};
    font-weight: 500;
    padding: 4px 8px;
}}

QPushButton#GhostDangerButton:hover {{
    background-color: {t["conflict_bg"]};
}}

QPushButton#IconButton {{
    padding: 8px;
    min-width: 36px;
    max-width: 36px;
}}

QPushButton#ChipButton {{
    background-color: {t["accent_subtle"]};
    border: none;
    color: {t["accent"]};
    font-size: 11px;
    font-weight: 500;
    padding: 4px 10px;
    border-radius: 999px;
}}

QPushButton#ChipButton:hover {{
    background-color: {t["accent_subtle_hover"]};
}}

QPushButton#SmallButton {{
    padding: 4px;
    min-width: 26px;
    max-width: 28px;
    font-size: 11px;
}}

QScrollArea {{
    border: none;
    background: transparent;
}}

QScrollBar:vertical {{
    background: {t["bg_app"]};
    width: 10px;
    margin: 0;
}}

QScrollBar::handle:vertical {{
    background: {t["border"]};
    border-radius: 5px;
    min-height: 24px;
}}

QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
    height: 0;
}}

QSplitter::handle {{
    background: {t["border"]};
}}

QSplitter::handle:horizontal {{
    width: 1px;
}}

QSplitter::handle:vertical {{
    height: 1px;
}}

QStatusBar {{
    color: {t["text_muted"]};
    background: {t["bg_app"]};
    border-top: 1px solid {t["border"]};
    font-size: 12px;
    padding: 4px 16px;
}}

QToolBar {{
    background: {t["bg_panel"]};
    border-bottom: 1px solid {t["border"]};
    spacing: 8px;
    padding: 8px 12px;
}}

QToolBar::separator {{
    width: 1px;
    background: {t["border"]};
    margin: 4px;
}}

QProgressBar {{
    border: none;
    border-radius: 4px;
    background: {t["border"]};
    max-height: 4px;
    text-align: right;
}}

QProgressBar::chunk {{
    background-color: {t["accent"]};
    border-radius: 4px;
}}

QMenuBar {{
    background: {t["bg_panel"]};
    color: {t["text_secondary"]};
    border-bottom: 1px solid {t["border"]};
}}

QMenuBar::item:selected {{
    background: {t["bg_hover"]};
}}

QMenu {{
    background: {t["bg_panel"]};
    color: {t["text_primary"]};
    border: 1px solid {t["border"]};
}}

QMenu::item:selected {{
    background: {t["bg_hover"]};
}}

QDialog {{
    background-color: {t["bg_panel"]};
    color: {t["text_secondary"]};
}}

QDialog QLabel#ModalTitle {{
    color: {t["text_primary"]};
    font-size: 20px;
    font-weight: 600;
    letter-spacing: -0.02em;
}}

QDialog QLabel#ModalBody {{
    color: {t["text_secondary"]};
    font-size: 14px;
    line-height: 1.5;
}}

QFrame#ModalIllus {{
    background: {t["bg_table"]};
    border: 1px solid {t["border"]};
    border-radius: {RADIUS_INPUT}px;
    min-height: 120px;
}}

QFrame#ModalBlock {{
    background: {t["bg_app"]};
    border: 1px solid {t["border"]};
    border-radius: 4px;
}}

QFrame#ModalBlock[accent="true"] {{
    border-left: 3px solid {t["accent"]};
}}

QPushButton#ModalDot {{
    min-width: 6px;
    max-width: 6px;
    min-height: 6px;
    max-height: 6px;
    border-radius: 3px;
    padding: 0;
    background: {t["border"]};
    border: none;
}}

QPushButton#ModalDot:checked {{
    background: {t["accent"]};
}}

QPushButton#SkipLink {{
    background: transparent;
    border: none;
    color: {t["text_muted"]};
    font-weight: normal;
    text-decoration: underline;
    padding: 4px;
}}
"""


def get_app_style(theme: str) -> str:
    from ui.theme import DARK, LIGHT

    tokens = LIGHT if theme == "light" else DARK
    return _base(tokens)
