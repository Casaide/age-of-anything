#!/bin/sh
# Plays every exported scenario in a folder in the Lobster port, with the default JIT and --mir.
# Usage: tests/lobster_spike/time_lobster.sh <folder of scenario .txt files>
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
for f in "$1"/*_*_*.txt; do
	echo "-- $(basename "$f")"
	echo "tcc: $("$LOBSTER" tests/lobster_spike/sim.lobster -- "$f" | grep -E 'step|hashes' | tr '\n' ' ')"
	echo "mir: $("$LOBSTER" --mir tests/lobster_spike/sim.lobster -- "$f" | grep -E 'step|hashes' | tr '\n' ' ')"
done
