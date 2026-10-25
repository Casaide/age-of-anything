#!/bin/sh
# Every spike scenario: exported from GDScript, played in Lobster (--mir), hashes compared per tick.
# Usage: tests/lobster_spike/all.sh <out dir>
out="$1"
run="tests/lobster_spike/run.sh"
$run "$out" move choke_test 100 2400
$run "$out" move reed_meadow_2v2 1000 1200
$run "$out" fight flat_test 100 2400
$run "$out" fight hill_test 50 1200
$run "$out" fight reed_meadow 100 2400
$run "$out" fight reed_meadow_2v2 500 1200
$run "$out" fight reed_meadow_2v2 1000 1200
$run "$out" eco flat_test 0 4800
$run "$out" eco reed_meadow 0 4800
$run "$out" eco reed_meadow_2v2 0 4800
$run "$out" match flat_test 0 18000
