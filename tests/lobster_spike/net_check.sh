#!/bin/sh
# Two Lobster processes, a host and one who joins, playing a match in lockstep over TCP (net_check.lobster).
# Usage: tests/lobster_spike/net_check.sh [ticks] [noscan] [people]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-4000}"
people="${3:-2}"
"$LOBSTER" --mir net_check.lobster -- host "$ticks" "players:$people" 2>&1 | grep -v warning &
sleep 1
n=1
while [ $n -lt $((people - 1)) ]; do
	"$LOBSTER" --mir net_check.lobster -- join "$ticks" noscan "players:$people" 2>&1 | grep -v warning &
	sleep 1
	n=$((n + 1))
done
"$LOBSTER" --mir net_check.lobster -- join "$ticks" $2 "players:$people" 2>&1 | grep -v warning
wait
