#!/bin/sh
# A mod's match starts in the real window (#64): its buildings and units bake, the match draws, one picture is
# taken and the game quits. Fails on a VM error (#58: a building with no model stopped the start) or no picture.
#   src/mod_start_check.sh [bake options]
cd "$(dirname "$0")/.." || exit 1
pic="${TMPDIR:-/tmp}/steading_start.png"
rm -f "$pic"
./play.sh lobby mods:steading rules:steading "races:villagers|villagers" mute novsync shot:"$pic" at:6 "$@" || { echo "FAIL: steading: the match didn't start"; exit 1; }
[ -s "$pic" ] || { echo "FAIL: steading: no picture of the match"; exit 1; }
echo "steading: the match starts and draws"
