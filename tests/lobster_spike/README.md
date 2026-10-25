# The Lobster sim spike (2026-10-25)

Would the sim be better in [Lobster](https://github.com/aardappel/lobster)? This spike ports `src/sim` and the
bots in `src/ai` to Lobster and checks the port against the GDScript sim tick by tick: a hash of the whole state
after every tick must match.

## What runs in Lobster

`sim.lobster` and `lib/` (about 7,900 lines), modules following `src/sim` and `src/ai`:

| Module | Ports |
|---|---|
| `consts`, `fixed`, `tokens`, `state` | fixed.gd, the World's, units.gd's and buildings.gd's arrays, the scenario reader |
| `flow`, `spatial`, `map` | flow.gd (fields, patching after map changes, the field cache), spatial.gd, sim_map.gd's changes, World._sync_map |
| `orders`, `movement` | formations, order_move / order_reach / order_beside, World._move with _sidestep, _queued, _passed, _plan, the spots round a rect, _separate |
| `fog` | the visible grid with line of sight, hills, buildings' sight, the memory of enemy buildings |
| `combat` | targets (counter pull, spreading), chasing, blows, shots in flight, stances, buildings as targets and surrounding them, towers, heroes' auras, deaths |
| `economy`, `tech` | gathering at spots, carrying, construction, farms, training, pop, rallies; ages, research, line upgrades, race bonuses (retype, refresh) |
| `garrison`, `heal`, `heroes`, `match` | sheltering and the call to arms, healers, heroes (auras, regen, revival), defeat and the winner |
| `eco_bot`, `bot`, `scout`, `land`, `expand`, `ai_cfg` | the economy bot (and reach.gd), the full bot, scouting and memory, routes.gd and land.gd, camps and escorts, data/ai.json |

Not ported (none in the scenarios; the exporter or the port asserts it): walls you stand on, gates, bridges,
animals and pens, trade and markets' trading, Wonders, siege weapons, abilities (webs), shift-queued orders,
game modes, cancelling, and the remembered ground (no bot reads it).

## How it's checked

`export.gd` runs the GDScript sim and writes a scenario: the state at the start (map, terrain tables,
resources, rules, unit and building types with every line step, research and race effects, every unit and
building, fog), the bot config, the orders as they ran, and a hash of the state after every tick. It also times
`World.step` against a step of only the systems the port has, and checks they give the same hashes.

`sim.lobster` loads it and either **replays** GDScript's orders, or with `bots` **plays its own bots** (the
recorded orders are thrown away). Either way the hash is compared after every tick. `dump:<tick>` and
`trace:<tick>` print the state on both sides to diff; `cmdlog` prints the orders the Lobster bots give.

Scenarios: `move` (allied armies moving), `fight` (enemy armies attack-moving, moving, changing stance),
`eco` (two eco bots' opening), `match` (two full bots, bot.gd at the normal level).

```sh
tests/lobster_spike/run.sh /tmp/spike match flat_test 0 18000   # export, replay, then the bots playing in Lobster
tests/lobster_spike/all.sh /tmp/spike                           # every scenario
```

Needs a Lobster build (`~/Dev/lobster/bin/lobster`, built with CMake; `LOBSTER=` to point elsewhere).

## Results

`all.sh`, 2026-10-26, every hash matched on every tick:

| Scenario | Units | Ticks | GDScript step | Lobster replay | Lobster with its bots |
|---|---|---|---|---|---|
| move, choke_test | 200 | 2,400 | 3.73 ms | 0.19 ms | |
| move, reed_meadow_2v2 | 2,000 | 1,200 | 47.0 ms | 2.20 ms | |
| fight, flat_test | 200 | 2,400 | 2.69 ms | 0.15 ms | |
| fight, hill_test | 100 | 1,200 | 1.07 ms | 0.044 ms | |
| fight, reed_meadow | 200 | 2,400 | 2.78 ms | 0.16 ms | |
| fight, reed_meadow_2v2 | 1,000 | 1,200 | 35.2 ms | 1.30 ms | |
| fight, reed_meadow_2v2 | 2,000 | 1,200 | 87.5 ms | 2.84 ms | |
| eco, flat_test | 2 bots | 4,800 | 0.54 ms | 0.061 ms | 0.064 ms |
| eco, reed_meadow | 2 bots | 4,800 | 0.56 ms | 0.060 ms | 0.088 ms |
| eco, reed_meadow_2v2 | 4 bots | 4,800 | 0.55 ms | 0.096 ms | 0.143 ms |
| match, flat_test | 2 full bots | 18,000 | 1.11 ms | 0.089 ms | 0.105 ms |

Times are per tick on Dominic's Mac while it was running other work (local AI tests); read the ratios, not the
times, and measure again on a quiet machine. Lobster runs with `--mir`. The GDScript column is `World.step` alone;
the GDScript bots add their thinking on top (0.38 ms a tick in the full match, measured in an earlier run), while
"Lobster with its bots" includes the bots. So the whole match is about 1.48 ms against 0.105 ms, ~14x; battles
20-30x.

## Agent friction

About 7,900 lines of Lobster, written by Claude with the language reference in hand. Every compile error was
fixed from the compiler's message: forgetting `import std`; `read_file`'s nilable string; predicates typed `int`
where comparisons give `bool`; `write_file`'s absolute-path flag; the dictionary's constructor; a line
continuation (`or` ends the line, it doesn't start the next); keywords used as names (`any`, `from`, `guard`);
locals shadowing globals (refused); fields with defaults aren't constructor arguments; two functions named
`refresh` with one int each (an overload clash); and, most often, declaration order (a global must be declared
above any function that reads it, across modules too). No made-up builtins. Bitwise operators bind looser than
`==` in Lobster; every bit operation is parenthesised.

The porting bugs the hash check found: the healer's patient not cleared by an attack-move, the event list never
cleared between ticks (the bots re-read old hits as new raids), and one GDScript behaviour (below).

## Found on the way

- **GDScript:** in Godot 4.7 packed arrays are shared, not copy-on-write, so `World._move`'s "tick start" copies
  are the live arrays: units later in the list see this tick's moves of earlier ones. The port follows what
  GDScript does (`move()` aliases the arrays). The fix is on its own branch (D-167), not merged.
- **Lobster:** its optimizing JIT (`--mir`) miscompiles a mutable global read inside an `and` chain that returns
  from within a `for` block (the default tcc JIT is right). A 25-line repro is `mir_repro.lobster`. The port works round
  it in two places (the index in a local first).
