#!/bin/sh
# The match start made in Lobster (gen/setup.lobster) against export.gd's, for a few maps and races:
# the writer first (a scenario loaded and written back), then the setup itself. Run from anywhere.
cd "$(dirname "$0")"
GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
LOBSTER=${LOBSTER:-$HOME/Dev/lobster/bin/lobster}
OUT=${TMPDIR:-/tmp}/start_check
mkdir -p "$OUT"
bad=0
check() {   # name map [animals] [prompts:A|B]
	name=$1
	map=$2
	shift 2
	timeout 300 "$GODOT" --headless --path ../.. --script res://tests/lobster_spike/export.gd -- match "$map" 0 8 "$OUT/$name.txt" "$@" > "$OUT/$name.log" 2>&1
	animals=""
	mode=""
	a="sewer rats with cheese hammers"
	b="angry swamp frogs with reed spears"
	for x in "$@"; do
		case "$x" in
			animals) animals=animals ;;
			mode:*) mode=$x ;;
			prompts:*) p=${x#prompts:}; a=${p%%|*}; b=${p#*|} ;;
		esac
	done
	echo "== $name ($map $*)"
	timeout 120 "$LOBSTER" start_check.lobster -- roundtrip "$OUT/$name.txt" 2>&1 | grep -v warning 
	timeout 120 "$LOBSTER" start_check.lobster -- setup "$OUT/$name.txt" "$map" $mode $animals "$a" "$b" 2>&1 | grep -v warning 
}
check flat flat_test
check reed reed_meadow animals
check delta river_delta animals "prompts:moonbears|sneaky spider archers"
check vale siege_vale "prompts:centaur romans|tiny vikings"
check fortress reed_meadow mode:fortress animals
check siege siege_vale mode:siege "prompts:centaur romans|tiny vikings"
echo "files in $OUT"
