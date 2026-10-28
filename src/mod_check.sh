#!/bin/sh
# A mod checked (mod_check.lobster): loaded or refused with the reason, its check prompts' races and who wears its
# parts, the 3D placement check on their units. Brings the mod's Lobster models in for the run, then puts them back.
#   src/mod_check.sh <mod id>
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
mkdir -p model/mods   # (mods_gen writes the mod's models there; Lobster can't make a folder)
"$LOBSTER" mods_gen.lobster -- "$1" | grep -v warning
"$LOBSTER" mod_check.lobster -- "$1" 2>&1 | grep -v warning
code=$?
"$LOBSTER" mods_gen.lobster | grep -v warning
exit $code
