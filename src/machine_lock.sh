# A lock shared by every worktree and session on this machine, sourced by batch.sh and shards.sh (#242). A lane has one
# holder at a time; the others wait, saying who holds it. A lock is a symlink, as making one either works or doesn't,
# and its target says who holds it in the same step. macOS has no flock(1).
#   lock_take <lane> <what>   waits for the lane (a lane this process tree already holds goes straight through)
#   lock_drop <lane>          lets it go; a process's locks also go when it exits (lock_on_exit)
# A holder killed outright leaves its link: the next to want the lane takes it over, if the holder's PID is gone or is
# now a different process (its start time differs). AOA_LOCK_DIR moves the locks, AOA_LOCK_POLL is the seconds between looks (the test sets both).
lock_dir="${AOA_LOCK_DIR:-/tmp/aoa-locks}"
lock_mine=""

lock_me() {   # lock_me <what>: this process, as a link's target (pid|started|folder|what|since)
	printf '%s|%s|%s|%s|%s' "$$" "$(ps -o lstart= -p $$)" "$(pwd)" "$1" "$(date +%s)"
}

lock_is_stale() {   # lock_is_stale <target>: its holder is gone
	pid="${1%%|*}"
	rest="${1#*|}"
	[ "${rest%%|*}" != "$(ps -o lstart= -p "$pid" 2>/dev/null)" ]
}

# Under a second lock, so that of several waiters who see one dead holder, only one removes its link: without it the
# second could remove the link of the first, who now holds the lane.
lock_take_over() {   # lock_take_over <path> <target seen>
	find "$1.over" -prune -mmin +1 -exec rmdir {} \; 2>/dev/null   # (left by a waiter killed in these few lines)
	mkdir "$1.over" 2>/dev/null || return 0
	if [ "$(readlink "$1")" = "$2" ]; then
		echo "lock: $(basename "$1"): the holder (PID ${2%%|*}) is gone, taking over" >&2
		rm -f "$1"
	fi
	rmdir "$1.over"
}

lock_say_queued() {   # lock_say_queued <lane> <target>
	folder="${2#*|*|}"
	what="${folder#*|}"
	since="${what#*|}"
	echo "lock: queued for the $1 lane: held by PID ${2%%|*} in ${folder%%|*} (${what%%|*}) for $(( $(date +%s) - since )) s" >&2
}

lock_take() {   # lock_take <lane> <what>
	case " $AOA_LOCKS_HELD " in *" $1 "*) return 0 ;; esac
	mkdir -p "$lock_dir" || { echo "lock: can't make $lock_dir" >&2; exit 1; }
	path="$lock_dir/$1"
	me="$(lock_me "$2")"
	said=0
	until ln -s "$me" "$path" 2>/dev/null; do
		held="$(readlink "$path")" || continue   # (let go just now)
		if lock_is_stale "$held"; then
			lock_take_over "$path" "$held"
			continue
		fi
		if [ $(($(date +%s) - said)) -ge 60 ]; then
			lock_say_queued "$1" "$held"
			said=$(date +%s)
		fi
		sleep "${AOA_LOCK_POLL:-2}"
	done
	lock_mine="$lock_mine $1"
	AOA_LOCKS_HELD="$AOA_LOCKS_HELD $1"
	export AOA_LOCKS_HELD   # (what a job starts, shards.sh say, is under this lock already)
}

lock_drop() {   # lock_drop <lane>
	path="$lock_dir/$1"
	case "$(readlink "$path")" in "$$|"*) rm -f "$path" ;; esac
	lock_mine="$(echo "$lock_mine" | sed "s/ $1\$//; s/ $1 / /")"
	AOA_LOCKS_HELD="$(echo "$AOA_LOCKS_HELD" | sed "s/ $1\$//; s/ $1 / /")"
}

lock_on_exit() {   # lock_on_exit: this process's locks go when it exits, however it does
	trap 'for lane in $lock_mine; do lock_drop "$lane"; done' EXIT
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM
}
