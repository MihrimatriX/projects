#!/usr/bin/env bash
# macOS geliştirme derlemesi — publish.sh ile aynı çıktı
set -euo pipefail
cd "$(dirname "$0")/.."
exec bash ./publish.sh
