# Decision log

Append-only. Each entry: date, decision, why, and what it replaced. To change a decision, add a
new entry that supersedes the old one, rather than editing it.

---

**D-001, 2026-10-10: Make a classic-style RTS where your race is whatever you can describe.**
Why: the classic RTS games survived decades on community content; customising and making your own games is what
people love about it. Nobody has made creation easy for strategy games.

**D-002, 2026-10-10: Races are built from parts (Borderlands-gun style), not generated images.**
Why: deterministic, consistent style, animatable, tiny to share, and stats can follow looks.
Replaced: the early idea of runtime 2D image generation.

**D-003, 2026-10-10: No runtime AI in v1; simple deterministic NLP over a dictionary.**
Why: fast, offline, any hardware, reproducible. AI is used at dev time to build breadth (parts,
synonyms, names). Replaced: "small LLM at runtime + harness for tool calls". That's now a
post-MVP option (D-014).

**D-004, 2026-10-10: Generation happens in game; share the result (key), not just the prompt.**
Why: LLM/seed output isn't reproducible across machines; recorded results are. Sharing the prompt
stays as a "roll your own" mode. Unpredictability lives in generation, never in the simulation.

**D-005, 2026-10-10: Balance through cost.** Every part has points, and cost is superlinear.
Silly races are allowed, just priced. Later: price by simulated fights.

**D-006, 2026-10-10: Host modes: curated, bounded generation (default), no limits (later).**
Start strict: Bronze Age to Medieval.

**D-007, 2026-10-10: Frogs vs Rats ships as the default handmade matchup.**
Centaur Romans vs winged Greeks is the second test.

**D-008, 2026-10-10: Misinterpretation is a feature.** Substitute honestly with a playful note
(WW2 -> saucepan helmets). Mods and community parts fill the gaps.

**D-009, 2026-10-10: Godot 4.7 + GDScript, 2D.** Multiplayer is deterministic lockstep; transport
is a Hyperswarm/Bare sidecar later. Godot's state replication was rejected for RTS scale.

**D-010, 2026-10-10: Name: Age of Whatever** (folder `~/Dev/age-of-whatever`).
Replaced: "frogs-vs-rats" ("a terrible name"). Other candidates: Ragtag, Kitbash, Bodge.

**D-011, 2026-10-10: Build race generation first (milestone 0), then UI and gameplay.**
Replaced: the research plan's advice to cut the prompt generator from the MVP.

**D-012, 2026-10-10: Art target is the classic 2D isometric RTS look.** Familiar enough to feel like the genre you know,
gone mad. Our own art and twist; not a copy. Vector shapes are placeholders until the art pass.

**D-013, 2026-10-10: Winged Greeks means wings on their own backs** (pulp sci-fi winged men), not
pegasi. Ridden units put wings on the mount (pegasus), so mounts never float under a hovering rider.

**D-014, 2026-10-10: An LLM brief expander is the fix for cultural knowledge, but post-MVP.**
"Romans" should mean legionaries and scuta; the dictionary can't know that. The bridge step is
culture templates written at dev time.

**D-015, 2026-10-10: Humans and centaurs don't become giants unless asked.** Their large unit
is mounted or "Heavy". Signature gear (Roman, Greek, Viking, cheese) only appears when asked for,
or when it's the race's own thing (rats + cheese).

**D-016, 2026-10-10: Follow the genre's standard role structure** (buildings, ages, unit lines, counters),
with our own names, art, text and twists. MVP roster: worker, spear,
skirmisher, archer, large. See `docs/roster-template.md`.

**D-017, 2026-10-10: Keep this archive.** Pictures, decisions and directions, for AI context and
for fun.

**D-018, 2026-10-10: Dream mod: a space-fleet sci-fi pack.** Shipped content stays our own
"space federation"; official names and likenesses stay out.

**D-019, 2026-10-10: The sim stores units as parallel packed int arrays, sorted by id.**
(`src/sim/units.gd`.) A plain index loop is then the deterministic order, there are no per-unit
objects for GDScript to chase, and hot loops can work on local copies. Neighbours come from a
per-tile counting-sort grid rebuilt every tick. Claude proposed it; Dominic approved the plan.

**D-020, 2026-10-10: Lockstep turns are 4 ticks (200 ms at 20 Hz); a command stamped turn T runs
at the start of turn T+2, sorted by (turn, player, seq).** Matches design §9. Each player keeps its
own seq counter. Debug SPAWN goes through the same queue, so setups are part of every replay.

**D-021, 2026-10-10: The cost curve is a checked-in integer table, not maths at runtime.**
`data/cost_curves.json` holds per-mille multipliers by points for each curve id
(`pow1.4_ref12`, `pow1.2_ref12`), written offline by `tests/gen_cost_curve.gd`. Rules files name
a curve instead of carrying `exponent`/`ref_points`. Dominic chose the table over integer
log2/exp2 (simpler, auditable, mod-friendly). Replaces the float `pow()` in pricing; all 659
test-prompt units priced identically before and after, and no race key changed.

**D-022, 2026-10-10: Sim units: speed stat x 5 = milli-tiles per tick (10 = 1 tile/s); radius
0.3 tiles x scale, 0.42 if mounted, capped at 0.5.** Placeholder feel numbers for milestone 1;
tune in milestone 2 with real maps.

**D-023, 2026-10-10: Replays rebuild races from prompt + rules + reroll and must reproduce the
race key; maps are pinned by a content hash.** Small replays (the 10-minute test match is
~150 KB of JSON with checkpoints). Downside parked in the backlog: generator changes break old
replays, so bundles take over once races are shared as data.

**D-024, 2026-10-10: `tests/test_sim.gd` is a separate, slower suite (~45 s)** that runs the full
12,000-tick, 200-unit match several times. `run_tests.gd` stays fast. Dominic's call.
