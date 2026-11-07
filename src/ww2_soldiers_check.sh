#!/bin/sh
# The WW2 mod's two sides are their own soldiers: a GI and a German, with nothing from the base game's kit on the riflemen (#264). Silent.
#   src/ww2_soldiers_check.sh
cd "$(dirname "$0")" || exit 1
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
out="$("$LOBSTER" races.lobster -- mods:ww2 ww2_duel sherman panzer 2>/dev/null | grep '^{')"
bad=0
say() { echo "ww2 soldiers: $*"; }
want() { [ "$2" = "$3" ] || { say "$1: $2, wanted $3"; bad=1; }; }
creatures="$(printf '%s\n' "$out" | jq -r .creature | tr '\n' ' ')"
want "the two sides' soldiers" "$creatures" "gi_1944 landser_1944 "
foreign="$(printf '%s\n' "$out" | jq -r '.units[].recipe | select(.parts.hand_r == "weapon.flak") | .parts | to_entries[] | select(.value | test("ww2|flak") | not) | .value' | sort -u | tr '\n' ' ')"
want "kit from outside the mod on the riflemen" "$foreign" ""
for b in gi_1944 landser_1944; do
	f="../mods/ww2/data/voxel/bodies/$b.json"
	[ -f "$f" ] || { say "no body $b"; bad=1; continue; }
	roman="$(jq -r '[.shapes[] | select(.mat == "kilt" or .mat == "bronze")] | length' "$f")"
	want "$b's Roman stuff" "$roman" "0"
done
rifle="$(jq -r '.tools.ww2_rifle // ""' ../mods/ww2/data/voxel/bodies/landser_1944.json 2>/dev/null)"
want "the German's rifle" "$rifle" "ww2_kar98k"
[ "$bad" = 0 ] && say "a GI and a German, in their own kit"
exit "$bad"
