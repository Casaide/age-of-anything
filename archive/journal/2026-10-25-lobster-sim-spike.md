# 2026-10-25: the sim in Lobster, a spike that became a port

## What happened

Dominic asked what Lobster (Wouter van Oortmerssen's game language) would give us over Godot. Claude's answer:
for this game, mostly a fast sim. Balance by cost wants many headless matches (price-by-simulation, the round
robins), and the agent loop wants quick runs. Rather than argue it, a spike: port the movement path of `src/sim`
to Lobster and check it against GDScript tick by tick. Dominic cloned Lobster to `~/Dev/lobster`; Claude built it
(CMake) and did the port on a branch (`worktree-lobster-sim-spike`, `tests/lobster_spike/`).

`export.gd` plays a scenario in the GDScript sim and writes the starting state, the orders as they ran and a hash
of the state after every tick; `sim.lobster` replays it (or plays its own bots) and compares every tick.

It went in steps, Dominic asking for each:
1. **Movement** (formations, flow fields, `_move`, separation): every tick matched, 200 to 2,000 units.
2. **Combat** ("port combat and the economy too"; "hills" first): targets, chasing, blows, shots that fly and
   miss, stances, fog with line of sight, high ground. Battles of up to 2,000 units matched, survivors included.
   The port was split into modules (`lib/`) on the way: same behaviour, cleaner layout; behaviour cleanups wait
   until the port is finished and checked (Dominic asked; Claude: one change at a time, each measured).
3. **The economy**: gathering at spots, carrying, building, farms, training, the map changing under the flow
   fields (patched, not re-solved). A two-bot opening matched on the first compile; changing one constant by one
   milli-tile made it fail by tick 2,132, so the check is real.
4. **The AI** ("port the AI too"; Dominic picked "keep going here" over splitting into sessions): the eco bot, then
   ages and research, buildings in combat, towers, garrisons, healers, heroes, the match rules, and the full bot
   with scouting, land (routes, studies, roads, hills) and expansion. **A 15-minute bot-vs-bot match runs in Lobster
   with Lobster's own bots, identical to GDScript on all 18,000 ticks.**

Speed (Dominic's Mac busy with other work: read the ratios): the full bot match took 1.48 ms a tick in GDScript
(sim 1.10, bots 0.38) and 0.099 ms in Lobster under `--mir`, about 15x: 27 s against 1.8 s for 15 minutes of play.
Battles ran 20-40x faster (2,000 units: 111.6 ms against 3.3 ms). Details and the table: `tests/lobster_spike/README.md`.

About 7,900 lines of Lobster. Not ported yet (asserted where they'd act): walls, gates, bridges, animals and pens,
trade, Wonders, siege, abilities, shift-queued orders.

## Decisions

None yet: this is a measurement. Whether to go further (the rest of the sim, a Lobster sim beside Godot, the brute-
force balancing it makes possible, or leave it) is Dominic's call.

## Funny moments / bugs

- The port's first divergence wasn't a porting bug. In Godot 4.7, packed arrays are shared, not copy-on-write, so
  `World._move`'s "tick start" copies are the live arrays: units later in the list see this tick's moves of the
  earlier ones. The comments said otherwise. The fix went to its own session (D-167, its own branch, not merged:
  movement came out mixed, nothing retuned).
- A healer kept walking to its old patient: GDScript's attack-move clears a healer's patient, the port didn't.
- The Lobster bots re-read every hit since the match began as a fresh raid: GDScript clears the event list each
  tick, the port never did. They answered raids from six minutes ago, and the match parted at tick 7,360.
- Lobster's own bug: its optimizing JIT (`--mir`) reads garbage for a mutable global inside an `and` chain that
  returns from within a `for` block (the default JIT is right). 25-line repro in `tests/lobster_spike/mir_repro.lobster`;
  worked round in two places. Worth reporting upstream (Dominic's call).
- GDScript's arrays answer index -1 with the last element; a bot that found no resource sends a gather to cell -1,
  which the port has to mimic (a walk to (-500, 500)).
- Agent friction: about a dozen kinds of compile error over 7,900 lines (keywords as names, declaration order, a
  line continuation, `bool` against `int`...), each fixed from the compiler's message. No made-up builtins.

## Ideas parked

- Measure again on a quiet machine; try `--cpp`.
- Lobster threads share nothing: round-robin matches on every core would suit it (brute-force balance).
- The rest of the sim (walls, bridges, animals, trade, siege) to run any map and any race.
