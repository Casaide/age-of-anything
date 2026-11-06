#!/bin/sh
# Two Lobster processes, a host and one who joins, playing a match in lockstep over TCP (net_check.lobster).
# Usage: src/net_check.sh [ticks] [noscan] [people]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-4000}"
people="${3:-2}"
logs="$(mktemp -d)"
failed=0
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- host "$ticks" "players:$people" > "$logs/host" 2>&1 &
host=$!
sleep 1
n=1
while [ $n -lt $((people - 1)) ]; do
	"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan "players:$people" > "$logs/join$n" 2>&1 &
	joiners="$joiners $!"
	sleep 1
	n=$((n + 1))
done
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" $2 "players:$people" > "$logs/join" 2>&1 || failed=1
for pid in $host $joiners; do wait $pid || failed=1; done
cat "$logs"/* | grep -v warning
rm -rf "$logs"
[ $failed = 0 ] || { echo "FAILED: a side of the match stopped"; exit 1; }
