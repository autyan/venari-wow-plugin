#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src/Venari"
OUT_DIR="$ROOT_DIR/dist/debug/Venari"
ZIP_PATH="$ROOT_DIR/dist/Venari-debug.zip"

rm -rf "$OUT_DIR"
mkdir -p "$(dirname "$OUT_DIR")"
cp -a "$SRC_DIR" "$OUT_DIR"

lua -e "assert(loadfile('$OUT_DIR/VenariLocale.lua')); assert(loadfile('$OUT_DIR/VenariPetFoodDB.lua')); assert(loadfile('$OUT_DIR/Venari.lua'))"

rm -f "$ZIP_PATH"
(
  cd "$ROOT_DIR/dist/debug"
  zip -qr "$ZIP_PATH" Venari
)

echo "Built debug addon: $OUT_DIR"
echo "Built debug zip: $ZIP_PATH"
