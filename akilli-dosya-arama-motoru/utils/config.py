import os
from pathlib import Path

APP_VERSION = "3.1.0"

# Ayar, indeks ve geçmiş klasörü; testler/taşınabilir kullanım için AKILLI_ARAMA_DATA_DIR ile değiştirilebilir.
DATA_DIR = Path(os.environ.get("AKILLI_ARAMA_DATA_DIR") or Path.home() / ".akilli-dosya-arama")

_projects = Path.home() / "Desktop" / "projects"
DEFAULT_SEARCH_ROOT = _projects if _projects.is_dir() else Path.home()
MAX_RESULTS = 50
FUZZY_MIN_SCORE = 58
FUZZY_CANDIDATE_LIMIT = 10000
SNIPPET_MAX_BYTES = 4096
CONTENT_SEARCH_MAX_BYTES = 512_000
PREVIEW_SIZE = 48

EXCLUDE_DIR_NAMES = frozenset({
    ".git",
    "node_modules",
    "target",
    "__pycache__",
    ".venv",
    ".dart_tool",
    "dist",
    "build",
})

CODE_EXTENSIONS = frozenset({
    ".py", ".rs", ".ts", ".tsx", ".js", ".jsx", ".go", ".java", ".cs", ".cpp", ".c", ".h",
    ".md", ".json", ".yaml", ".yml", ".toml",
})

TEXT_EXTENSIONS = CODE_EXTENSIONS | frozenset({
    ".txt", ".log", ".csv", ".xml", ".html", ".htm", ".css", ".scss", ".sql",
    ".ini", ".cfg", ".env", ".bat", ".ps1", ".sh",
})

IMAGE_EXTENSIONS = frozenset({
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".ico",
})

DOCS_EXTENSIONS = frozenset({
    ".pdf", ".doc", ".docx", ".txt", ".md", ".rtf", ".odt", ".xls", ".xlsx",
    ".ppt", ".pptx", ".csv", ".log",
})

DEFAULT_EXCLUDE_PATTERNS = (
    "node_modules",
    ".git",
    "target",
    "*.tmp",
    ".DS_Store",
)

BINARY_SKIP_EXTENSIONS = frozenset({
    ".exe", ".dll", ".so", ".dylib", ".bin", ".zip", ".rar", ".7z",
    ".mp4", ".mkv", ".avi", ".mp3", ".wav", ".flac", ".iso",
    ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
})
