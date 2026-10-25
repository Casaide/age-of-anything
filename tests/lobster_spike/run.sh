#!/bin/sh
# The Lobster sim spike: export a scenario from the GDScript sim, then play it in the Lobster port.
# Usage: tests/lobster_spike/run.sh <out dir> <move|fight> <map> <units per player> <ticks>
# Needs LOBSTER (default ~/Dev/lobster/bin/lobster) and GODOT (default the macOS app).
set -e
out="$1"
mode="$2"
map="$3"
per="$4"
ticks="$5"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
file="$out/${mode}_${map}_$((per * 2))_$ticks.txt"
mkdir -p "$out"
echo "== $mode, $map, $((per * 2)) units, $ticks ticks"
timeout 3600 "$GODOT" --headless --path . --script res://tests/lobster_spike/export.gd -- "$mode" "$map" "$per" "$ticks" "$file" | grep -E '^(move|fight|whole|ported)'
"$LOBSTER" --mir tests/lobster_spike/sim.lobster -- "$file" | grep -v warning
if [ "$mode" = eco ] || [ "$mode" = match ]; then
	echo "-- the same, the bots playing in Lobster:"
	"$LOBSTER" --mir tests/lobster_spike/sim.lobster -- "$file" bots | grep -v warning
fi
