#!/bin/sh
# test_ai.lobster in n processes side by side (each runs every n-th piece: shard:i/n), their logs in order,
# then the checks across pieces (bot vs bot twice the same, healers heal) and the total. Exit 1 on a failure.
# Usage (any folder): tests/lobster_spike/test_ai.sh [map_id] [mode] [jobs=N]   (jobs: performance cores - 1 by default)
exec "$(dirname "$0")/shards.sh" test_ai.lobster "$@"
