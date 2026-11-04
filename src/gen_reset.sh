#!/bin/sh
# Writes gen/reset.lobster and gen/save.lobster (gen_reset.lobster says what they are), in the formatter's layout so
# ./lint.sh stays clean after a run. Run after adding a global.
#   src/gen_reset.sh
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
LOBSTERFMT="${LOBSTERFMT:-$(dirname "$LOBSTER")/lobsterfmt}"
set -e
cd "$(dirname "$0")"
"$LOBSTER" gen_reset.lobster
"$LOBSTERFMT" -w -program "$PWD/game.lobster" "$PWD/gen/reset.lobster" "$PWD/gen/save.lobster"
