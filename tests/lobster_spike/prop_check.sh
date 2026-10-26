#!/bin/sh
# The props built in Lobster (model/props, trees, town_props, bridges) against Godot's (prop_export.gd), triangle for
# triangle. Usage: tests/lobster_spike/prop_check.sh <out dir> [case...]   (no cases: every kind, seeds, stage and style)
out="$1"; shift
here="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
LOBSTER="${LOBSTER:-$HOME/Dev/lobster/bin/lobster}"
if [ $# -eq 0 ]; then
    set --
    for s in 0 7 12345; do
        set -- "$@" stone_mesh:$s:0 stone_mesh:$s:1 grass_tuft:$s field_stones:$s lily_pads:$s boulders:$s crops:$s paddy:$s
        for st in 0 1 2 3; do
            set -- "$@" reed_clump:$s:1.0:$st bug_bush:$s:$st quarry:$s:$st:stone quarry:$s:$st:gold carcass:$s:$st
        done
        set -- "$@" reed_clump:$s:0.5:0 reed_clump:$s:0.5:2
    done
    for s in 3 41; do
        for sp in broadleaf pine swamp; do
            for sy in 0 1 2; do
                for st in 0 1 2 3; do set -- "$@" tree:$s:$sp:$sy:$st; done
            done
        done
    done
    for k in food wood stone gold; do
        for st in 0 1 2 3; do set -- "$@" pile:$k:$st:a pile:$k:$st:b; done
    done
    for st in 1 2 3; do set -- "$@" yard:$st:0 yard:$st:5 garden:$st:0 garden:$st:5; done
    set -- "$@" tether_post
    for s in 0 9; do
        for sy in 0 1 2; do
            for b in 0 1; do set -- "$@" bridge:$s:3:$sy:$b:1 bridge:$s:1:$sy:$b:1 bridge:$s:4:$sy:$b:2; done
        done
    done
fi
rm -rf "$out"
(cd "$here/../.." && timeout 600 "$GODOT" --headless --path . --script res://tests/lobster_spike/prop_export.gd -- "$out" "$@" 2>&1 | grep -i "skip\|error" | head -20)
cd "$here" && timeout 600 "$LOBSTER" prop_check.lobster -- "$out" "$@" 2>&1 | grep -v "warning" | tail -400
