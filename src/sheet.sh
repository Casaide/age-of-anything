#!/bin/sh
# The concept sheet tool in Lobster (sheet.lobster): src/sheet.sh tests/sheets/<spec>.json <out dir> [sheet,...|all] [zoom,...|all] [nocheck] [cache:<dir>]
# Makes the out dir (Lobster can't), brings the spec's mods' Lobster models in for the run (mods_gen.lobster) and
# puts them back after. Silent: the sheet plays no sound.
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
spec="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
mkdir -p "$2"
out="$(cd "$2" && pwd)"
shift 2
cd "$(dirname "$0")"
. ./bake_cache.sh
mods=$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1])).get("mods", [])))' "$spec")
[ -n "$mods" ] && "$LOBSTER" mods_gen.lobster -- $mods | grep -v warning
"$LOBSTER" sheet.lobster -- "$spec" "$out" "$@"
code=$?
[ -n "$mods" ] && "$LOBSTER" mods_gen.lobster | grep -v warning
exit $code
