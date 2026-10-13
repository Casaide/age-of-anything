#!/bin/bash
# The test batch (tests/batch.gd): every suite side by side, a summary table, exit 1 on a failure.
#   tests/batch.sh            everything (~3-4 min)
#   tests/batch.sh --quick    the fast subset to run while working (~1 min)
#   tests/batch.sh jobs=6     fewer processes at once (default: performance cores - 1; or AOA_JOBS)
# GODOT overrides the Godot binary.
cd "$(dirname "$0")/.." || exit 1
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
exec timeout 3600 "$GODOT" --headless --audio-driver Dummy --path . --script res://tests/batch.gd -- "$@"
