#!/bin/sh
# The game's tests side by side (src/batch.sh): ./tests/batch.sh [--quick] [jobs=N] [only=name,...]
exec "$(cd "$(dirname "$0")/.." && pwd)/src/batch.sh" "$@"
