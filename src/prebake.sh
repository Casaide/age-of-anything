#!/bin/sh
# The art a build ships: every prop and every architecture's buildings, baked once into baked/ (the game reads it
# before bake_cache/, so a match start bakes only the races' own parts), its PNGs compressed. Remade when
# BAKE_VERSION changes; otherwise only what's missing is baked. The Deck and Android builds run it.
#   src/prebake.sh
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
set -e
version=$(sed -n 's/^let BAKE_VERSION = \([0-9]*\).*/\1/p' view/bake_cache.lobster)
mkdir -p baked
if [ "$(cat baked/version 2>/dev/null)" != "$version" ]; then
	find baked -mindepth 1 -delete
	echo "$version" > baked/version
fi
"$LOBSTER" game.lobster -- none - prebake mute 2>&1 | grep '^prebake:'
python3 ../tools/art/squeeze_png.py baked
echo "baked/: $(ls baked | wc -l | tr -d ' ') files, $(du -sh baked | cut -f1)"
