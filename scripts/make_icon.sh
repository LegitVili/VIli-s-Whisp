#!/usr/bin/env bash
# Genera Resources/AppIcon.icns (icona semplice con una forma d'onda) usando solo strumenti di sistema.
set -euo pipefail
cd "$(dirname "$0")/.."
ICONSET=Resources/AppIcon.iconset
rm -rf "$ICONSET"; mkdir -p "$ICONSET"

render() { # $1 = size px, $2 = nome file
  swift - "$1" "$ICONSET/$2" <<'SWIFT'
import AppKit
let size = CGFloat(Double(CommandLine.arguments[1])!)
let path = CommandLine.arguments[2]
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size*0.04, dy: size*0.04), xRadius: size*0.22, yRadius: size*0.22)
NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 1).setFill(); bg.fill()
let bars: [CGFloat] = [0.25, 0.5, 0.8, 0.55, 0.35]
let w = size * 0.09, gap = size * 0.06
let total = CGFloat(bars.count) * w + CGFloat(bars.count - 1) * gap
var x = (size - total) / 2
for h in bars {
  let bh = size * 0.6 * h
  let r = NSRect(x: x, y: (size - bh)/2, width: w, height: bh)
  NSColor(calibratedRed: 0.45, green: 0.75, blue: 1.0, alpha: 1).setFill()
  NSBezierPath(roundedRect: r, xRadius: w/2, yRadius: w/2).fill()
  x += w + gap
}
img.unlockFocus()
let tiff = img.tiffRepresentation!
let rep = NSBitmapImageRep(data: tiff)!
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: path))
SWIFT
}

for s in 16 32 128 256 512; do
  render "$s" "icon_${s}x${s}.png"
  render "$((s*2))" "icon_${s}x${s}@2x.png"
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
rm -rf "$ICONSET"
echo "Creata Resources/AppIcon.icns"
