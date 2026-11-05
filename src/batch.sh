#!/bin/sh
# The game's tests side by side, a table of them, exit 1 on any failure. Slow suites are split into shards (each its own
# process, its own seeded worlds, so the results are a serial run's).
#   ./batch.sh [--quick] [jobs=N] [only=name,name]
# --quick: the checks to run after a change (unit tests, the sim, the counter chain, the AI's quick checks, the voxel
# units' checks); the whole batch adds every AI piece, the 2v2 match, the golden files, the prices' round robins, saves and network play.
# jobs: processes at once (AOA_JOBS; default 4, so a run doesn't take every core: Dominic's fans).
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
quick=0
jobs="${AOA_JOBS:-4}"
only=""
for a in "$@"; do
	case "$a" in
		--quick) quick=1 ;;
		jobs=*) jobs="${a#jobs=}" ;;
		only=*) only="${a#only=}" ;;
	esac
done
logs="${TMPDIR:-/tmp}/aoa_batch"
rm -rf "$logs"
mkdir -p "$logs"
list="$logs/jobs.txt"
: > "$list"
add() {   # add <name> <command...>
	name="$1"
	shift
	if [ -n "$only" ] && ! echo ",$only," | grep -q ",${name%%.*},"; then return; fi
	echo "$name|$*" >> "$list"
}
L="$LOBSTER"
add run_tests "$L" run_tests.lobster
add lint ./lint.sh   # lobsterfmt leaves every file as it is, every program compiles with no warnings
add test_heroes "$L" test_heroes.lobster
add race_identity "$L" test_race_identity.lobster
add voxel_contact "$L" voxel_proto.lobster -- - check   # the voxel units stand in their shadows as drawn (the voxels option)
add voxel_check "$L" voxel_check.lobster                # the voxel units' art: straight standing knees, skins that never clip or grey, kit that keeps the creature's shape, no look-alikes, no specks
for i in 0 1 2 3; do add test_sim.$i "$L" test_sim.lobster -- shard:$i/4; done
for a in 2 3; do add counters.$a "$L" calibrate.lobster -- pairs $a; done   # the counter chain, each pair in ages 2 and 3 (D-200)
if [ $quick = 1 ]; then
	add test_ai "$L" test_ai.lobster -- quick
else
	for i in 0 1 2 3; do add test_ai.$i "$L" test_ai.lobster -- shard:$i/4; done
	add test_2v2 "$L" test_2v2.lobster
	add test_mod_match "$L" test_mod_match.lobster
	add golden ./golden.sh
	add vbcheck "$L" game.lobster -- none - vbcheck mute   # every building look as voxels: no specks (a window, but quick)
	add prices "$L" calibrate.lobster -- measure expect check:42   # held-out round robins against the counter chain (D-199): 32% off now
	add saves "$L" save_check.lobster
	add network ./net_check.sh 2000
	# The drawing's cost in the real window, vsync on (game/perf.lobster): wall time, so it runs alone after the rest.
	add perf timeout 240 ../play.sh lobby "\"races:sewer rats|romans\"" watch mute perf:20
fi

# Run them, at most $jobs at once (xargs keeps the pool full); each line of jobs.txt: name|command. The slow suites go
# first so the quick ones fill in round them.
t0=$(date +%s)
{ grep '^test_ai\.\|^test_2v2\|^golden' "$list"; grep -v '^test_ai\.\|^test_2v2\|^golden\|^perf' "$list"; } | tr '\n' '\0' |
	xargs -0 -P "$jobs" -n 1 sh -c 'line="$0"; name="${line%%|*}"; cmd="${line#*|}"; start=$(date +%s); sh -c "$cmd" > "'"$logs"'/$name.log" 2>&1; echo "$name $? $(( $(date +%s) - start ))" > "'"$logs"'/$name.result"'

# The ones that measure wall time, alone once the pool is done.
grep '^perf' "$list" | while IFS='|' read -r name cmd; do
	start=$(date +%s)
	sh -c "$cmd" > "$logs/$name.log" 2>&1
	echo "$name $? $(( $(date +%s) - start ))" > "$logs/$name.result"
done

# The table: each suite (its shards together), its time, and the last line it printed.
fail=0
printf '%-16s %-6s %6s  %s\n' suite result secs summary
for name in $(cut -d'|' -f1 "$list" | sed 's/\.[0-9]*$//' | uniq); do
	code=0
	secs=0
	for r in "$logs/$name".result "$logs/$name".[0-9]*.result; do
		[ -f "$r" ] || continue
		set -- $(cat "$r")
		[ "$2" != 0 ] && code=$2
		[ "$3" -gt "$secs" ] && secs=$3
	done
	summary=$(cat "$logs/$name".log "$logs/$name".[0-9]*.log 2>/dev/null | grep -v -i "warning\|extra references\|leaks\|^  \|^$" | tail -1 | cut -c1-70)
	if [ "$code" = 0 ]; then result=ok; else result=FAIL; fail=1; fi
	printf '%-16s %-6s %6s  %s\n' "$name" "$result" "$secs" "$summary"
done
echo "all in $(( $(date +%s) - t0 )) s, $jobs at once; logs in $logs"
rm -f memory_leaks.txt
exit $fail
