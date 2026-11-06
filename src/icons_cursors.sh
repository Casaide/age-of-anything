#!/bin/sh
# The OS cursors (#222): each kind's art on one 40-unit canvas at the size it's shown (0.65 of the 32-unit art: 26 points),
# at 1x and 2x, into src/icons/os_cursor/. A tool sits at (7, 7) with the small pointer at half size at the top left.
# Needs rsvg-convert. Usage: src/icons_cursors.sh (src/icons.sh runs it)
set -e
cd "$(dirname "$0")/.."
art=assets/art/cursors
out=src/icons/os_cursor
mkdir -p "$out"
sheet="$art/.os_cursor.svg"
trap 'rm -f "$sheet"' EXIT
for kind in pointer move attack wall chop mine forage build; do
	case "$kind" in
		pointer | move | attack | wall) body="<image href=\"$kind.svg\" width=\"32\" height=\"32\"/>" ;;
		*) body="<image href=\"$kind.svg\" x=\"7\" y=\"7\" width=\"32\" height=\"32\"/><image href=\"pointer.svg\" width=\"16\" height=\"16\"/>" ;;
	esac
	echo "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 40 40\">$body</svg>" > "$sheet"
	rsvg-convert -w 26 -h 26 "$sheet" -o "$out/$kind.png"
	rsvg-convert -w 52 -h 52 "$sheet" -o "$out/$kind@2x.png"
done
