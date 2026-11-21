#!/bin/sh
# Fullscreen in a real window (#223): starts fullscreen, switches to a window and back, in the lobby and in a match, and
# the window's size follows. Takes over the screen for half a minute, so not in the batch. Run from anywhere.
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
report="${TMPDIR:-/tmp}/aoa_fullscreen_check.txt"
fail=0
check() { # check <what> <options...>
	what="$1"
	shift
	rm -f "$report"
	timeout -s KILL 22 "$LOBSTER" game.lobster -- none lobby lobby mute fullscreen "fsreport:$report" fsat:7,14 "$@" > /dev/null 2>&1
	sizes="$(cat "$report")"
	last="$(printf '%s\n' "$sizes" | tail -1)"
	win="$(printf '%s\n' "$sizes" | grep 'fullscreen false' | tail -1 | cut -d' ' -f2-3)"
	if [ -z "$win" ] || ! printf '%s\n' "$last" | grep -q 'fullscreen true' || printf '%s\n' "$last" | grep -qF "$win"; then
		echo "FAIL $what: $sizes"
		fail=1
	else
		echo "ok $what: a window $win, then $last"
	fi
}
# The atmosphere's buffers follow the window (#123): a match started in a window goes fullscreen, then it must not be shaded
# with a buffer of the old size (each unit's mask off it: a pale copy of its legs under it).
shade_check() {
	rm -f "$report"
	# (once first, to bake the match's units: the switch must come in the match, not on the loading screen)
	"$LOBSTER" game.lobster -- none lobby lobby mute windowed "races:sewer rats|romans" watch "shot:${TMPDIR:-/tmp}/aoa_fullscreen_warm.png" at:1 > /dev/null 2>&1
	timeout -s KILL 22 "$LOBSTER" game.lobster -- none lobby lobby mute windowed "fsreport:$report" fsat:8 "races:sewer rats|romans" watch > /dev/null 2>&1
	sizes="$(cat "$report")"
	if [ "$(printf '%s\n' "$sizes" | grep -c '^window:')" -lt 2 ] || printf '%s\n' "$sizes" | grep -q '^atmosphere:'; then
		echo "FAIL shade: $sizes"
		fail=1
	else
		echo "ok shade: the buffers follow the window: $(printf '%s\n' "$sizes" | tr '\n' ' ')"
	fi
}
check lobby page:setup
check match "races:sewer rats|romans" watch
shade_check
rm -f "$report" "${TMPDIR:-/tmp}/aoa_fullscreen_warm.png"
exit $fail
