#!/bin/sh
# Every check of what the game builds (races, the match start, models, props, buildings, materials, voxels) run the
# way the game runs (lobster --mir), against Godot's. The summary lines go to stdout; each check's whole output to
# <out dir>/<check>.txt. Usage: tests/lobster_spike/mir_audit.sh <out dir>
out="$1"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"
cd "$here"
echo "== races";     ./race_check.sh > "$out/races.txt" 2>&1; tail -2 "$out/races.txt"
echo "== start";     TMPDIR="$out" ./start_check.sh > "$out/start.txt" 2>&1; grep -ci "same\|differ\|DIFF" "$out/start.txt"; tail -3 "$out/start.txt"
for p in "sewer rats with cheese hammers" "swamp frogs with spears" "romans" "centaur greeks" "spiders" "moonbears with axes" \
         "cat vikings riding horses" "beetle aztecs" "flying greeks with wings" "han frogs on newts" "nile cats"; do
	echo "== models: $p"; ./model_check.sh "$out/m" "$p" > "$out/models.txt" 2>&1; tail -1 "$out/models.txt"
	grep -i "differ\|DIFF\|wrong\|missing" "$out/models.txt" | head -5
done
echo "== props";     ./prop_check.sh "$out/p" > "$out/props.txt" 2>&1; tail -2 "$out/props.txt"
echo "== buildings"; ./building_check.sh "$out/b" > "$out/buildings.txt" 2>&1; tail -2 "$out/buildings.txt"
echo "== materials"; ./mat_check.sh "$out/mat" > "$out/mats.txt" 2>&1; tail -2 "$out/mats.txt"
echo "== voxels";    ./geom_check.sh "$out/g" "sewer rats with cheese hammers" "swamp frogs with spears" "romans" "spiders" "moonbears with axes" \
                     "cat vikings riding horses" "beetle aztecs" "flying greeks with wings" 2>&1 | grep -v "^NEAR"
