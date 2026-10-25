#!/bin/sh
# The Lobster sim spike: export a scenario from the GDScript sim, then play it in the Lobster port.
# Usage: tests/lobster_spike/run.sh <out dir> <map> <units per player> <ticks>
# Needs LOBSTER (default ~/Dev/lobster/bin/lobster) and GODOT (default the macOS app).
set -e
out="$1"
map="$2"
per="$3"
ticks="$4"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
file="$out/${map}_$((per * 2))_$ticks.txt"
mkdir -p "$out"
echo "== $map, $((per * 2)) units, $ticks ticks"
timeout 1800 "$GODOT" --headless --path . --script res://tests/lobster_spike/export.gd -- "$map" "$per" "$ticks" "$file" | grep -E '^(map|whole|movement)'
"$LOBSTER" tests/lobster_spike/sim.lobster -- "$file" | grep -v warning
