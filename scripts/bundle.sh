#!/usr/bin/env bash
# Assembla VilisWhisp.app a partire dal binario compilato da SwiftPM.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=VilisWhisp
BIN_DIR="$(swift build -c release --show-bin-path)"
BIN="$BIN_DIR/$APP"
OUT="build/$APP.app"

if [[ ! -x "$BIN" ]]; then
  echo "Binario non trovato: $BIN (esegui prima 'swift build -c release')" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP"
cp Resources/Info.plist "$OUT/Contents/Info.plist"
echo -n "APPL????" > "$OUT/Contents/PkgInfo"

if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$OUT/Contents/Resources/AppIcon.icns"
elif command -v iconutil >/dev/null 2>&1; then
  bash scripts/make_icon.sh >/dev/null 2>&1 || true
  [[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$OUT/Contents/Resources/AppIcon.icns"
fi

# Firma ad-hoc stabile: i permessi Microfono/Accessibility sono legati all'identita' del bundle.
codesign --force --deep --sign - --identifier it.vili.whisp "$OUT"
touch "$OUT"
echo "Creato $OUT"
