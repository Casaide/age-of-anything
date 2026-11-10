#!/bin/sh
# The ground's textures (#392): src/ground_textures.lobster paints them, sips writes the PNG the game loads
# (data/ground/atlas.png). Run again after a change to the painting, and commit the PNG with it.
set -e
cd "$(dirname "$0")"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
"$LOBSTER" ground_textures.lobster -- "$tmp/atlas.tga"
mkdir -p ../data/ground
sips -s format png "$tmp/atlas.tga" --out ../data/ground/atlas.png > /dev/null
ls -l ../data/ground/atlas.png
