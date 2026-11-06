#!/bin/sh
# Play the game: src/play.sh [lobby] [watch] [windowed] [speed:<x>] [shot:<png> at:<seconds>]
# Filming (tools/film/take.sh): record:<dir> from:<s> for:<s> fps:<n> clean window:<w>,<h> push:<k> pan:<x>,<y> (src/game.lobster says each)
# The game makes the races and the start itself (gen/); scenario:<file> plays a scenario file instead.
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
. ./bake_cache.sh   # (buildings, props and voxel units baked once are kept in bake_cache/: emptied when the bake version changes)
# (the game's first word was a Godot art pack's folder: gone with Godot, D-184; "none", or skipped)
if [ $# -gt 0 ] && { [ "$1" = none ] || [ -d "$1" ]; }; then
	pack="$1"
	shift
else
	pack=none
fi
start=-
for a in "$@"; do
	case "$a" in
		scenario:*) start=${a#scenario:} ;;
		lobby) start=lobby ;;   # the lobby: type the races (or races:A|B), pick the map and mode
	esac
done
# (Lobster's window never takes Ctrl-C, so the script does: it stops the game.)
"$LOBSTER" $LOBSTER_FLAGS game.lobster -- "$pack" "$start" "$@" &
game=$!
trap 'kill -9 $game 2>/dev/null' INT TERM
wait $game
