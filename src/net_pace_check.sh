#!/bin/sh
# Two Lobster processes in lockstep, paced as the game is, the joiner loading late (net_pace_check.lobster, #151 in Creel).
# Usage: src/net_pace_check.sh [ticks] [late seconds]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-300}"
late="${2:-2}"
port=47833
logs="$(mktemp -d)"
failed=0
"$LOBSTER" $LOBSTER_FLAGS net_pace_check.lobster -- host "$ticks" "port:$port" > "$logs/host" 2>&1 &
host=$!
sleep 1
"$LOBSTER" $LOBSTER_FLAGS net_pace_check.lobster -- join "$ticks" noscan "port:$port" "late:$late" > "$logs/join" 2>&1 || failed=1
wait $host || failed=1
cat "$logs"/* | grep -v warning
rm -rf "$logs"
[ $failed = 0 ] || { echo "FAILED: net_pace_check"; exit 1; }
