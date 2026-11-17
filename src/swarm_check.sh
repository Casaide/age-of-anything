#!/bin/sh
# Online play by join code (#514), headless: net_check's host shows a code through its sidecar, and the
# joiner reaches it only through its own sidecar and that code, on a local test DHT (no internet needed).
# Needs node and `npm install` in creel/sidecar. Usage: src/swarm_check.sh [ticks]
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
ticks="${1:-2000}"
logs="$(mktemp -d)"
failed=0
node ../creel/sidecar/test/testnet.js > "$logs/dht" &
dht=$!
while [ ! -s "$logs/dht" ]; do sleep 0.1; done
bs="$(cat "$logs/dht")"
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- host "$ticks" swarm "bootstrap:$bs" port:47826 "codefile:$logs/code" > "$logs/host" 2>&1 &
host=$!
n=0
code=""
while [ -z "$code" ] && [ $n -lt 200 ]; do
	sleep 0.1
	n=$((n + 1))
	code="$(cat "$logs/code" 2>/dev/null)"
done
"$LOBSTER" $LOBSTER_FLAGS net_check.lobster -- join "$ticks" noscan "code:$code" "bootstrap:$bs" > "$logs/join" 2>&1 || failed=1
wait $host || failed=1
kill $dht
cat "$logs"/host "$logs"/join | grep -v warning
rm -rf "$logs"
[ $failed = 0 ] || { echo "FAILED: a side of the match stopped"; exit 1; }
