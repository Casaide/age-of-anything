#!/bin/sh
# Play the Lobster port: tests/lobster_spike/play.sh <pack dir> [watch] [speed:<x>] [shot:<png> at:<seconds>]
# The pack dir holds the art (art_pack.gd) and scenario.txt (export.gd match <map> 0 0 <pack>/scenario.txt).
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
pack="$1"
shift
exec "$LOBSTER" --mir game.lobster -- "$pack" "$pack/scenario.txt" "$@"
