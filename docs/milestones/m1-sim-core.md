# Milestone 1: Sim core

**Status:** done (2026-10-10)
**Exit criterion:** the same scripted 10-minute replay gives identical hashes; sim tick at or
under 3 ms with 200 units.

## Scope
Fixed 20 Hz tick, integer maths, command queue, replay record/playback, state hash,
determinism test, and a minimal debug view.

## What was built
- `src/sim/`: `fixed` (isqrt, sin/cos table, hash mixing), `units` (parallel packed int arrays
  sorted by id), `spatial` (per-tile buckets), `commands` (4-tick turns, run at turn + 2 in
  (turn, player, seq) order), `world` (commands -> move -> separate -> hash every 30 ticks),
  `sim_map`, `replay`.
- `src/sim_clock.gd`: the one Node, stepping the World from `_process`.
- Pricing uses a fixed-point cost table (`data/cost_curves.json`) instead of `pow()`.
- `scenes/sim_debug.tscn`: UnitViews interpolated between ticks, click select, right-click move,
  F5/F9 replays with live hash checks.
- `tests/test_sim.gd`: the separate, slower suite (~45 s).

## Results
- 400/400 checkpoints identical across runs, and across a run with every race dict key-reversed
  and commands queued in shuffled order. A planted dict-order leak is caught at tick 30.
- Replay JSON round trip plays back identically; a 1 milli-tile tamper is caught.
- Tick time, 200 units, 12,000 ticks, M4 Max: **avg 0.89 ms**, p50 0.88, p99 1.21, max ~10 ms.

## Changes from the original plan
- The fixed-point cost table was listed under milestone 5; it landed here (D-021).
- Movement is straight-line with wall sliding; pathfinding is milestone 2.

## Links
- Journal: `archive/journal/2026-10-10-sim-core.md`
- Decisions: D-019 to D-024
