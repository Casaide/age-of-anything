#!/bin/sh
# The voxelizer (view/geom.lobster) against Godot's (geom.gd) on every part of each race asked for.
# Usage: tests/lobster_spike/geom_check.sh <out dir> "<prompt>"...
out="$1"; shift
here="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
mkdir -p "$out"
n=0
for prompt in "$@"; do
	n=$((n + 1))
	(cd "$here/../.." && timeout 300 "$GODOT" --headless --path . --script res://tests/lobster_spike/geom_dump.gd -- "$out/g$n.json" "$prompt" > /dev/null 2>&1)
	echo "== $prompt"
	(cd "$here" && timeout 600 "$LOBSTER" ${LOBSTER_FLAGS-} geom_check.lobster -- "$out/g$n.json" "$prompt" 2>&1 | grep -v "warning")
done
