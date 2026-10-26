#!/bin/sh
# The Lobster generator against GDScript's: the same races (recipes, stats, costs, notes, keys, heroes)
# for a list of prompts, line by line. Run from tests/lobster_spike: ./race_check.sh [rules] [mods] [reroll]
cd "$(dirname "$0")"
RULES=${1:-default}
MODS=${2:-}
REROLL=${3:-0}
OUT=${TMPDIR:-/tmp}/race_check
mkdir -p "$OUT"
set -- "sewer rats with cheese hammers" "angry swamp frogs with reed spears" "centaur romans" "flying greeks with wings" \
  "sneaky spider archers" "romans riding bears" "moonbears" "polar bears" "tiny vikings" "giant red frogs with guns" \
  "spider widow" "pegasus knights" "aztec bugs" "nile cats" "han frogs on newts" "ww2 rats" "zzz qqq" "" \
  "horse people" "bat spiders with crossbows" "royal mice cavalry" "norse bears riding bears" "beetles riding hummingbirds" \
  "future soldiers" "space marines" "sewer rats from the future"
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
AOW_MODS="$MODS" AOW_REROLL="$REROLL" timeout 120 "$GODOT" --headless --path ../.. --script res://tests/lobster_spike/race_dump.gd -- "$OUT/gd.txt" "$RULES" "$@" > "$OUT/gd.log" 2>&1
timeout 120 ~/Dev/lobster/bin/lobster races.lobster -- ${MODS:+mods:$MODS} reroll:$REROLL "$RULES" "$@" 2>&1 | grep -v warning > "$OUT/lob.txt"
n=0
bad=0
while [ $n -lt $# ]; do
  n=$((n + 1))
  a=$(sed -n "${n}p" "$OUT/gd.txt")
  b=$(sed -n "${n}p" "$OUT/lob.txt")
  if [ "$a" = "$b" ]; then echo "same  $n"; else echo "DIFF  $n"; bad=$((bad + 1)); fi
done
echo "$bad of $# differ (files in $OUT)"
[ $bad -eq 0 ]
