#!/bin/sh
# A Lobster tool in n processes side by side: each runs every n-th piece (its argument shard:i/n), their
# logs are printed in order, then `<tool> -- combine <logs>` makes what spans the pieces (tables, checks,
# the total). Exits with the combine's code. For test_ai, race_matches, mass_battle (anything that takes
# shard:i/n and combine).
# Usage (any folder): src/shards.sh <tool.lobster> [args...] [jobs=N]
#   jobs: performance cores - 1 by default. Each process has a 30-minute timeout.
cd "$(dirname "$0")" || exit 1
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
. ./machine_lock.sh
lock_on_exit
lock_take full "shards.sh $*"   # (as many processes as there are performance cores, less one: one such run at a time, #242)
tool="$1"
shift
n=$(( $(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo 4) - 1 ))
args=""
for a in "$@"; do
	case "$a" in
		jobs=*) n="${a#jobs=}" ;;
		*) args="$args $a" ;;   # (no spaces inside an argument: prompts go in with underscores, see the tool)
	esac
done
[ "$n" -ge 1 ] || n=1
logs=".shards.$$"
mkdir -p "$logs"
i=0
while [ $i -lt "$n" ]; do
	timeout 1800 "$LOBSTER" "$tool" -- $args "shard:$i/$n" > "$logs/$i.log" 2>&1 &
	i=$((i + 1))
done
wait
i=0
while [ $i -lt "$n" ]; do
	echo "== shard $i/$n"
	grep -v ": warning: " "$logs/$i.log" | grep -v "^@@" | grep -v " passed, .* failed$"
	i=$((i + 1))
done
"$LOBSTER" "$tool" -- $args combine "$logs"/*.log > "$logs/combine.out" 2>&1
code=$?
grep -v ": warning: " "$logs/combine.out"
rm -rf "$logs"
exit $code
