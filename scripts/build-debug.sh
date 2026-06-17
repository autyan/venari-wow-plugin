#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-tbc-anniversary-cn}"
SRC_DIR="$ROOT_DIR/src/Venari"
OUT_DIR="$ROOT_DIR/dist/debug/Venari"
ZIP_PATH="$ROOT_DIR/dist/Venari-debug.zip"
PORT="$ROOT_DIR/ports/$VERSION/VenariPort.lua"

if [[ ! -f "$PORT" ]]; then
  echo "unknown version or missing port: $VERSION" >&2
  exit 2
fi

rm -rf "$OUT_DIR"
mkdir -p "$(dirname "$OUT_DIR")"
cp -a "$SRC_DIR" "$OUT_DIR"
cp "$PORT" "$OUT_DIR/VenariPort.lua"

lua -e "assert(loadfile('$OUT_DIR/VenariPort.lua')); assert(loadfile('$OUT_DIR/VenariLocale.lua')); assert(loadfile('$OUT_DIR/VenariPetFoodDB.lua')); assert(loadfile('$OUT_DIR/Venari.lua'))"

rm -f "$ZIP_PATH"
(
  cd "$ROOT_DIR/dist/debug"
  zip -qr "$ZIP_PATH" Venari
)

echo "Built debug addon: $OUT_DIR"
echo "Built debug zip: $ZIP_PATH"
