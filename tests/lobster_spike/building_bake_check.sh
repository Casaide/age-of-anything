#!/bin/sh
# The buildings baked in Lobster (game/art_kit_buildings.lobster) against the library's Godot bakes, frame for frame,
# and their fx against fx.txt. Usage: tests/lobster_spike/building_bake_check.sh <out prefix> [arch...]
#   (pictures: <out prefix>0.png, 1.png...; no archs: thatch junk stone tent reed mound)
here="$(cd "$(dirname "$0")" && pwd)"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$here" && timeout 1800 "$LOBSTER" building_bake_check.lobster -- "$@" 2>&1 | grep -v "warning"
