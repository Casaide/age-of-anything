#!/bin/sh
# The test runner's own tests (batch.sh), with a stand-in for Lobster so they take seconds and no game runs. Exit 1 on a failure.
#   src/batch_test.sh
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/aoa_batch_test.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export TMPDIR="$work"
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

# Asking for tests that don't exist isn't a pass.
batch locks_d only=no_such_suite > "$work/d.out" 2>&1
check "no jobs at all fails the batch" [ "$?" != 0 ]

echo
echo "$passed passed, $failed failed"
[ "$failed" = 0 ]
