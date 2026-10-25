# 2026-10-25: the sim in Lobster, a spike

## What happened

Dominic asked what Lobster (Wouter van Oortmerssen's game language) would give us over Godot. Claude's answer:
for this game, mostly a fast sim. Balance by cost wants many headless matches (price-by-simulation, the round
robins), and the agent loop wants quick runs. Rather than argue it, a spike: port the movement path of `src/sim`
to Lobster and check it against GDScript tick by tick. Dominic cloned Lobster to `~/Dev/lobster`; Claude built it
(CMake) and did the port on a branch (`worktree-lobster-sim-spike`, `tests/lobster_spike/`).

`export.gd` plays two allied armies in the GDScript sim and writes the starting state, the moves and a hash of the
movement state after every tick; `sim.lobster` replays it and compares. Results: every tick matched, from 200 units
on the test maps to 2,000 on the 2v2 meadow. Movement ran about 20-40x faster under Lobster's optimizing JIT
(`--mir`): 2,000 units took 56 ms a tick in GDScript and 2.2 ms in Lobster. The Mac was busy with Dominic's local
AI tests, so the ratios count more than the times. Details: `tests/lobster_spike/README.md`.

## Decisions

None yet: this is a measurement. Whether to go further (port combat and the economy, run the Lobster sim as a
sidecar to Godot, or leave it) is Dominic's call.

## Funny moments / bugs

- The port's first divergence wasn't a porting bug. In Godot 4.7, packed arrays are shared, not copy-on-write, so
  `World._move`'s "tick start" copies are the live arrays: units later in the list see this tick's moves of the
  earlier ones. The comments in units.gd and world.gd say otherwise. Deterministic, so lockstep is fine; fixing it
  is its own change (it shifts pathing).
- Writing the port cost four compile errors, none of them a made-up builtin.

## Ideas parked

- Measure again on a quiet machine; try `--cpp`.
- Lobster threads share nothing: round-robin matches on every core would suit it.
