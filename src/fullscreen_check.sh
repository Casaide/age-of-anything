#!/bin/sh
# Fullscreen in a real window (#223): starts fullscreen, switches to a window and back, in the lobby and in a match, and
# the window's size follows. Takes over the screen for half a minute, so not in the batch. Run from anywhere.
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
fail=0
check() { # check <what> <options...>
	what="$1"
	shift
	sizes="$(timeout -s KILL 22 "$LOBSTER" game.lobster -- none lobby lobby mute fullscreen fsreport fsat:7,14 "$@" 2>&1 | grep '^window:')"
	last="$(printf '%s\n' "$sizes" | tail -1)"
	win="$(printf '%s\n' "$sizes" | grep 'fullscreen false' | tail -1 | cut -d' ' -f2-3)"
	if [ -z "$win" ] || ! printf '%s\n' "$last" | grep -q 'fullscreen true' || printf '%s\n' "$last" | grep -qF "$win"; then
		echo "FAIL $what: $sizes"
		fail=1
	else
		echo "ok $what: a window $win, then $last"
	fi
}
check lobby page:setup
check match "races:sewer rats|romans" watch
exit $fail
