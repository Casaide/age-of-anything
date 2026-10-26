#!/bin/sh
# Two Lobster processes, a host and one who joins, playing a match in lockstep over TCP (net_check.lobster).
# Usage: tests/lobster_spike/net_check.sh [ticks]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-4000}"
"$LOBSTER" --mir net_check.lobster -- host "$ticks" 2>&1 | grep -v warning &
sleep 1
"$LOBSTER" --mir net_check.lobster -- join "$ticks" 2>&1 | grep -v warning
wait
