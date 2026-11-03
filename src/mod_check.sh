#!/bin/sh
# A mod checked (mod_check.lobster): loaded or refused with the reason, its check prompts' races and who wears its
# parts, then what its parts' price_points should be (calibrate.lobster mod).
#   src/mod_check.sh <mod id>
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
"$LOBSTER" mod_check.lobster -- "$1" 2>&1 | grep -v warning
code=$?
echo "Its parts' prices, by fights against the panel (calibrate.lobster, D-195; a few minutes):"
"$LOBSTER" calibrate.lobster -- mod "$1" 2>&1 | grep -v warning
exit $code
