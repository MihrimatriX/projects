#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TekrarlananDosyaBulucu"

if [[ "$OSTYPE" == darwin* ]]; then
  TARGET="$HOME/Applications/${APP_NAME}.app"
  if [ -d "$TARGET" ]; then
    rm -rf "$TARGET"
    echo "Kaldirildi: $TARGET"
  else
    echo "Kurulu .app bulunamadi: $TARGET"
  fi
else
  BIN="${XDG_DATA_HOME:-$HOME/.local}/bin/$APP_NAME"
  if [ -f "$BIN" ]; then
    rm -f "$BIN"
    echo "Kaldirildi: $BIN"
  else
    echo "Binary bulunamadi: $BIN"
  fi
fi
