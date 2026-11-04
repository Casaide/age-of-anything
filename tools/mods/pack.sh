#!/bin/sh
# Pack a mod for sharing (milestone 21, docs/modding.md): build/mods/<id>-<version>.zip, holding the mod's folder as
# <id>/... (unzip it into the game's user://mods folder to install it).
#
#     tools/mods/pack.sh <id>
#
# Refuses a mod marked "private" in its manifest (fan pieces stay private), and leaves out renders/, .import and .uid
# files. Steam Workshop upload is later (docs/milestones/m21-modability.md).
set -e
if [ $# -ne 1 ]; then sed -n '2,8s/^# \{0,1\}//p' "$0"; exit 1; fi
mod_id=$1
if [ -d "mods_private/$mod_id" ]; then echo "$mod_id is private: it is never packed or shared"; exit 1; fi
if [ ! -d "mods/$mod_id" ]; then echo "no mod $mod_id in mods/ or mods_private/"; exit 1; fi
if grep -Eq '"private": *true' "mods/$mod_id/mod.json"; then echo "$mod_id is private: it is never packed or shared"; exit 1; fi
version=$(sed -n 's/^ *"version": *"\([^"]*\)".*/\1/p' "mods/$mod_id/mod.json" | head -1)
mkdir -p build/mods
out=$PWD/build/mods/$mod_id-$version.zip
rm -f "$out"
(cd mods && zip -qr -X "$out" "$mod_id" -x '*/renders/*' '*/__pycache__/*' '*.import' '*.uid' '*.DS_Store')
echo "packed build/mods/$mod_id-$version.zip"
