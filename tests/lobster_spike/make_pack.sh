#!/bin/sh
# Build the Lobster game's match pack: the starting state (export.gd) and the art (art_pack.gd, a
# Godot window for a minute or so). Usage: tests/lobster_spike/make_pack.sh [map] (default flat_test)
# Then: tests/lobster_spike/play.sh tests/lobster_spike/pack
set -e
cd "$(dirname "$0")/../.."
map="${1:-flat_test}"
out="tests/lobster_spike/pack"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
mkdir -p "$out"
"$GODOT" --headless --path . --script res://tests/lobster_spike/export.gd -- match "$map" 0 0 "$PWD/$out/scenario.txt" | grep -E '^(match|ported)'
"$GODOT" --path . --audio-driver Dummy --always-on-top --script res://tests/lobster_spike/art_pack.gd -- "$PWD/$out" "$map" | grep -E '^(baked|pack)'
