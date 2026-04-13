#!/usr/bin/env bash
set -Eeuo pipefail

DOWNLOADS_DIR="$HOME/Downloads"
SOURCE_KEYMAP="$DOWNLOADS_DIR/go60.keymap"
TARGET_KEYMAP="config/go60.keymap"

echo "Looking for keymap at: $SOURCE_KEYMAP"

if [[ ! -f "$SOURCE_KEYMAP" ]]; then
  echo "Error: $SOURCE_KEYMAP not found."
  exit 1
fi

echo "Replacing $TARGET_KEYMAP with downloaded keymap..."
mv -f "$SOURCE_KEYMAP" "$TARGET_KEYMAP"

echo "Running build..."
./build.sh

echo "Build succeeded."
echo "Running flash script..."
./flash_go60.sh

echo "Done."
