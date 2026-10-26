#!/bin/sh
# The parts built in Lobster (model/) against Godot's (mesh_export.gd race mode), triangle for triangle.
# Usage: tests/lobster_spike/model_check.sh <out dir> "<prompt>" <part id>...
out="$1"; prompt="$2"; shift 2
here="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
rm -rf "$out"
(cd "$here/../.." && timeout 300 "$GODOT" --headless --path . --script res://tests/lobster_spike/mesh_export.gd -- "$out" "$prompt" "$@" 2>&1 | grep -i "skip\|error" | head -20)
cd "$here" && timeout 300 "$LOBSTER" model_check.lobster -- "$out" "$prompt" "$@" 2>&1 | grep -v "^warning" | tail -80
