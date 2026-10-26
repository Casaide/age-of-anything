#!/bin/sh
# Play the Lobster port: tests/lobster_spike/play.sh <pack dir> [watch] [speed:<x>] [shot:<png> at:<seconds>]
# The pack dir holds the art (art_pack.gd), baked for a map and two races; the game makes the races and the
# start itself (gen/). scenario:<file> plays a scenario from export.gd instead.
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
pack="$1"
shift
start=-
for a in "$@"; do
	case "$a" in scenario:*) start=${a#scenario:} ;; esac
done
exec "$LOBSTER" --mir game.lobster -- "$pack" "$start" "$@"
