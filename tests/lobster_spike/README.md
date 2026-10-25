# The Lobster sim spike (2026-10-25)

Would the sim be better in [Lobster](https://github.com/aardappel/lobster)? This spike ports the part of
`src/sim` a group move uses to Lobster and checks it against the GDScript sim tick by tick.

## What is ported

`sim.lobster` (~1,300 lines): formations (`World._formation`, `_slot_ok`, `_off_walls`), `order_move`, `_plan`,
`_progress`, `_move` with `_sidestep`, `_queued` and `_passed`, `_solve_queued`, flow fields (`Flow.solve`, `ahead`,
`clear_path`, `clear_line`, `nearest_walkable`, the roomy/tight grids), the spatial buckets and `_separate`.

Left out, because they're constant in the scenario (the exporter asserts it): jobs, fights, walls, rect moves,
near fields, webs, trails, wading, map changes, spawning. That's most of `src/sim` by line count (economy,
combat, walls, tech, garrison...): this measures the hottest part, not the whole.

## How it's checked

`export.gd` runs the GDScript sim: two allied armies (rats and frogs: ground and amphibious lanes, mounted
flanks, shooters) spawn round their starts and settle, then each player sends its army or a quarter of it to a
random point every 4 s. It writes the state after the settle, the MOVE commands as they ran, and a hash of the
movement state after every tick. It also checks that a movement-only step gives the whole `World.step`'s hashes
in this scenario (it does), so the movement-only timing is a fair comparison.

`sim.lobster` loads that, plays the same commands and compares its hash with GDScript's after every tick.
`dump:<tick>` / `trace:<tick>` on both sides print the state to diff when they part.

```sh
tests/lobster_spike/run.sh /tmp/spike flat_test 100 2400            # export + play: 200 units, 2 minutes
tests/lobster_spike/time_lobster.sh /tmp/spike                      # every exported scenario, default JIT and --mir
```

Needs a Lobster build (`~/Dev/lobster/bin/lobster`, built with CMake; `LOBSTER=` to point elsewhere).

## Results

Every scenario matched GDScript on every tick.

| Scenario | GDScript whole step | GDScript movement | Lobster (tcc JIT) | Lobster (`--mir`) | movement vs `--mir` |
|---|---|---|---|---|---|
| flat_test, 200 units, 2,400 ticks | 8.6 ms | 3.6 ms | 0.23 ms | 0.16 ms | ~23x |
| choke_test, 200 units, 2,400 ticks | 7.4 ms | 4.6 ms | 0.19 ms | 0.12 ms | ~39x |
| reed_meadow_2v2, 1,000 units, 1,200 ticks | 24.4 ms | 16.6 ms | 1.4 ms | 0.87 ms | ~19x |
| reed_meadow_2v2, 2,000 units, 1,200 ticks | 93.2 ms | 56.5 ms | 3.5 ms | 2.2 ms | ~26x |

Times are per tick, on Dominic's Mac **while it was running local AI tests**, so the absolute numbers are
inflated (the same 200-unit export took 1.8 ms and 3.6 ms a tick in two runs); the ratios are what to read,
and they should be measured again on a quiet machine. `--cpp` (compiled C++) wasn't tried; the Lobster docs put
`--mir` close to it.

## Agent friction

Writing the port took one draft and four compile errors, each fixed from the compiler's message in one try:
`map` needs `import std`; `read_file` returns a nilable string (`assert` it); predicates typed `-> int` where
comparisons give `bool`; `write_file` writes relative to its own folder without its absolute-path flag. One trap
known in advance: `&`, `|`, `<<`, `>>` bind looser than `==`, so every bit operation is parenthesised.
No made-up builtins. The one real porting bug was GDScript's, below.

## What GDScript actually does

The first port diverged at tick 196. In Godot 4.7 packed arrays are shared, not copy-on-write: `var xs :=
units.x` then `xs[i] = ...` writes `units.x`. So `World._move`'s "tick start" copies (`_ox`, `_om`, `_ost`,
`_owx`, ...) are the live arrays: `_sidestep`, `_queued` and `_passed` see this tick's moves of units earlier in the
list, and `_plan` reads the live stuck count. It's deterministic (lockstep is fine), but not the order-independence
the comments describe. The port follows what GDScript does (`move()` aliases the arrays); fixing the GDScript is
its own change (it shifts pathing, so the crossings and path_audit need re-running).
