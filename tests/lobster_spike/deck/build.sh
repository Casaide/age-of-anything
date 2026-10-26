#!/bin/sh
# A Steam Deck build of the Lobster game: Lobster built for Linux x86_64 in a container (its libraries
# are in its own tree: SDL, SDL_mixer, freetype...), then the game's folder assembled beside it:
#   <out>/lobster/{bin/lobster, data, modules}   the language and its own data (shaders, fonts)
#   <out>/data, assets/audio, mods               the game's data and sounds
#   <out>/tests/lobster_spike/...                the game's code and the part library (the art)
#   <out>/run.sh                                 runs the game (the lobby)
# Usage: tests/lobster_spike/deck/build.sh [out dir]   (default build/lobster_linux; needs podman or docker)
# The Deck pulls it with tools/deck/pull_lobster.sh.
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
root="$(cd "$here/../.." && pwd)"
out="${1:-$root/build/lobster_linux}"
LOBSTER_SRC="${LOBSTER_SRC:-$HOME/Dev/lobster}"
ENGINE="${ENGINE:-$(command -v podman || command -v docker)}"
IMAGE="${IMAGE:-ubuntu:22.04}"   # (glibc 2.35: the Deck's SteamOS is newer, so it runs there)

echo "== Lobster for Linux x86_64 ($ENGINE, $IMAGE)"
mkdir -p "$out/lobster/bin"
"$ENGINE" run --rm --platform linux/amd64 -v "$LOBSTER_SRC:/lobster:ro" -v "$out/lobster/bin:/out" "$IMAGE" sh -c '
	set -e
	apt-get update -qq && apt-get install -y -qq build-essential cmake libgl1-mesa-dev libx11-dev libxext-dev \
		libxrandr-dev libxcursor-dev libxi-dev libxss-dev libxfixes-dev libxtst-dev libxkbcommon-dev libdbus-1-dev \
		libasound2-dev libpulse-dev libudev-dev libegl1-mesa-dev libgles2-mesa-dev >/dev/null
	cp -r /lobster/dev /tmp/dev
	cd /tmp/dev && rm -rf build-linux && mkdir build-linux && cd build-linux
	cmake -DCMAKE_BUILD_TYPE=Release .. > /tmp/cmake.log 2>&1 || { tail -30 /tmp/cmake.log; exit 1; }
	make -j"$(nproc)" lobster > /tmp/make.log 2>&1 || { tail -40 /tmp/make.log; exit 1; }
	found=$(find /tmp/dev -name lobster -type f -perm -u+x -newer /tmp/cmake.log | head -1)
	[ -n "$found" ] || { echo "no lobster binary built"; exit 1; }
	cp "$found" /out/lobster
	strip /out/lobster
'
cp -R "$LOBSTER_SRC/data" "$LOBSTER_SRC/modules" "$out/lobster/"

echo "== The game"
mkdir -p "$out/assets" "$out/tests/lobster_spike"
rsync -a --delete --exclude '*.import' --exclude '*.uid' "$root/data/" "$out/data/"
rsync -a --delete --exclude '*.import' "$root/assets/audio/" "$out/assets/audio/"
rsync -a --delete --exclude '*.import' --exclude '*.uid' "$root/mods/" "$out/mods/"
rsync -a --delete --exclude 'pack' --exclude 'pack6b' --exclude 'pack_scifi' --exclude '*.sav' --exclude 'memory_leaks.txt' \
	--exclude 'deck' "$here/" "$out/tests/lobster_spike/"
cat > "$out/run.sh" <<'EOF'
#!/bin/sh
# Age of Anything (the Lobster port): the lobby. Extra words go to the game (watch, host, join:<ip>...).
cd "$(dirname "$0")/tests/lobster_spike"
exec ../../lobster/bin/lobster --mir game.lobster -- library lobby "$@"
EOF
chmod +x "$out/run.sh" "$out/lobster/bin/lobster"
echo "== $(du -sh "$out" | cut -f1) in $out"
