#!/bin/sh
# The art a build ships: every prop and every architecture's buildings, baked once into baked/ at the base density and at
# a Retina screen's 2.4 (each keyed by its density: the game finds the set for its screen, #358; the game reads it
# before bake_cache/, so a match start bakes only the races' own parts), its PNGs compressed. Remade when
# BAKE_VERSION changes; otherwise only what's missing is baked. The Deck and Android builds and `make mac` run it.
# In pieces side by side (#456): the props, then each architecture's buildings, at each density, a process a piece,
# BAKE_JOBS at once (the cores but one).
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
jobs="${BAKE_JOBS:-$(($(sysctl -n hw.ncpu 2>/dev/null || nproc) - 1))}"
pieces=$("$LOBSTER" game.lobster -- none - prebake pieces mute 2>&1 | sed -n 's/^prebake: \([0-9]*\) pieces$/\1/p')
[ -n "$pieces" ]
export LOBSTER pieces
for density in density:0 density:2.4; do
	i=0
	while [ $i -lt "$pieces" ]; do
		echo "$density $i"
		i=$((i + 1))
	done
done | xargs -P "$jobs" -L1 sh -c '"$LOBSTER" game.lobster -- none - prebake "$0" shard:$1/$pieces mute 2>&1 | grep "^prebake:" | sed "s/^prebake:/prebake ($0):/"'
# Recompressed in place (the game's PNG writer, creel's view/png.lobster png_bytes, stores the pixels uncompressed), only
# what's new since the last run. Pixels unchanged.
newer=""
if [ -f baked/squeezed ]; then newer="-newer baked/squeezed"; fi
find baked -name '*.png' $newer -print0 | xargs -0 -P"$jobs" -n32 magick mogrify -define png:compression-level=9 \
	-define png:compression-filter=0 -define png:compression-strategy=0 -define png:color-type=6 -define png:exclude-chunks=all
touch baked/squeezed
echo "baked/: $(ls baked | wc -l | tr -d ' ') files, $(du -sh baked | cut -f1)"
