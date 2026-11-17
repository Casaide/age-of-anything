#!/bin/sh
# The online-play sidecar (creel/sidecar, #44) made ready to run on one platform with nothing to install there:
# sidecar.js and its node_modules for that platform only (the bare runtime, Hyperswarm and their native parts; the
# other platforms' builds are left out). The game finds it at ../creel/sidecar from src/ (creel/src/net/swarm.lobster).
# Usage: tools/sidecar_pack.sh <platform> <out dir>   platform: darwin-arm64, darwin-x64, linux-x64 (the Deck)...
# Needs node and npm on this machine only. Quick when nothing changed: the out dir keeps a stamp of what it holds.
set -e
root="$(cd "$(dirname "$0")/.." && pwd)"
target="$1"
out="$2"
[ -n "$target" ] && [ -n "$out" ] || { echo "usage: tools/sidecar_pack.sh <platform> <out dir>"; exit 1; }
src="$root/creel/sidecar"
[ -f "$src/sidecar.js" ] || { echo "no creel/sidecar: git submodule update --init"; exit 1; }
command -v npm > /dev/null || { echo "the online-play sidecar needs node and npm on this machine (https://nodejs.org)"; exit 1; }
os="${target%-*}"
cpu="${target#*-}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
stamp="$target $(cat "$src/sidecar.js" "$src/package.json" "$src/package-lock.json" | cksum)"
bare="$out/node_modules/bare-runtime-$target/bin/bare"
if [ -f "$out/node_modules/.packed" ] && [ "$(cat "$out/node_modules/.packed")" = "$stamp" ] && [ -x "$bare" ]; then
	echo "== Online-play sidecar for $target: have it"
	exit 0
fi
echo "== Online-play sidecar for $target"
if [ "$out" != "$src" ]; then cp "$src/sidecar.js" "$src/package.json" "$src/package-lock.json" "$out/"; fi
rm -f "$out/node_modules/.packed"
(cd "$out" && npm ci --omit=dev --os="$os" --cpu="$cpu" --no-audit --no-fund --loglevel=error)
# (every native addon ships prebuilds for every platform: keep this one's)
for dir in "$out"/node_modules/*/prebuilds "$out"/node_modules/@*/*/prebuilds; do
	[ -d "$dir" ] || continue
	for p in "$dir"/*; do [ "$(basename "$p")" = "$target" ] || rm -rf "$p"; done
done
[ -f "$bare" ] || { echo "npm left out the bare runtime for $target"; exit 1; }
chmod +x "$bare"   # (the npm package has lost its exec bit before)
echo "$stamp" > "$out/node_modules/.packed"
echo "== $(du -sh "$out" | cut -f1) in $out"
