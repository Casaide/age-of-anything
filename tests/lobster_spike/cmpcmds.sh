#!/bin/sh
# Compare the orders GDScript's bots gave in a scenario with the ones Lobster's bots give.
# Usage: tests/lobster_spike/cmpcmds.sh <scenario file> (prints the first differences)
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
f="$1"
"$LOBSTER" --mir sim.lobster -- "$f" bots cmdlog 2>/dev/null | awk '$1=="cmd"{$1=""; print substr($0,2)}' > "$f.lob_cmds"
awk '/^CMDS/{f=1;next} /^HASHES/{f=0} f' "$f" > "$f.gd_cmds"
diff "$f.gd_cmds" "$f.lob_cmds" | head -${2:-12}
