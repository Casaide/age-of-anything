#!/bin/sh
# The test runner's own tests (batch.sh), with a stand-in for Lobster so they take seconds and no game runs. Exit 1 on a failure.
#   src/batch_test.sh
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/aoa_batch_test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work"
export XDG_CACHE_HOME="$work/cache"   # (the batch's shared bakes: not the real ones)
link_before="$(readlink "$here/../build/bake_store" 2> /dev/null)"
passed=0
failed=0
check() {   # check <what> <command...>
	what="$1"
	shift
	if "$@"; then
		passed=$((passed + 1))
	else
		failed=$((failed + 1))
		echo "FAIL: $what"
	fi
}
has() { grep -q "$2" "$1"; }
has_not() { ! grep -q "$2" "$1"; }

# The stand-in: run_tests takes three seconds, test_heroes one, test_2v2 kills the job that runs it before it can report.
cat > "$work/lobster" <<'EOF'
#!/bin/sh
case "$1" in
	run_tests.lobster) sleep 3; echo "stand-in run_tests" ;;
	test_heroes.lobster) sleep 1; echo "stand-in test_heroes" ;;
	test_2v2.lobster)
		p=$PPID
		while [ "$p" -gt 1 ]; do
			if ps -o command= -p "$p" | grep -q 'line="\$0"'; then kill -9 "$p"; break; fi
			p=$(ps -o ppid= -p "$p" | tr -d ' ')
		done
		sleep 1
		;;
	test_shot_look.lobster) trap '' TERM; sleep 30 ;;   # (stuck, as a window is in vsync with the display asleep: SIGTERM doesn't stop it)
	*) echo "$*" >> "$TMPDIR/../../lobster_args" ;;
esac
EOF
chmod +x "$work/lobster"
export LOBSTER="$work/lobster"
batch() {   # batch <lock folder> <args...>: the lock folder apart, for batches that must overlap
	AOA_LOCK_DIR="$work/$1" && export AOA_LOCK_DIR
	shift
	"$here/batch.sh" "$@"
}

# Two batches at once report their own suites, and neither's results are lost to the other (#229).
batch locks_a only=run_tests > "$work/a.out" 2>&1 &
a=$!
sleep 1
batch locks_b only=test_heroes > "$work/b.out" 2>&1
b_code=$?
wait $a
a_code=$?
check "the first batch reports its own suite (#229)" has "$work/a.out" '^run_tests  *ok'
check "and not the second's" has_not "$work/a.out" 'test_heroes'
check "the second reports its own" has "$work/b.out" '^test_heroes  *ok'
check "and not the first's" has_not "$work/b.out" 'run_tests'
check "both pass" [ "$a_code" = 0 ] && check "(the second)" [ "$b_code" = 0 ]

# A job that never reported is a failure, not a pass (#229).
batch locks_c only=test_2v2 > "$work/c.out" 2>&1
c_code=$?
check "a job with no result fails the batch" [ "$c_code" != 0 ]
check "and says so" has "$work/c.out" '^test_2v2  *FAIL.*no result'

# A run with no windowed job leaves the shared bakes alone: this test runs inside a real batch, whose jobs read them through that link.
check "a run without windowed jobs doesn't touch the bakes' link" [ "$(readlink "$here/../build/bake_store" 2> /dev/null)" = "$link_before" ]

# A stuck job fails on its time limit, even one that ignores SIGTERM, and the others still report (#294).
started=$(date +%s)
(export AOA_JOB_LIMIT=2; batch locks_f only=test_shot_look,test_heroes > "$work/stuck.out" 2>&1)
stuck_code=$?
check "a stuck job fails the batch" [ "$stuck_code" != 0 ]
check "and shows as failed" has "$work/stuck.out" '^test_shot_look  *FAIL'
check "the others still report" has "$work/stuck.out" '^test_heroes  *ok'
check "and it doesn't wait for the job" [ $(($(date +%s) - started)) -lt 25 ]

# The windowed checks that measure no frames don't wait on vsync: with the display asleep it never comes (#294).
batch locks_g only=vbcheck > "$work/vb.out" 2>&1
check "vbcheck runs without vsync" has "$work/lobster_args" 'vbcheck.*novsync'

# Asking for tests that don't exist isn't a pass.
batch locks_d only=no_such_suite > "$work/d.out" 2>&1
check "no jobs at all fails the batch" [ "$?" != 0 ]

# ---- the lock across worktrees (machine_lock.sh, #242)
unset AOA_LOCKS_HELD   # (run inside a batch, which holds its own, elsewhere)
export AOA_LOCK_DIR="$work/locks"
export AOA_LOCK_POLL=0.1

# Holds <lane> for the seconds given, marking the time inside; two inside at once is an overlap.
cat > "$work/hold.sh" <<EOF
. "$here/machine_lock.sh"
lock_on_exit
lock_take "\$1" "the test"
mkdir "$work/inside" 2>/dev/null || echo overlap >> "$work/overlaps"
echo in >> "$work/entered"
sleep "\$2"
rmdir "$work/inside"
EOF
hold() { exec sh "$work/hold.sh" "$@"; }

pids=""
for i in 1 2 3 4 5 6 7 8; do
	(hold contended 0.1 2> /dev/null) &
	pids="$pids $!"
done
wait $pids
check "eight at once all get in" [ "$(wc -l < "$work/entered" | tr -d ' ')" = 8 ]
check "one at a time" [ ! -f "$work/overlaps" ]
check "and the lane is free after" [ ! -L "$AOA_LOCK_DIR/contended" ]

# A waiter says it's queued and who holds the lane.
(hold named 2 2> /dev/null) &
held=$!
sleep 0.5
(hold named 0 2> "$work/queued.out")
wait $held
check "a waiter says it's queued" has "$work/queued.out" 'queued for the named lane'
check "and who holds it" has "$work/queued.out" "held by PID $held in .*(the test)"

# A holder killed outright: taken over, once, by waiters that all arrive together.
(hold killed 20 2> /dev/null) &
victim=$!
sleep 0.5
kill -9 $victim
wait $victim 2> /dev/null
rmdir "$work/inside"
rm -f "$work/entered"
: > "$work/over.out"
pids=""
for i in 1 2 3 4 5 6; do
	(hold killed 0.2 2>> "$work/over.out") &
	pids="$pids $!"
done
wait $pids
check "a dead holder's lock is taken over" [ "$(wc -l < "$work/entered" | tr -d ' ')" = 6 ]
check "exactly once" [ "$(grep -c 'taking over' "$work/over.out")" = 1 ]
check "with no overlap" [ ! -f "$work/overlaps" ]

# A PID that's alive but isn't the holder any more (the system reused it).
ln -s "$$|Thu Jan  1 00:00:00 1970|/elsewhere|the old holder|0" "$AOA_LOCK_DIR/reused"
(hold reused 0 2> "$work/reused.out")
check "a reused PID doesn't hold it for ever" has "$work/reused.out" 'taking over'

# A holder that exits on a signal lets go.
cat > "$work/signalled.sh" <<EOF
. "$here/machine_lock.sh"
lock_on_exit
lock_take signalled "the test"
sleep 20 &
wait
EOF
sh "$work/signalled.sh" 2> /dev/null &
victim=$!
sleep 0.5
kill -TERM $victim
wait $victim 2> /dev/null
check "a holder stopped by a signal lets go" [ ! -L "$AOA_LOCK_DIR/signalled" ]

# The batch's lanes: only= and --quick run beside a full batch, one of them at a time; a full batch waits for another.
(hold full 5 2> /dev/null) &
held=$!
sleep 0.5
"$here/batch.sh" only=test_heroes > "$work/beside.out" 2>&1
check "only= doesn't wait for a full batch" has_not "$work/beside.out" 'queued'
check "and runs" has "$work/beside.out" '^test_heroes  *ok'
"$here/batch.sh" > "$work/full.out" 2>&1 &
full=$!
sleep 1
check "a full batch waits for another" has "$work/full.out" 'queued for the full lane'
kill -TERM $full
wait $full 2> /dev/null
wait $held
"$here/batch.sh" only=run_tests > "$work/q1.out" 2>&1 &
first=$!
sleep 1
"$here/batch.sh" only=test_heroes > "$work/q2.out" 2>&1
wait $first
check "two only= runs take turns" has "$work/q2.out" 'queued for the quick lane'
check "and both report" has "$work/q1.out" '^run_tests  *ok'
check "and let go" [ ! -L "$AOA_LOCK_DIR/quick" ]

echo
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
