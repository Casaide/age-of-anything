#!/bin/sh
# A mod's icons (mods/<id>/art/icons/*.svg, e.g. res_<good>.svg for its goods) as PNGs at twice their size in its
# data (mods/<id>/data/icons), where the HUD finds them (Creel's icon_file, #141). Needs rsvg-convert.
# Usage: tools/mods/icons.sh <id>
set -e
cd "$(dirname "$0")/../.."
mod=mods/$1
mkdir -p "$mod/data/icons"
for f in "$mod"/art/icons/*.svg; do
	n=${f##*/}
	rsvg-convert -z 2 "$f" -o "$mod/data/icons/${n%.svg}.png"
done
