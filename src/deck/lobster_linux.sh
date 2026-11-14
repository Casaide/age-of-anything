#!/bin/sh
# Builds Lobster for Linux x86_64 from /lobster (the fork, read-only) into /out/lobster, stripped. Run inside an Ubuntu 22.04
# container or runner (glibc 2.35: the Deck's SteamOS is newer, so it runs there): src/deck/build.sh's fallback, and CI (#483).
set -e
apt-get update -qq && apt-get install -y -qq build-essential cmake libgl1-mesa-dev libx11-dev libxext-dev \
	libxrandr-dev libxcursor-dev libxi-dev libxss-dev libxfixes-dev libxtst-dev libxkbcommon-dev libdbus-1-dev \
	libasound2-dev libpulse-dev libudev-dev libegl1-mesa-dev libgles2-mesa-dev >/dev/null
cp -r /lobster/dev /tmp/dev
rm -rf /tmp/dev/CMakeCache.txt /tmp/dev/CMakeFiles   # (a checkout built in place: its cache would point cmake back there)
cd /tmp/dev && rm -rf build-linux && mkdir build-linux && cd build-linux
cmake -DCMAKE_BUILD_TYPE=Release .. > /tmp/cmake.log 2>&1 || { tail -30 /tmp/cmake.log; exit 1; }
make -j"$(nproc)" lobster > /tmp/make.log 2>&1 || { tail -40 /tmp/make.log; exit 1; }
found=$(find /tmp/bin /tmp/dev -name lobster -type f -perm -u+x -newer /tmp/cmake.log 2>/dev/null | head -1)
[ -n "$found" ] || { echo "no lobster binary built"; exit 1; }
cp "$found" /out/lobster
strip /out/lobster
