#!/bin/sh
# A Steam Deck build of the Lobster game: Lobster for Linux x86_64 (CI's build of the fork commit, or one made in a
# container; its libraries are in its own tree: SDL, SDL_mixer, freetype...), then the game's folder assembled beside it:
#   <out>/lobster/{bin/lobster, data, modules}   the language and its own data (shaders, fonts)
#   <out>/data, assets/{audio,fonts}, mods       the game's data, sounds and display font
#   <out>/creel/{src,sidecar}                    the engine's modules, and online play's sidecar (bare and Hyperswarm
#                                                for Linux x86_64, nothing to install on the Deck: tools/sidecar_pack.sh)
#   <out>/src/...                                the game's code, and baked/ (its buildings and props, from prebake.sh;
#                                                a race's own parts it bakes itself)
#   <out>/run.sh                                 runs the game (the lobby)
#   <out>/icon.png                               the game's icon (pull_lobster.sh makes a launcher with it)
# Usage: src/deck/build.sh [out dir]   (default build/lobster_linux; needs node and npm, and gh or podman/docker for a fork
# commit CI hasn't built)
# The Deck pulls it with tools/deck/pull_lobster.sh.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
root="$(cd "$here/.." && pwd)"
out="${1:-$root/build/lobster_linux}"
LOBSTER_SRC="${LOBSTER_SRC:-$HOME/Dev/lobster}"
REPO="${REPO:-Casaide/age-of-anything}"
RELEASE="${RELEASE:-lobster-linux}"   # (one release; its assets are lobster-<fork commit>)
PODMAN_MACHINE="${PODMAN_MACHINE:-aoa-build}"
IMAGE="${IMAGE:-ubuntu:22.04}"   # (glibc 2.35: the Deck's SteamOS is newer, so it runs there)

# Only Lobster itself is Linux code: the game ships as source, data and baked/ (the same files on every platform). So the
# binary is taken, in order, from LOBSTER_LINUX, this checkout's build/lobster-linux/<fork commit>/, the release CI
# publishes for that commit (#486), and only then built in a container (the podman machine started if it's stopped).
sha=$(git -C "$LOBSTER_SRC" rev-parse HEAD)
have="$root/build/lobster-linux/$sha"
mkdir -p "$out/lobster/bin" "$have"
if [ -n "${LOBSTER_LINUX:-}" ]; then
	echo "== Lobster for Linux x86_64: $LOBSTER_LINUX"
	cp -f "$LOBSTER_LINUX" "$have/lobster"
elif [ -f "$have/lobster" ]; then
	echo "== Lobster for Linux x86_64: build/lobster-linux/$sha (have it)"
elif command -v gh >/dev/null && gh release download "$RELEASE" -R "$REPO" -p "lobster-$sha" -O "$have/lobster.tmp" --clobber 2>/dev/null; then
	echo "== Lobster for Linux x86_64: CI's release ($RELEASE, lobster-$sha)"
	mv "$have/lobster.tmp" "$have/lobster"
else
	rm -f "$have/lobster.tmp"
	ENGINE="${ENGINE:-$(command -v podman || command -v docker)}"
	[ -n "$ENGINE" ] || { echo "no release for fork commit $sha, and no podman or docker to build it"; exit 1; }
	echo "== Lobster for Linux x86_64: no release for $sha, building it ($ENGINE, $IMAGE)"
	case "$ENGINE" in */podman) podman machine start "$PODMAN_MACHINE" 2>/dev/null || true ;; esac
	"$ENGINE" run --rm --platform linux/amd64 -v "$LOBSTER_SRC:/lobster:ro" -v "$have:/out" "$IMAGE" sh -c "$(cat "$here/deck/lobster_linux.sh")"
fi
cp -f "$have/lobster" "$out/lobster/bin/lobster"
cp -R "$LOBSTER_SRC/data" "$LOBSTER_SRC/modules" "$out/lobster/"

echo "== The buildings and props, baked once here and shipped (src/prebake.sh)"
"$here/prebake.sh"

echo "== The game"
mkdir -p "$out/assets" "$out/src" "$out/creel"
rsync -a --delete --exclude '*.import' --exclude '*.uid' "$root/data/" "$out/data/"
rsync -a --delete --exclude '*.import' "$root/assets/audio/" "$out/assets/audio/"
rsync -a --delete "$root/assets/fonts/" "$out/assets/fonts/"   # (the display font, ../assets/fonts: the lobby failed without it)
rsync -a --delete --exclude '*.import' --exclude '*.uid' "$root/mods/" "$out/mods/"
rsync -a --delete --delete-excluded --exclude 'pack' --exclude 'pack6b' --exclude 'pack_scifi' --exclude 'library' --exclude 'bake_cache' \
	--exclude 'model/mods' --exclude 'textures/bmat*' --exclude '*.sav' --exclude 'memory_leaks.txt' \
	--exclude 'deck' "$here/" "$out/src/"
[ -f "$root/creel/src/lib/world.lobster" ] || { echo "creel/ is empty: git submodule update --init"; exit 1; }
rsync -a --delete "$root/creel/src/" "$out/creel/src/"   # (the engine's modules, where the game's programs look for them)
"$root/tools/sidecar_pack.sh" linux-x64 "$out/creel/sidecar"   # (online play by join code, #44: ../creel/sidecar from src/)
# which build this is, for the menu's foot (#500): the Deck has no .git to ask
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
[ -n "$(git -C "$root" status --porcelain --untracked-files=no 2>/dev/null)" ] && commit="$commit+changes"
echo "$commit" > "$out/src/build_id.txt"
rsvg-convert -w 512 -h 512 "$root/assets/art/ui/game_icon.svg" -o "$out/icon.png"
cat > "$out/run.sh" <<'EOF'
#!/bin/sh
# Age of Anything (the Lobster port): the lobby, with no pack (every picture baked by the game itself, the parts
# kept in bake_cache/ after the first start). Extra words go to the game (watch, host, join:<ip>, mods:<id>...).
# Started directly (a Steam shortcut made before #492 points here), it goes through the launcher make serve's deck.sh
# installed beside the game first, so a newer build the Mac serves is pulled before the game starts (#502).
launch="$(cd "$(dirname "$0")/.." && pwd)/age-of-anything.sh"
if [ -z "${AOA_UPDATED:-}" ] && [ -f "$launch" ]; then AOA_UPDATED=1 exec sh "$launch" --run; fi
cd "$(dirname "$0")/src"
. ./bake_cache.sh
../lobster/bin/lobster game.lobster -- none lobby "$@" > ../last_run.log 2>&1 &   # (the log: a failed join says why, #506)
game=$!
trap 'kill -9 $game 2>/dev/null' INT TERM   # (Lobster's window never takes Ctrl-C: the script stops the game)
wait $game
EOF
chmod +x "$out/run.sh" "$out/lobster/bin/lobster"
echo "== $(du -sh "$out" | cut -f1) in $out"
