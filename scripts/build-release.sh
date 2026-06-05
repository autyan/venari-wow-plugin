#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$ROOT_DIR/src/Venari"
OUT_DIR="$ROOT_DIR/dist/release/Venari"
ZIP_PATH="$ROOT_DIR/dist/Venari-release.zip"

rm -rf "$OUT_DIR"
mkdir -p "$(dirname "$OUT_DIR")"
cp -a "$SRC_DIR" "$OUT_DIR"

python3 "$ROOT_DIR/scripts/make-release.py" "$OUT_DIR/Venari.lua" "$OUT_DIR/VenariLocale.lua"

lua -e "assert(loadfile('$OUT_DIR/VenariLocale.lua')); assert(loadfile('$OUT_DIR/VenariPetFoodDB.lua')); assert(loadfile('$OUT_DIR/Venari.lua'))"

rm -f "$ZIP_PATH"
(
  cd "$ROOT_DIR/dist/release"
  zip -qr "$ZIP_PATH" Venari
)

echo "Built release addon: $OUT_DIR"
echo "Built release zip: $ZIP_PATH"
