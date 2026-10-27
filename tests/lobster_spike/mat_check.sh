#!/bin/sh
# The buildings' materials made in Lobster (model/build_mats.lobster) against Godot's (src/view/art/bake/materials.gd):
# properties exactly, textures pixel by pixel. Usage: tests/lobster_spike/mat_check.sh <out dir>
out="$1"
here="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
LOBSTER_FLAGS="${LOBSTER_FLAGS-}"   # (as the game runs it, play.sh: no --mir, D-174)
rm -rf "$out"
(cd "$here/../.." && timeout 300 "$GODOT" --headless --path . --script res://tests/lobster_spike/mat_dump.gd -- "$out" 2>&1 | grep -i "error\|materials" | head -20)
cd "$here" && timeout 300 "$LOBSTER" $LOBSTER_FLAGS mat_check.lobster -- "$out" 2>&1 | grep -v "^warning" | tail -80
