#!/bin/sh
# The network lobby (#519): a joiner comes in before the start, takes a side an AI held and types its army; the host
# then starts and the match runs in lockstep, the AIs on the other sides thinking alike on both machines.
# Three rooms: a 1v1; a 2v2 with the joiner as the host's ally; a 2v2 with the joiner as an enemy.
# Usage: src/room_check.sh [ticks]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-600}"
port=47818  # (the batch runs net_check and net_check_packs beside this)
logs="$(mktemp -d)"
failed=0
room() {  # room <name> <sides> <the side the joiner takes>
	"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- host "$ticks" room "sides:$2" "port:$port" > "$logs/$1.host" 2>&1 &
	host=$!
	sleep 1
	"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan room "side:$3" "port:$port" > "$logs/$1.join" 2>&1 || failed=1
	wait $host || failed=1
	grep -hv warning "$logs/$1.host" "$logs/$1.join"
	h="$(grep -ho 'last hash [0-9-]*' "$logs/$1.host")"
	j="$(grep -ho 'last hash [0-9-]*' "$logs/$1.join")"
	took="$(grep -c "join: took side $3 " "$logs/$1.join")"
	if [ -z "$h" ] || [ "$h" != "$j" ] || [ "$took" != 1 ]; then
		echo "FAILED: $1: host '$h', joiner '$j', joiner on side $3: $took"
		failed=1
	fi
}
room 1v1 2 1
room ally 4 1
room enemy 4 3
rm -rf "$logs"
[ $failed = 0 ] || exit 1
echo "rooms: 1v1, a joined ally and a joined enemy all end on the host's hash"
