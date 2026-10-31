#!/bin/sh
# The command icons (assets/art/icons/*.svg) as PNGs at twice their size (as icons.gd rasterises them) for the
# Lobster port, which can't read SVG; then the culture crests (icons_crests.py). Needs rsvg-convert.
# Usage: src/icons.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p src/icons/glyph
for f in assets/art/icons/*.svg assets/art/icons/glyph/*.svg; do
	o=src/icons/${f#assets/art/icons/}
	rsvg-convert -z 2 "$f" -o "${o%.svg}.png"
done
python3 src/icons_crests.py
python3 src/icons_game.py
