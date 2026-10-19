"""Tasarım token'ları — design/index.html kaynak."""

from __future__ import annotations

# Koyu tema (varsayılan)
DARK = {
    "bg_app": "#18181b",
    "bg_panel": "#27272a",
    "bg_table": "#1f1f23",
    "bg_hover": "#3f3f46",
    "border": "#3f3f46",
    "border_strong": "#52525b",
    "text_primary": "#fafafa",
    "text_secondary": "#a1a1aa",
    "text_muted": "#71717a",
    "accent": "#8b5cf6",
    "accent_hover": "#7c3aed",
    "on_accent": "#ffffff",
    "accent_subtle": "rgba(139, 92, 246, 0.15)",
    "accent_subtle_hover": "rgba(139, 92, 246, 0.28)",
    "success": "#22c55e",
    "warning": "#eab308",
    "danger": "#ef4444",
    "preview_old": "#fca5a5",
    "preview_new": "#86efac",
    "conflict_bg": "rgba(239, 68, 68, 0.12)",
}

LIGHT = {
    "bg_app": "#fafafa",
    "bg_panel": "#f4f4f5",
    "bg_table": "#ffffff",
    "bg_hover": "#e4e4e7",
    "border": "#e4e4e7",
    "border_strong": "#d4d4d8",
    "text_primary": "#18181b",
    "text_secondary": "#52525b",
    "text_muted": "#71717a",
    "accent": "#8b5cf6",
    "accent_hover": "#7c3aed",
    "on_accent": "#ffffff",
    "accent_subtle": "rgba(139, 92, 246, 0.12)",
    "accent_subtle_hover": "rgba(139, 92, 246, 0.22)",
    "success": "#16a34a",
    "warning": "#eab308",
    "danger": "#dc2626",
    "preview_old": "#dc2626",
    "preview_new": "#16a34a",
    "conflict_bg": "rgba(220, 38, 38, 0.1)",
}

# Geriye dönük kısayollar (koyu tema)
TEXT_PRIMARY = DARK["text_primary"]
TEXT_MUTED = DARK["text_muted"]
DANGER = DARK["danger"]
SUCCESS = DARK["success"]
PREVIEW_OLD = DARK["preview_old"]
PREVIEW_NEW = DARK["preview_new"]

RADIUS = 8
RADIUS_INPUT = 6
PANEL_WIDTH = 360
ROW_HEIGHT = 40
FONT_UI = "Segoe UI"
FONT_MONO = "Consolas"
