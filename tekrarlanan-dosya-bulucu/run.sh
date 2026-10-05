#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Sistem python'una pip kurulumu modern dağıtımlarda engelli (PEP 668); venv kullan
if [[ ! -x ".venv/bin/python" ]]; then
  python3 -m venv .venv
fi
PY=".venv/bin/python"

"$PY" -m pip install -r requirements.txt -q
exec "$PY" main.py "$@"
