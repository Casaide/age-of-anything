#!/bin/sh
# The buildings built in Lobster (model/buildings.lobster, buildings2.lobster) against Godot's (building_export.gd),
# part for part and triangle for triangle. Usage: tests/lobster_spike/building_check.sh <out dir> [case...]
# (no cases: every named model, every type in every architecture, every look, gates on the diagonal, walls rescaled)
out="$1"; shift
here="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
LOBSTER_FLAGS="${LOBSTER_FLAGS-}"   # (as the game runs it, play.sh: no --mir, D-174)
if [ $# -eq 0 ]; then
    set --
    for m in town_center stilt_house junk_town_center junk_town_center_small junk_town_center_pride tin_can_house \
             stone_town_center villa_house tent_town_center tent_house farm_plot reed_house reed_town_center mound_house \
             mound_town_center concept_junk_tc_small concept_junk_tc_low concept_junk_tc_berm concept_pen_hurdles \
             concept_pen_rails concept_pen_wall rally_flag waypoint_flag; do
        set -- "$@" model:$m
    done
    for s in 800 803 805; do set -- "$@" model:flowers:$s; done
    for a in thatch junk stone tent reed mound; do
        for t in barracks stable watchtower wonder archery_range armoury pen lumber_camp mill mining_camp market \
                 siege_workshop university castle wall palisade palisade_gate stone_gate wall_tower ladder outpost \
                 outpost_pole outpost_deck outpost_beacon bastion; do
            set -- "$@" building:$t:$a
        done
        set -- "$@" building:barracks:$a:ruin2 building:market:$a:ruin4 building:watchtower:$a:ruin3   # broken up (game/ruin.lobster)
        set -- "$@" building:palisade_gate:$a:diag building:stone_gate:$a:diag building:wall:$a:r0.8 building:stone_gate:$a:r0.9
        for l in curtain motte great_tower; do set -- "$@" look:castle:$a:$l; done
        for l in observatory cloister builders; do set -- "$@" look:university:$a:$l; done
        for l in hurdles rails wall; do set -- "$@" look:pen:$a:$l; done
        for l in squat drum hoard; do set -- "$@" look:wall_tower:$a:$l; done
        for l in plain hooked mantlet; do set -- "$@" look:ladder:$a:$l; done
        for l in heap stub; do set -- "$@" look:wall_rubble:$a:$l; done
    done
fi
rm -rf "$out"
(cd "$here/../.." && timeout 900 "$GODOT" --headless --path . --script res://tests/lobster_spike/building_export.gd -- "$out" "$@" 2>&1 | grep -i "error" | head -20)
cd "$here" && timeout 900 "$LOBSTER" $LOBSTER_FLAGS building_check.lobster -- "$out" "$@" 2>&1 | grep -v "warning" | tail -500
