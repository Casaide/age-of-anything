#!/bin/sh
# What a Steading town is drawn as (#188, Creel's draw probe): the demo town (steading_town.lobster) played on in the
# real window, its probe written with a picture, then drawn_check.lobster reads it: carriers drawn carrying their goods,
# sites showing their stages with nothing over them.
#   src/drawn_check.sh [bake options]
cd "$(dirname "$0")" || exit 1
L="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
"$L" steading_town.lobster > /dev/null 2>&1  # (the demo save; its own check of the town is test_steading's job)
[ -s saves/steading-town.sav ] || { echo "FAIL: drawn: no demo town saved"; exit 1; }
pic="${TMPDIR:-/tmp}/drawn.png"
probe="${TMPDIR:-/tmp}/drawn.json"
rm -f "$pic" "$probe"
# (2.5 minutes on: by then every carried good's pose is baked, on a slow machine too)
../play.sh lobby mods:steading rules:steading page:saves loadfirst mute novsync windowed shot:"$pic" at:150 probe:"$probe" "$@" || { echo "FAIL: drawn: the town didn't play"; exit 1; }
[ -s "$probe" ] || { echo "FAIL: drawn: no probe written"; exit 1; }
"$L" drawn_check.lobster -- "$probe"
