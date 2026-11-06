#!/bin/sh
# The command icons (assets/art/icons/*.svg) as PNGs at twice their size (as icons.gd rasterises them) for the
# Lobster port, which can't read SVG; then the culture crests (icons_crests.lobster). Needs rsvg-convert.
# Usage: src/icons.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p src/icons/glyph
for f in assets/art/icons/*.svg assets/art/icons/glyph/*.svg; do
	o=src/icons/${f#assets/art/icons/}
	rsvg-convert -z 2 "$f" -o "${o%.svg}.png"
done
for f in assets/art/cursors/*.svg; do
	n=${f##*/}
	rsvg-convert -z 2 "$f" -o "src/icons/cursor_${n%.svg}.png"
done
src/icons_cursors.sh
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
(cd src && "$LOBSTER" icons_crests.lobster) | while read -r orn light mid dark; do
	sed -e "s/{L}/$light/g" -e "s/{M}/$mid/g" -e "s/{D}/$dark/g" "assets/art/ui/crest_$orn.svg" | rsvg-convert -z 2 -o "src/icons/crest_$orn.png"
done
src/icons_game.sh
