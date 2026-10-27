#!/bin/sh
# Play the Lobster port: tests/lobster_spike/play.sh <pack dir> [lobby] [watch] [speed:<x>] [shot:<png> at:<seconds>]
# The pack dir holds the art (art_pack.gd), baked for a map and two races; the game makes the races and the
# start itself (gen/). scenario:<file> plays a scenario from export.gd instead.
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
mkdir -p bake_cache   # (parts baked once are kept here: view/part_bake.lobster)
pack="$1"
shift
start=-
for a in "$@"; do
	case "$a" in
		scenario:*) start=${a#scenario:} ;;
		lobby) start=lobby ;;   # the lobby: type the races (or races:A|B), pick the map and mode
	esac
done
# The mods asked for (mods:a,b or AOW_MODS) bring their Lobster models in before the game compiles (mods_gen.lobster).
mods="$AOW_MODS"
for a in "$@"; do
	case "$a" in
		mods:*) mods=${a#mods:} ;;
	esac
done
"$LOBSTER" mods_gen.lobster -- $(echo "$mods" | tr ',' ' ') | grep -v warning
# (Lobster's window never takes Ctrl-C, so the script does: it stops the game.)
"$LOBSTER" $LOBSTER_FLAGS game.lobster -- "$pack" "$start" "$@" &
game=$!
trap 'kill -9 $game 2>/dev/null' INT TERM
wait $game
