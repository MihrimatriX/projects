#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
echo ""
echo ">>> Binary: .build/release/ClipboardGecmisiYoneticisi"
echo ">>> Calistir: .build/release/ClipboardGecmisiYoneticisi"
