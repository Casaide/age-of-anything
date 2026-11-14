#!/bin/sh
# Makes sure creel/ (the engine submodule) is checked out at the commit this game pins, before a build (#495): an old or
# missing creel/ makes every program fail to compile, and the bake stopped with nothing but "Error 1". `make` runs it first.
# Missing, or behind the pin with nothing of its own (clean, and its commit is an ancestor of the pin): synced. Anything else
# (local changes, or a commit the pin doesn't contain, i.e. engine work in progress): left alone, with what to run.
set -e
cd "$(dirname "$0")/.."
pin=$(git rev-parse HEAD:creel)
if [ ! -f creel/src/view/bake_cache.lobster ]; then
	echo "creel/ is missing: checking out the pinned $(echo "$pin" | cut -c1-7)"
	git submodule update --init creel
	exit 0
fi
at=$(git -C creel rev-parse HEAD)
[ "$at" = "$pin" ] && exit 0
if [ -z "$(git -C creel status --porcelain)" ] && git -C creel merge-base --is-ancestor "$at" "$pin" 2>/dev/null; then
	echo "creel/ is at an older $(echo "$at" | cut -c1-7): moving it to the pinned $(echo "$pin" | cut -c1-7)"
	git submodule update --init creel
	exit 0
fi
echo "creel/ is at $(echo "$at" | cut -c1-7), not the pinned $(echo "$pin" | cut -c1-7), and has work of its own (changes, or commits the pin"
echo "doesn't have). Building with it as it is. To build with the pin: git submodule update --init creel"
