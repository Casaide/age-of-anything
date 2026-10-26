#!/bin/sh
# Build the Lobster game's match pack: the starting state (export.gd) and the art (art_pack.gd, a
# Godot window for a minute or so). Usage: tests/lobster_spike/make_pack.sh [map] ["your race" "their race"]
# (default flat_test, rats v frogs). Then: tests/lobster_spike/play.sh tests/lobster_spike/pack
set -e
cd "$(dirname "$0")/../.."
map="${1:-flat_test}"
a="${2:-sewer rats with cheese hammers}"
b="${3:-angry swamp frogs with reed spears}"
out="tests/lobster_spike/pack"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
mkdir -p "$out"
"$GODOT" --headless --path . --script res://tests/lobster_spike/export.gd -- match "$map" 0 0 "$PWD/$out/scenario.txt" animals "prompts:$a|$b" | grep -E '^(match|ported)'
"$GODOT" --path . --audio-driver Dummy --always-on-top --script res://tests/lobster_spike/art_pack.gd -- "$PWD/$out" "$map" "$a" "$b" | grep -E '^(baked|pack)'
"$GODOT" --headless --path . --script res://tests/lobster_spike/building_fx.gd -- "$PWD/$out" | grep -E '^building fx'
