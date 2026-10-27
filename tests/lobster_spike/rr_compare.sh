#!/bin/sh
# One round-robin fight in GDScript and in Lobster, state hash tick by tick: the first tick they part.
# Usage (from anywhere): tests/lobster_spike/rr_compare.sh <age> <a> <b> [dump tick]
cd "$(dirname "$0")"
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
LOBSTER=${LOBSTER:-$HOME/Dev/lobster/bin/lobster}
OUT=${TMPDIR:-/tmp}/rr_compare
mkdir -p "$OUT"
timeout 300 "$GODOT" --headless --path ../.. --script res://tests/lobster_spike/rr_hash.gd -- "$@" > "$OUT/gd.txt" 2>&1
timeout 300 "$LOBSTER" $LOBSTER_FLAGS balance.lobster -- hash "$@" > "$OUT/lob.txt" 2>&1
rm -f memory_leaks.txt
grep "^h " "$OUT/gd.txt" > "$OUT/gd.h"
grep "^h " "$OUT/lob.txt" > "$OUT/lob.h"
echo "ticks: $(wc -l < "$OUT/gd.h") GDScript, $(wc -l < "$OUT/lob.h") Lobster"
diff "$OUT/gd.h" "$OUT/lob.h" | head -4
echo "files in $OUT"
