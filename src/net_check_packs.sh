#!/bin/sh
# Packs must match in a network match: a joiner without the host's mod is turned away by name, then one with it plays.
# Usage: src/net_check_packs.sh [ticks]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-300}"
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- host "$ticks" mods:scifi_test 2>&1 | grep -v warning &
sleep 1
out="$("$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan refused 2>&1 | grep -v warning)"
echo "$out"
case "$out" in
	*"join: refused: this host plays with the mod scifi_test"*) ;;
	*) echo "FAILED: the joiner without the mod wasn't refused by name"; kill %1 2>/dev/null; exit 1 ;;
esac
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan mods:scifi_test 2>&1 | grep -v warning
wait
echo "packs: refused without the mod, played with it"
