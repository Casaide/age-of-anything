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

**D-025, 2026-10-10: One markdown file per milestone (`docs/milestones/`).** Status, exit
criterion, scope, plan, checklist, results and changes live there; `mvp-plan.md` §3 keeps the
overview table and links. Dominic asked for it.

**D-026, 2026-10-10: Go isometric now, not at the art pass.** The sim grid stays square; the view
projects it to 2:1 diamonds (`src/view/iso.gd`). Camera, picking, box select and tiles get built
once for the target look. Dominic's call.

**D-027, 2026-10-10: Maps stay JSON; the view generates its TileMapLayer from them.** Mod-safe
(no scripts), loads headless, easy to hash. Terrain types are data (`data/terrain.json`).
Supersedes the MVP plan's "bake the sim grid from TileMapLayer custom data". Dominic's call; an
in-editor painting tool that writes JSON is in the backlog.

**D-028, 2026-10-11: Selection is view-side, in screen space.** Click, box and double-click test
the units' drawn positions, so what you see is what you select. The sim has no pick/rect query.
Supersedes the MVP plan's "against the sim's spatial hash".

**D-029, 2026-10-11: Movement = flow field per target cell + waypoint steering + move groups.**
Fields: integer Dijkstra, 10/14 costs, no corner cutting. Units aim at the furthest clear cell a
few steps down the field (or straight at the target), re-planning every 8 ticks. Each MOVE is a
group that settles when a unit bumps an arrived groupmate; settled units shoved well off their
spot walk back. Units stuck 3 s give up (tests count them).

**D-030, 2026-10-11: At most one flow-field solve per tick, queued in order.** Units whose field
isn't ready head straight for a tick or two. This makes the set of solved/pending fields sim
state, so it is hashed. Keeps the solve spike to one (~2.4 ms) per tick.

**D-031, 2026-10-11: Cut-down reeds become walkable ground.** Paths open up over a match, the
way they do in the genre. The map is mutable: resources and building footprints change it, and
every change bumps a version that's part of the state hash. Dominic's call.

**D-032, 2026-10-11: Milestone 3 builds a minimal clickable command panel plus hotkeys**, not
hotkeys only, so an opening can be played by hand. Styling comes later (and see the backlog's
race-themed UI). Dominic's call.

**D-033, 2026-10-11: The economy is data.** Resources are terrain fields (`resource`, `amount`,
`depleted`), buildings live in `data/buildings.json`, and the rules carry an `economy` block.
Race-wide economy modifiers (`cost_pct`, `train_time_pct`, `house_pop`) come from
`creatures.json`, so rats are cheap and breed fast with no rat code. They are derived, not part
of the race key.

**D-034, 2026-10-11: Train time = `rules.cost.train_base` (20 s) on a flatter `pow0.5` curve.**
Supersedes pricing's fixed 8 s on `pow1.2`, which gave 2-3 s workers. Now a worker takes
~11-14 s, a spear ~20 s, a large unit ~27 s.

**D-035, 2026-10-11: Flow fields take several sources and an optional cost cutoff; a map change
drops only the fields it touches; solves share a budget of 1,500 cells per tick.** Short work
trips ("next to this reed tile", "next to the Town Center") solve in ~0.4 ms. Supersedes D-030's
"one solve per tick" (a full solve still runs alone).

**D-036, 2026-10-11: Workers sent to a busy resource tile take the quietest tile of that
resource within 2 tiles.** Without it everyone piled onto one bush and gathering halved.

**D-037, 2026-10-11: AI players live in `src/ai/`, issue commands like a person, and follow the
sim's determinism rules (the lint covers them).** The economy bot is the first; the debug view's
F6 lets it play both sides.

**D-038, 2026-10-11: Replays pin the rules (id + content hash) as well as the map.** The
economy reads the rules, so a changed rules file must be caught. Replay schema `aow.replay/2`.

**D-039, 2026-10-11: The debug view gets army-regeneration hotkeys** (G reroll, Shift+G random
prompt, Ctrl+G random enemy). The match restarts with the new race, since swapping races mid-match
would break running orders and replays. Dominic asked for it.

**D-040, 2026-10-11: The art direction is open again; we choose from a sampler of five.**
Supersedes D-012's "painterly" as the assumed target (D-012's classic 2D isometric framing
still stands). The composer's `part_shape.gd` gained a `style` so directions can be compared
on the real parts and animation. Dominic asked for samples of every direction.

**D-041, 2026-10-11: Add a sixth direction, high-fidelity pre-rendered, built as a real bake
pipeline.** Detailed 3D models with procedural materials are baked at 4x into mipmapped sprites
(mipmaps = level of detail). Units are baked per part with their pivots and animated in 2D, as
the composer expects. Buildings are mostly static but keep "a little life" through live parts
animated in 2D (banner, smoke, glow, weathervane). Dominic asked for higher fidelity and living
buildings; Claude proposed the pipeline-prototype approach.

**D-042, 2026-10-11: The leading art candidate is high-fidelity pixel art that keeps the
original characters.** Units: each existing 2D part is auto-converted to simple lit 3D, drawn in
its 2D order, and baked to a pixel sprite. The design stays ours, and every part in `parts.json`
works with no extra art. Buildings and props: detailed matte 3D baked to pixels with ground
shadows and live parts. Terrain: one continuous shader, no grid, rounded shorelines. Everything
goes through one shared palette at art resolution. Supersedes the photoreal leaning of D-041 as the
preferred direction (the bake pipeline stays). Dominic's direction ("focus more on the pixel art
approach", "in the classic games you never think the lighting is bad"); Claude's
implementation. Not final until Dominic picks.
