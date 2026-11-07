#!/bin/sh
# Packs must match in a network match: a joiner without the host's mod is turned away by name, then one with it plays.
# Usage: src/net_check_packs.sh [ticks]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-300}"
port=47817  # (the batch runs net_check beside this)
log="$(mktemp)"
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- host "$ticks" mods:scifi_test "port:$port" > "$log" 2>&1 &
host=$!
sleep 1
out="$("$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan refused "port:$port" 2>&1 | grep -v warning)"
echo "$out"
case "$out" in
	*"join: refused: this host plays with the mod scifi_test"*) ;;
	*) echo "FAILED: the joiner without the mod wasn't refused by name"; kill $host 2>/dev/null; exit 1 ;;
esac
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan mods:scifi_test "port:$port" > "$log.join" 2>&1
join_rc=$?
wait $host
host_rc=$?
grep -hv warning "$log" "$log.join"
rm -f "$log" "$log.join"
if [ $join_rc != 0 ] || [ $host_rc != 0 ]; then echo "FAILED: host $host_rc, join $join_rc"; exit 1; fi
echo "packs: refused without the mod, played with it"
