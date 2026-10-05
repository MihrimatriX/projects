#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="TekrarlananDosyaBulucu"
DIST_DIR="dist"

if [ ! -f "$DIST_DIR/$APP_NAME" ] && [ ! -d "$DIST_DIR/${APP_NAME}.app" ]; then
  echo ">>> publish.sh calistiriliyor..."
  bash ./publish.sh
fi

if [[ "$OSTYPE" == darwin* ]]; then
  TARGET="$HOME/Applications/${APP_NAME}.app"
  if [ -d "$DIST_DIR/${APP_NAME}.app" ]; then
    rm -rf "$TARGET"
    cp -R "$DIST_DIR/${APP_NAME}.app" "$TARGET"
    echo "Kuruldu: $TARGET"
  else
    echo "macOS .app bulunamadi. packaging/build-macos.sh veya publish.sh calistirin." >&2
    exit 1
  fi
else
  INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local}/bin"
  mkdir -p "$INSTALL_DIR"
  if [ -f "$DIST_DIR/$APP_NAME" ]; then
    install -m 755 "$DIST_DIR/$APP_NAME" "$INSTALL_DIR/$APP_NAME"
    echo "Kuruldu: $INSTALL_DIR/$APP_NAME"
    echo "PATH icinde ~/.local/bin oldugundan emin olun."
  else
    echo "Linux binary bulunamadi: $DIST_DIR/$APP_NAME" >&2
    exit 1
  fi
fi
