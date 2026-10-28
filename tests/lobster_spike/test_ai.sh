#!/bin/sh
# test_ai.lobster in n processes side by side (each runs every n-th piece: shard:i/n), their logs in order,
# then the checks across pieces (bot vs bot twice the same, healers heal) and the total. Exit 1 on a failure.
# Usage (any folder): tests/lobster_spike/test_ai.sh [map_id] [mode] [jobs=N]   (jobs: performance cores - 1 by default)
cd "$(dirname "$0")" || exit 1
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
n=$(( $(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo 4) - 1 ))
args=""
for a in "$@"; do
	case "$a" in
		jobs=*) n="${a#jobs=}" ;;
		*) args="$args $a" ;;
	esac
done
[ "$n" -ge 1 ] || n=1
logs=".test_ai_logs.$$"
mkdir -p "$logs"
i=0
while [ $i -lt "$n" ]; do
	timeout 1800 "$LOBSTER" test_ai.lobster -- $args "shard:$i/$n" > "$logs/$i.log" 2>&1 &
	i=$((i + 1))
done
wait
i=0
while [ $i -lt "$n" ]; do
	echo "== shard $i/$n"
	grep -v ": warning: " "$logs/$i.log" | grep -v "^@@ " | grep -v " passed, .* failed$"
	i=$((i + 1))
done
"$LOBSTER" test_ai.lobster -- combine "$logs"/*.log > "$logs/combine.out" 2>&1
code=$?
grep -v ": warning: " "$logs/combine.out"
rm -rf "$logs"
exit $code
