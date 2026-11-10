#!/bin/sh
# The game's tests side by side, a table of them, exit 1 on any failure. Slow suites are split into shards (each its own
# process, its own seeded worlds, so the results are a serial run's).
#   ./batch.sh [--quick] [jobs=N] [only=name,name]
# --quick: the checks to run after a change (unit tests, the sim, the counter chain, the AI's quick checks, the voxel
# units' checks); the whole batch adds every AI piece, the 2v2 match, the golden files, the prices' round robins, saves and network play.
# jobs: processes at once (AOA_JOBS; default 4, so a run doesn't take every core: Dominic's fans).
# One batch at a time on this machine (machine_lock.sh, #242): a whole batch takes the full lane, and waits for another
# whole batch, in any worktree; --quick and only= take the quick lane, so they don't wait a whole batch to check one change.
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
quick=0
jobs="${AOA_JOBS:-4}"
limit="${AOA_JOB_LIMIT:-900}"   # seconds a job may take: past that it's stuck, and fails (#294; a cold bake takes minutes)
only=""
for a in "$@"; do
	case "$a" in
		--quick) quick=1 ;;
		jobs=*) jobs="${a#jobs=}" ;;
		only=*) only="${a#only=}" ;;
	esac
done
. ./machine_lock.sh
lock_on_exit
if [ $quick = 1 ] || [ -n "$only" ]; then lane=quick; else lane=full; fi
lock_take $lane "batch.sh $*"
# Each run has a folder of its own (#229), and its jobs' temporary files go there too. Runs over two days old go.
find "${TMPDIR:-/tmp}/" -maxdepth 1 -name 'aoa_batch.*' -mtime +2 -exec rm -rf {} + 2>/dev/null
logs="$(mktemp -d "${TMPDIR:-/tmp}/aoa_batch.XXXXXX")"
mkdir "$logs/tmp"
export TMPDIR="$logs/tmp"
list="$logs/jobs.txt"
: > "$list"
add() {   # add <name> <command...>
	name="$1"
	shift
	if [ -n "$only" ] && ! echo ",$only," | grep -q ",${name%%.*},"; then return; fi
	echo "$name|$*" >> "$list"
}
L="$LOBSTER"
bakes=cache:../build/bake_store   # (the same path everywhere: a bake's record names its own files by it)
add run_tests "$L" run_tests.lobster
add lint ./lint.sh   # lobsterfmt leaves every file as it is, every program compiles with no warnings
add runner ./batch_test.sh   # this runner's own tests: a run keeps its own results, a job with none is a failure (#229), the lock across worktrees (#242)
add test_heroes "$L" test_heroes.lobster
add race_identity "$L" test_race_identity.lobster
add voxel_contact "$L" voxel_proto.lobster -- - check   # the voxel units stand in their shadows as drawn (the voxels option)
add test_formations "$L" test_formations.lobster  # big armies in formation, headless: drift, jitter, facing, overlap, the framed map
add test_movement "$L" test_movement.lobster  # group moves, headless: sway, flicker, overlap, settling (every scene, #344)
add test_shot_look "$L" test_shot_look.lobster  # shots look faster and land when they always did
add voxel_check "$L" voxel_check.lobster                # the voxel units' art: straight standing knees, skins that never clip or grey, kit that keeps the creature's shape, no look-alikes, no specks
add vox_check "$L" vox_check.lobster                    # the .vox reader (#313): models, palette, MATL, the scene graph, broken files
add vox_model_check "$L" vox_model_check.lobster        # .vox models as a shape (#313): placement, mirror, facings, materials, the bake key
add vox_body_check "$L" vox_body_check.lobster          # a body from a .vox (#313): joints from the drawing, points layer, the walk, standing on its legs, bad files named
add vox_mod_check "$L" vox_mod_check.lobster            # the example .vox mod (#381): loads with its model, its word gives its creature, its body from the .vox
add size_check "$L" size_check.lobster                  # the one size table (data/voxel/sizes.json): every body as tall as it says, every mount at its ratio
add rider_check "$L" rider_check.lobster                # riders and crews as drawn: every pair a race can field, showing, one on a seat, in the size table's ratios
add walk_check "$L" walk_check.lobster                  # feet against the ground (#422): a planted foot goes back as far as the walk cycle covers, at a steady speed, for every body and mount
add voxel_parts "$L" voxel_proto.lobster -- - parts test.turret voxels:../tests/voxel/parts   # a part stays on its hull in every pair of facings
add voxel_parts_twin "$L" voxel_proto.lobster -- - parts test.twin voxels:../tests/voxel/parts   # two turrets on one hull
add voxel_bodies "$L" voxel_proto.lobster -- - bodies voxels:../tests/voxel/parts $(for d in ../mods/*/data/voxel; do [ -d "$d" ] && printf "voxels:%s " "$d"; done)   # every body in every pack draws, its parts stay on it
add voxel_aim "$L" voxel_proto.lobster -- - aim voxels:../mods/ww2/data/voxel   # a rifle stays up through the firing cycle and kicks (#261)
add ww2_soldiers ./ww2_soldiers_check.sh   # the WW2 mod's sides are a GI and a German, in their own kit (#264)
add voxel_falls "$L" voxel_proto.lobster -- - falls voxels:../mods/ww2/data/voxel voxels:../mods/scifi_test/data/voxel   # a soldier crumples as it dies (#263)
for i in 0 1 2 3; do add test_sim.$i "$L" test_sim.lobster -- shard:$i/4; done
for a in 2 3; do add counters.$a "$L" calibrate.lobster -- pairs $a; done   # the counter chain, each pair in ages 2 and 3 (D-200)
if [ $quick = 1 ]; then
	add test_ai "$L" test_ai.lobster -- quick
else
	for i in 0 1 2 3; do add test_ai.$i "$L" test_ai.lobster -- shard:$i/4; done
	add test_2v2 "$L" test_2v2.lobster
	add test_mod_match "$L" test_mod_match.lobster
	add test_units_plain "$L" test_units_plain.lobster
	add test_hooks "$L" test_hooks.lobster
	add air_click ./air_check.sh "$bakes" novsync   # a click takes an aircraft where it's drawn
	add golden ./golden.sh
	for i in 0 1 2 3; do add vbcheck.$i "$L" --background game.lobster -- none - vbcheck mute novsync shard:$i/4; done   # every building look as voxels: no specks (a window each, behind the others; no vsync, which never comes with the display asleep, #294)
	add cursor_check "$L" cursor_check.lobster   # the OS cursors in a real window (#222)
	if [ "$(uname)" = Darwin ]; then add mac_app ../tests/mac_app_check.sh; fi   # the Mac app bundle: games category, name, icon, the binary inside (#224)
	add prices "$L" calibrate.lobster -- measure expect check:42   # held-out round robins against the counter chain (D-199): 32% off now
	add saves "$L" save_check.lobster
	add network ./net_check.sh 2000
	add network_packs ./net_check_packs.sh
	# The drawing's cost in the real window, vsync on (game/perf.lobster): wall time, so it runs alone after the rest.
	add perf ../play.sh lobby "\"races:sewer rats|romans\"" watch mute perf:20 "$bakes"
	add perf_big ../play.sh lobby mods:big_battle mute perf:90 "$bakes"
fi
if [ ! -s "$list" ]; then
	echo "batch: no tests to run (only=$only)"
	exit 1
fi
# The art the windowed jobs bake is kept for every worktree (#245): a fresh worktree needn't bake it all again. Old
# versions go after three days, and a version past 4 GB starts again, so it stays small (whole folders: a look's files go
# together). They reach it through a link, as the game takes a relative path. Only a run with such a job touches any of it.
if grep -q "$bakes" "$list"; then
	store="${XDG_CACHE_HOME:-$HOME/.cache}/aoa-bakes"
	version="$(sed -n 's/^let BAKE_VERSION = \([0-9]*\).*/\1/p' view/bake_cache.lobster)"
	mkdir -p "$store/$version" ../build
	find "$store" -mindepth 1 -maxdepth 1 ! -name "$version" -mtime +3 -exec rm -rf {} +
	if [ "$(du -sk "$store/$version" | cut -f1)" -gt 4000000 ]; then
		rm -rf "$store/$version"
		mkdir "$store/$version"
	fi
	ln -sfn "$store/$version" ../build/bake_store
fi

# Run them, at most $jobs at once (xargs keeps the pool full); each line of jobs.txt: name|command. The slowest go first,
# as measured, so the quick ones fill in round them and nothing long starts late.
slowest='^vbcheck\.\|^voxel_contact\|^test_mod_match\|^test_ai\|^test_formations\|^prices\|^air_click\|^test_2v2\|^test_sim\|^golden'
t0=$(date +%s)
{ grep "$slowest" "$list"; grep -v "$slowest\\|^perf" "$list"; } | tr '\n' '\0' |
	xargs -0 -P "$jobs" -n 1 sh -c 'line="$0"; name="${line%%|*}"; cmd="${line#*|}"; start=$(date +%s); timeout -k 5 "'"$limit"'" sh -c "$cmd" > "'"$logs"'/$name.log" 2>&1; echo "$name $? $(( $(date +%s) - start ))" > "'"$logs"'/$name.result"'

# The ones that measure wall time, alone once the pool is done, and with no quick batch beside them.
if grep -q '^perf' "$list"; then lock_take quick "batch.sh perf"; fi
# (Vsync on, as the player has it, unless the display is asleep: then it never comes, and the frame cap paces them, #294.)
grep '^perf' "$list" | while IFS='|' read -r name cmd; do
	if system_profiler SPDisplaysDataType 2> /dev/null | grep -q 'Display Asleep: Yes'; then cmd="$cmd novsync"; fi
	start=$(date +%s)
	timeout -k 5 "$limit" sh -c "$cmd" > "$logs/$name.log" 2>&1
	echo "$name $? $(( $(date +%s) - start ))" > "$logs/$name.result"
done

# The table: each suite (its shards together), its time, and the last line it printed.
fail=0
printf '%-16s %-6s %6s  %s\n' suite result secs summary
for name in $(cut -d'|' -f1 "$list" | sed 's/\.[0-9]*$//' | uniq); do
	code=0
	secs=0
	missing=0
	for job in $(cut -d'|' -f1 "$list" | grep "^$name\(\.[0-9]*\)\{0,1\}$"); do   # (every job asked for: one with no result is a failure, #229)
		if [ ! -f "$logs/$job.result" ]; then
			code=1
			missing=$((missing + 1))
			continue
		fi
		set -- $(cat "$logs/$job.result")
		[ "$2" != 0 ] && code=$2
		[ "$3" -gt "$secs" ] && secs=$3
	done
	summary=$(cat "$logs/$name".log "$logs/$name".[0-9]*.log 2>/dev/null | grep -v -i "warning\|extra references\|leaks\|^  \|^$" | tail -1 | cut -c1-70)
	[ "$missing" = 0 ] || summary="no result from $missing of its jobs (killed?)"
	if [ "$code" = 0 ]; then result=ok; else result=FAIL; fail=1; fi
	printf '%-16s %-6s %6s  %s\n' "$name" "$result" "$secs" "$summary"
done
echo "all in $(( $(date +%s) - t0 )) s, $jobs at once; logs in $logs"
rm -f memory_leaks.txt
exit $fail
