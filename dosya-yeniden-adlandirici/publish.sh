#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  PYTHON=python
fi

if [ ! -d .venv ]; then
  "$PYTHON" -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate

pip install -q -r requirements.txt pytest pyinstaller

echo ">>> Testler"
python -m pytest tests/ -q

echo ">>> PyInstaller"
pyinstaller \
  --noconfirm \
  --onefile \
  --windowed \
  --name DosyaYenidenAdlandirici \
  --hidden-import=PIL \
  --collect-all PySide6 \
  main.py

echo ">>> Hazir: dist/DosyaYenidenAdlandirici"
