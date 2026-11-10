#!/bin/sh
# The art a build ships: every prop and every architecture's buildings, baked once into baked/ at the base density and at
# a Retina screen's 2.4 (each keyed by its density: the game finds the set for its screen, #358; the game reads it
# before bake_cache/, so a match start bakes only the races' own parts), its PNGs compressed. Remade when
# BAKE_VERSION changes; otherwise only what's missing is baked. The Deck and Android builds run it.
#   src/prebake.sh
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
cd "$(dirname "$0")"
set -e
version=$(sed -n 's/^let BAKE_VERSION = \([0-9]*\).*/\1/p' ../creel/src/view/bake_cache.lobster)
mkdir -p baked
if [ "$(cat baked/version 2>/dev/null)" != "$version" ]; then
	find baked -mindepth 1 -delete
	echo "$version" > baked/version
fi
"$LOBSTER" game.lobster -- none - prebake mute 2>&1 | grep '^prebake:'
"$LOBSTER" game.lobster -- none - prebake density:2.4 mute 2>&1 | grep '^prebake:'
# Recompressed in place (the game's PNG writer, model/build_mats.lobster bmat_png, stores the pixels uncompressed), only
# what's new since the last run. Pixels unchanged.
newer=""
if [ -f baked/squeezed ]; then newer="-newer baked/squeezed"; fi
find baked -name '*.png' $newer -print0 | xargs -0 -P4 -n32 magick mogrify -define png:compression-level=9 \
	-define png:compression-filter=0 -define png:compression-strategy=0 -define png:color-type=6 -define png:exclude-chunks=all
touch baked/squeezed
echo "baked/: $(ls baked | wc -l | tr -d ' ') files, $(du -sh baked | cut -f1)"
