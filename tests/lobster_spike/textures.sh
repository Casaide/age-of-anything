#!/bin/sh
# The model kit's textures (step 6d): every authored SVG texture (assets/art/textures/, and each mod's textures/)
# as a PNG at scale 1 beside the Lobster port, which can't read SVG. Run again after a texture changes. Needs
# rsvg-convert; within 1.5 levels on average of Godot's rasteriser (tex_png.gd, which this replaces).
# Usage: tests/lobster_spike/textures.sh
set -e
cd "$(dirname "$0")/../.."
out=tests/lobster_spike/textures
mkdir -p "$out"
n=0
for f in assets/art/textures/*.svg; do
	rsvg-convert "$f" -o "$out/$(basename "${f%.svg}").png"
	n=$((n + 1))
done
for d in mods/*/textures; do
	[ -d "$d" ] || continue
	m=$(basename "$(dirname "$d")")
	mkdir -p "$out/$m"
	for f in "$d"/*.svg; do
		[ -f "$f" ] || continue
		rsvg-convert "$f" -o "$out/$m/$(basename "${f%.svg}").png"
		n=$((n + 1))
	done
done
echo "$n textures"
