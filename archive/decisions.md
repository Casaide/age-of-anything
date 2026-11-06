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

**D-043, 2026-10-11: Units are hand-modelled per part id with authored textures; the 2D
designs are reference, not a constraint.** Each part id can have a 3D model with real anatomy
(`scenes/art_pixel/unit_models.gd`), textured with SVG texture art Claude authors in
`assets/art/textures/` (no downloaded or procedural textures). Models are baked three-quarter,
and their sockets are projected into 2D (`PartShape.rigs`), so recipes, composition and
animation are unchanged; parts without a model fall back to the automatic bake. Parts are
layered by child order instead of `z_index` (which is global and broke y-sorting). Building
ground shadows are baked in a shadow-only pass, with light from the screen's upper left.
Dominic's direction (reference not exact; real textures, authored by Claude); Claude's design.

**D-044, 2026-10-11: Paths are generated, and their style is part of the race's culture.**
`families.json` gives each family a path style and width (imperial and hellenic: paved roads
with kerbs; swamp: plank boardwalks; sewer and royal: cobbles; others: dirt trails). A view-side
generator (`scenes/art_pixel/paths.gd`) routes each side's paths from its main building to its
other buildings, nearest resources and the shore, with merging trunks and smoothed bends.
Cosmetic, deterministic. Dominic's idea ("Romans should get nice roads"); Claude's design.

**D-045, 2026-10-11: Buildings follow the race's culture, like paths.** `families.json` gives
each family an `architecture` (sewer: "junk", others "thatch" for now). The view picks building
models by it: sewer rats build a scrap Town Center and tin-can houses. More architectures come
with more cultures. Claude's design, continuing Dominic's "part of the race" idea from paths.

**D-046, 2026-10-11: Baked art shares one atlas and one material; team colour comes from a
baked key.** Unit parts are baked with a magenta team key and recoloured by
`src/team_mask.gdshader`, with the team colour in `self_modulate` (and the far leg's shade in
its alpha), so one bake serves every team. All baked unit parts, unit shadows and scene sprites
are packed into one atlas (`PartShape.build_atlas`). Measured: 20 draw calls at 211 units vs
2,137 without. Retires the MVP plan's batching risk. Claude's implementation of the plan's
"params in modulate" idea.

**D-047, 2026-10-11: Landscape props and building materials use authored textures, and contact
shadows are drawn rather than lit.** Reeds, bug bushes, lily pads and roof thatch use Claude's
authored SVG textures (as D-043 did for units), replacing stretched noise. Every baked building
and prop gets a short hand-drawn-style dark band under its lowest pixels, plus an
ambient-occlusion pass, because lit contact shadow alone didn't survive pixelizing. Asked for by
Dominic ("lack of shadow at points like this"); approach by Claude.

**D-048, 2026-10-11: Every part is modelled; fused mounts have their own body; architecture
grows to stone and tent.** No unit part relies on the automatic fallback any more. A fused mount
(the centaur's horse half) uses the mount creature's `fused_body` (`body.pony_fused`, the pony
without its neck), and the rider stands at that body's seat; this only changes the view, not
recipes or race keys. `families.json` `architecture` gains "stone" (imperial, hellenic, royal)
and "tent" (steppe). Claude's call, following Dominic's "finish the art before moving on" and his
earlier "Romans should get nice roads".

**D-049, 2026-10-11: Every unit shows its team on its body, and building materials are
authored.** After an independent art review (an agent Claude ran at Dominic's request), every
frog, rat and human wears a team-colour kerchief drawn above armour, and human tunics are the
team colour, with culture shown in sleeves, trim and trousers (supersedes the tunic colours in
D-048's people). Building materials use authored SVG textures, like units (extends D-047).
Items not fixed yet are in the backlog, section 9.

**D-050, 2026-10-11: Woodland kit is signature gear, and optional gear never goes off theme.**
Acorn caps, leaf hats and capes, bark armour and lily-pad shields carry a `woodland` tag, which
joins the signature tags: they only appear for swamp and forest peoples (or when asked for).
Optional slots now drop off-theme candidates instead of just scoring them down, because a
worker's only cheap helmet was the acorn, so Roman scavengers wore acorns (spotted by Dominic).
Race keys for affected prompts change.

**D-051, 2026-10-11: The game view uses the pixel art; the placeholder views are deleted.**
`src/view/art/` holds the art kit (bakes units, buildings and props per match into the one atlas),
the terrain view (shader ground from a SimMap, rock in the mask's alpha, culture paths, seeded
doodads) and the building view. sim_debug bakes before a match starts, zooms in whole art pixels
(0.5x to 3x), and offers the palette as a screen pass (P, off by default: it's costly at full
resolution). Dominic asked why sim_debug still showed the old art; Claude moved the slice ahead
of the combat visuals. The 2D shapes in parts.json stay: they're the data contract, sockets and
the fallback for parts with no model.

**D-052, 2026-10-11: Direction for later: asymmetric race mechanics and a starter roster led
by animals and bronze/iron age cultures, non-European first.** Dominic: small but key mechanics
per race type (amphibians build on and swim in shallow water, Roman pilum throws, viking shield
walls), to be explored in a later milestone, and a launch roster of animals (bears and beavers
under consideration) and bronze/iron age cultures (vikings, Romans, Egyptians, Greeks and a few
more), with non-European animals and cultures an absolute priority. Recorded in the backlog §8
and the design doc §8; nothing built yet.

**D-053, 2026-10-11: Static props are drawn realistically; knight kit and bat wings are
signature gear.** Dominic: "for static items I prefer more realism" (with the genre's berry bushes
and stone piles as reference). Units stay stylised and outlined for readability; props
(bushes, rocks, doodads) are baked realistically, without the units' outline: bushes as dense
small-leaf shrubs with berries, rocks as noise-broken faceted stones. Separately, centaur Romans
wore the knight's iron helmet and winged Romans got bat wings: knight kit (iron helmet, kite
shield, mail) is now the royal culture's signature, bat wings the spooky/sewer one's, feather
wings are generic, and heavy units no longer "want" knight kit. A test checks that no culture
gets another's signature kit.

**D-054, 2026-10-11: Armour classes from the start; attack-move spreads out.** Dominic: all
armour types now (the genre's melee/pierce plus per-class armour), not one value, "so we don't
miss something important". And attack-move should spread units over the enemy line (each picks
a foe few allies are already fighting; a unit leaves a crowded foe for a free one), making
battles a set of duels that winners reinforce. The direction: combat a step more organised and
exciting than the genre's usual, short of the big-battle games, still easy and fun, and ready
for formations later (formations themselves stay cut for now).

**D-055, 2026-10-11: Combat stats follow the genre; upgrades swap parts, so units change look.**
Armour is two visible numbers (melee, pierce) plus hidden per-class armour, with flat
subtraction, the genre's standard (confirmed with Dominic after comparing how the genre's games
do it). Counters come from bonuses and from pierce armour on cavalry and skirmishers, and the
unit card shows "strong vs / weak vs" in plain words. Dominic: unlike the genre, upgrades should
change the unit's look. An upgrade swaps parts in the recipe (leather -> mail -> plate), the
stats follow from the parts, and existing art is reused. Planned for milestone 5 (see its design
notes).

**D-056, 2026-10-11: New milestones 5 (art rework) and 6 (foundations); the rest move back.**
Dominic: the current art round becomes milestone 5. A new milestone 6 pulls forward the
architecture that gets harder to retrofit:
- resources from data (stone from rock outcrops);
- movement classes (ground, amphibious, flying);
- placement rules per race and building;
- teams;
- data-driven ages and tech;
- per-race farms.
Progression, AI and match flow, fog and juice, and the playtest become milestones 7-10. Claude
finishes milestone 4, then starts milestone 6 while the art agent finishes milestone 5.

**D-057, 2026-10-11: Gear goes up with the ages; the blacksmith only adds small tells.** Dominic:
centaur Romans already in lorica "feels like we've skipped progression"; a culture can't look
fully armoured in every age. Parts get an age tier, and the generator writes each unit line
through the ages (light kit first, bronze and mail, then iron and plate, within the culture), so
a frog visibly toughens over the eras. Unit-line upgrades also change the look. Blacksmith
upgrades change numbers, with at most a subtle, consistent tell (Claude's suggestion, agreed),
to keep silhouettes readable and bakes few. The counter quiz is reshaped: name roles from
silhouettes, then predict counters with the unit card (Dominic scored 50% judging by gear
quality; the equal-cost counts and roles didn't come through). Planned in milestone 6.

**D-058, 2026-10-11: Bows for everyone; crossbows are royal and rat kit; shift-queued orders.**
Dominic noticed every archer had a crossbow and nobody a bow. The short bow carried the `greek`
signature tag, so it was off theme for everyone else. Now the bow is generic, and the crossbow
is signature kit for the royal culture and the rats (or anyone who asks; "crossbow" is in the
lexicon). Separately, orders can be shift-queued per unit (milestone 6, at Dominic's request).

**D-059, 2026-10-11: Winged races fly instead of riding.** Dominic: a flying race should have
wings on the person and the mount, or no mounts. Now:
- A race that asked for wings doesn't ride: its large unit is a giant or a heavy elite (like
  centaurs going heavy).
- Asked for mounts too ("winged knights on ponies"), rider and mount both get wings.
- "Pegasus" words give only the mount wings (they no longer make the whole race want to fly).
- The mount wing socket moves to the withers (art track).
Supersedes the part of the generator rules that put wings on the mount only.

**D-060, 2026-10-11: Game scenes draw only the baked art; a missing bake is loud; the style
sampler is retired.** `PartShape` draws only baked sprites (supersedes the fallback to plain
shapes in D-042/D-043): a part drawn without a bake warns once and shows a magenta marker. The
Race Lab bakes each race through the art kit and uses the game's ground. The 2D shapes in
`parts.json` stay as the data contract and socket reference, never drawn. The style sampler
(D-040, D-041) is deleted; its pictures stay in the archive, and the bake pipeline it held moved
to `src/view/art/bake/`. Dominic's call ("so weird I'm seeing it in the race lab"; "ignore the
sampler, it's history"); Claude's implementation.

**D-061, 2026-10-11: Buildings y-sort by their footprint's centre.** Not their front corner,
which hid units standing beside a building's lower faces. Art that spills past the footprint
(a podium) doesn't move the sort point. Found by Dominic (a centaur beside the Roman Town
Center showed only its legs); fix by Claude.

**D-070, 2026-10-11: Restrictions are layers, and each is a host switch.** (D-060 to D-069 are
reserved for the art agent's milestone 5 entries.) Dominic: frogs with muskets are too much fun
to forbid outright. The layers:
- era (host rules; "Anything goes" already allows gunpowder);
- culture and theme;
- each race's tech tree;
- a "Full tech tree / No restrictions" host option, as the genre has, that lifts the culture and
  tech limits.
Tech tree data is to be planned so each layer is a filter that can be turned off (milestone 7).
||||||| 6948828

**D-071, 2026-10-11: Age-ups need a building of the current age.** That's the genre's pacing
lever: a Barracks before age 2, a Stable before age 3. Age 2 costs 500 food and 200 wood and
takes 90 s, tuned so the economy bot ages up at minutes 4-6 for both frogs and rats (the
milestone 7 exit criterion), with no per-race special case. Claude's call.

**D-072, 2026-10-11: Unit textures are generated, big-marked and mapped in world space.** Unit
parts are tiny when drawn (a texture tile covers 10-20 art pixels), so their surface textures
carry a few large, high-contrast marks (toad blotches, fur tufts, cloth folds, shell plates)
rather than fine detail, written by a script (`tests/gen_unit_textures.py`) so they can be
re-tuned together. They map in world space, because the models are built from scaled
primitives. Dominic asked for "real textures" on units; the approach is Claude's call.

**D-073, 2026-10-11: Creatures can override their culture's architecture.** A creature in
`creatures.json` may name an `architecture`; otherwise the family's applies. Frogs build reed
domes on stilts, beetles and spiders dig earth mounds; humans and others keep their culture's
look. Dominic's idea (amphibians and bugs shouldn't live in timber houses); built by Claude.

**D-074, 2026-10-11: Unit art is designed concept-first.** Several distinct variations are
rendered close up and at game scale (`tests/concept_sheet.gd`, `docs/concepts/`), Dominic
picks, and only then is the pick built. This replaces slowly iterating on the first design.
Dominic's call ("really need design input here, not iterations"). Round 1 (age-1 head gear)
showed that at game scale head gear gets about 3 pixels, so culture identity has to come from
big shapes; head size is the first question.

**D-075, 2026-10-11: The AI is data plus counter-reading, and the match setup is the front door.**
The bot's build order, wave timings and sizes live in `data/ai.json`; what it trains is picked by
reading the enemy army's tags against its own bonus classes, so it adapts to any generated race
without special cases. A player is out when their Town Centers are gone or they surrender.
The match setup screen became the main scene (the Race Lab is a button on it). Claude's calls.

**D-076, 2026-10-11: Workers have one price.** A worker's value is what it gathers, and every
body gathers at the same rate, so workers cost `rules.cost.worker` (30) whatever their body,
still scaled by a creature's economy (rats stay cheap). Pricing by points made a centaur worker
cost 75 and crippled centaur starts. Bigger bodies still make sturdier workers. Claude's call;
Dominic may overrule.

**D-077, 2026-10-11: Pacing is a tester metric; bot matches are a guide.** The AI keeps a small
guard while saving for an age, which lengthens bot-vs-bot matches (median ~14 minutes). Claude
had removed it to hit a 9-12 minute bot median, then put it back after Dominic asked what was
wrong with it: the AI should play sensibly, and the bot median is reported, not enforced.

**D-078, 2026-10-11: Workers' costs vary with their body; creatures pay it back in data.
Supersedes D-076.** Dominic: a centaur should move faster, carry more and be harder to kill
than a human, and cost more for it. Worker cost is points-priced again; a creature's economy
can now set `carry_pct` (centaurs carry 160% a trip), alongside the existing cost and
training modifiers. Dominic's call.

**D-079, 2026-10-11: Farms are one thing, walkable, and reseeded.** Dominic: farms should work
like the genre's later classics: one farm (not four tiles that each run out), units walk across
it, and a worked-out farm can be restarted. A finished farm keeps its building; its tiles share
one pool of food (`SimMap.make_pool`, 400 food). Worked out, it lies fallow; a worker reseeds it
for 40 wood (`RESEED`, right-click). Razed, its ground returns to grass or shallows. The view
draws it flat under the units, with crops on every tile. Dominic's call; built by Claude.

**D-080, 2026-10-11: The look follows the design review; buildings share envelopes and may sit
lower.** Dominic approved the review's five rules (played straight; structure, not stickers;
silhouette first at 8 px; one body language and one scale ladder; each age one whole step) and
its process (brief, 3-5 options at game scale, his pick, build). Building scale: one footprint and
one height envelope per type for every culture; a culture may sit shorter and melded into its
terrain, never taller or bulkier. Rules by Dominic and Claude, scale refinement by Dominic.

**D-081, 2026-10-11: Human buildings read biggest; creature cultures' ages follow their
psychology.** Refines D-080. Same footprint for all, but human buildings always look the
biggest; creature buildings sit smaller and lower, blended into the ground (the rat Town Centre
is now the smaller, plinthless hall Dominic picked). Each culture's age story comes from how its
people feel: rats, frogs and bugs are proud and, by the top age, earnestly emulate the humans
(rats' oil-drum columns copying the Romans); bears and beavers ignore humans and build their own
impressive late-game halls. Dominic's direction.

**D-082, 2026-10-11: Archers are a balance problem, not a behaviour one.** Archers don't keep
their distance on their own in the genre (Dominic). The distance rule tried in milestone 10 is
removed. Fix by price and counters: bows cost 2 points, skirmishers' bonus against archers
rises to 6. Cost-sanity outliers 10 -> 8 of 20; counters still 82%. Claude, after Dominic's
question.

**D-083, 2026-10-11: The slim rat is the rat.** Dominic confirmed the approach: the lean,
hunched rat on the paint-over hybrid pipeline, with the scarf and armour fitted to it. Body armour
is modelled for wide bodies, so each body places and squeezes it (`torso` socket and
`torso_scale`); the rat's sits on the chest now.

**D-084, 2026-10-11: Picks for the rats, beetles and humans.** Dominic picked: the rat kit
ladder as shown (RB2: thimble, tin skullcap, spoon helmet with a toothbrush crest; bottle-cap
jerkin at age 2, sardine-tin cuirass at age 3; can scutum), the capybara as the rats' large unit
(RB1), rearing beetles (BG1), and Blender for modelling human parts (installed). The saucepan
helmet loses its junk/sewer tags, so rats no longer wear it; it stays the WW2 substitute.

**D-085, 2026-10-11: Team colour on buildings is quiet.** No pennants on every building: one
subtle team mark each (door curtain, trim, a rag), and only the town centre flies a banner.
Dominic ("looks like golf ... should be more subtle"). Units keep their team region.

**D-086, 2026-10-11: Short bows cost 3 points (was 2).** Adding the rat kit reshuffled the
generator's rolls, and the Greeks rolled a bare 20-cost archer: 30 of them beat equal-cost slingers
and counters fell to 73% (floor 75%). At 3 points counters are back at 82%. Supersedes the bow
price in D-082 (the skirmisher bonus stays). The generator's sensitivity to new parts is a
reminder that balance needs price-by-simulation (backlog). Claude.

**D-087, 2026-10-11: Units have 8 baked facings, none mirrored.** As Dominic asked earlier (8 baked
facings, all directions). Every modelled part bakes at 8 camera angles 45 degrees apart; each bake
brings its sockets, how near each socket is to the camera (so a cape draws over the body walking
away and the far hand's shield goes behind) and which way the model faces on screen. A unit takes
the facing that best fits the way it moves, works or attacks, and only switches when another fits
clearly better. Parts with no model keep their one view and still mirror. Claude.

**D-088, 2026-10-11: Animals belong to "gaia" until claimed or killed.** Wild animals are owned by
a world slot one past the last player, on a team of its own: anyone can hunt them, but idle
soldiers and towers don't attack them on their own (`is_foe` vs `is_enemy`). Sheep go to the
first player whose unit comes within a few tiles; a dead animal leaves a carcass (a food terrain
that turns back to grass) and the workers who killed it gather it. Animals are data
(data/animals.json) and a host rule (`animals`, on by default). Replays now carry their rules,
and rules hash the same whether numbers come back as ints or floats. Dominic asked for animals
(to hunt, and to herd like sheep); the design is Claude's.

**D-089, 2026-10-11: The rats' Town Center grows oil-drum columns at age 3.** Dominic loved the
RB3 "pride" concept: at the top age the rats' hall gains a porch of stacked oil drums, a pediment
cut from a cracked dinner plate and a forecourt of broken crockery, copying the Romans (the
psychology rule). Buildings can now change look per age as data (`age_looks` in buildings.json);
this is the first. The rest of RB3 (houses, barracks) still waits on his picks.

**D-090, 2026-10-11: The rats keep their tin-can house and junk barracks, smaller; houses come in
variants.** Dominic preferred the originals to the RB3 options, "just need down scaling", and
found cans and sardine tins as whole buildings push the scale too far into the unreal. A culture
can now size a building type in data (`scale` in buildings.json: the rats' house 0.72, barracks
0.8), and houses bake in four variants (a quarter turn each, nudged in size) that each building
picks from by where it stands, like the rocks. The RB3 town-centre pride step stays (D-089).

**D-091, 2026-10-11: Egypt, Han China and the Aztecs are cultures (data), the saucepan is only
for war words.** As Dominic asked ("all three"): families nile, han and aztec with their own
cloth, name parts and paths; words egypt/egyptian(s)/pharaoh/nile, han/china/chinese,
aztec(s)/mexica. The Aztecs have no mounts, so their large unit goes Heavy. They wear the shared
kit until their gear-by-age concept round. The saucepan helmet became a signature item, worn only
when a war word asks for it (it had leaked to everyone once it stopped being rat junk). Claude.

**D-092, 2026-10-11: Cultures can prefer skins (data).** Dominic: "The Aztecs are white with
stubble?" Skins were picked only from the creature, so a human culture could be any skin.
Families can now list `skins` (families.json); the generator picks from the creature's skins that
the culture prefers, or all of them when none match. Aztec and Nile people are tan or dark, Han
light or tan. Race keys stay deterministic (the pick uses the race's own rng). Claude.

**D-093, 2026-10-11: Human faces shade softly.** Every human had a dark band from ear to chin
that read as stubble. Test renders ruled out hair, the neck, cast shadows and ambient occlusion:
the bake's painted bands are fixed brightness steps, and the jaw's shade fell a whole step below
the cheek. The face's skin now carries about half its light itself (lower albedo, emission), so
its shading stays within a band; faces are a little flatter, which suits 30-pixel heads. A gentler
jaw in the Blender head came with it. Claude.

**D-094, 2026-10-11: Every rider shows its near leg.** Dominic: "riders legs missing?" Only
clinging riders (spiders, beetles) had legs; people sat legless on their mounts. All riders now
get the near leg down the mount's flank, held still; the far leg stays hidden. Fused mounts
(centaurs) are unchanged. Claude.

**D-095, 2026-10-11: The centaur grows out of the horse.** The human half stood on the horse's
flat back like a legless rider. The fused horse body now has a chest that rises at the front into
the man's waist, under the tunic's hem, and the man stands over it. Horse thighs start inside the
barrel on every horse, so they no longer hang under it like eggs. Claude.

**D-096, 2026-10-11: Body armour can be modelled for a body.** Worn armour was one generic model
scaled onto each body (`torso_fit`), which on the Blender human torso bulged out of the belly
seen from the front. The bake now first asks for `armour_<kind>_<body>.glb`, built in the body's
own space (`tools/blender/human_armour.py`), and only fits the generic model when there is none.
Humans have a fitted leather jerkin and bronze cuirass; the other armours and bodies keep the
fitting. The human leg is a Blender model too; arms stay in code because the game poses them per
weapon. Claude.

**D-097, 2026-10-11: The Fable second pass's polish is done.** Costs under buttons are numbers
with resource icons; the age-up card says "Becomes:" for renamed lines; tips sit under the top
bar (tooltip cards covered them); the portrait frame stays square; the lobby roster lists each
unit with its portrait; tool cursors carry a pointer tip as their hotspot; swamp pools are few and
broad; mineable stone shows a split face and cut blocks; builders' mills stand on a plinth under
their roof; the boar has a pink snout. Claude.

**D-098, 2026-10-11: The Nile, Han and Aztec kits go in as drawn (GC1), culture gear from age 1.**
Dominic picked "all as drawn" and asked why the culture weapons should wait for age 3: age 1 is
more varied. Every Nile, Han and Aztec unit wears its culture's head gear by age and carries its
culture's shield from age 1. The Han halberd (a spear, so the spear line keeps its counter) arms
the spear line at every age (wood, bronze, iron). The sickle sword and the obsidian club aren't
spears, so they arm the large unit when it opens (Dominic's choice over adding a sword slot).
New data: parts carry a `favour` that pulls a culture's own weapon over the role's usual pick, and
the primary pick now respects `requires_role`; nile, han and aztec are signature tags. Claude.

**D-099, 2026-10-11: Spiders rear up (SG1).** Dominic's pick: the abdomen low behind, the front
body raised, the front legs used as arms holding the gear, six legs to walk on. Ridden spiders
keep a saddle cloth on the abdomen. Head gear on spiders is scaled to the small head (an acorn cap
had covered it whole: "What's on the spiders head?"). Claude.

**D-100, 2026-10-11: Unit lines upgrade one at a time, researched where they train.** Dominic:
"upgrading a unit should be upgrade per unit - not a one off". An age-up no longer moves every
line to its next kit. Each trained line (not workers) has a line upgrade per later age
(`line.<slot>.<age>`, made from `tech.json` line_upgrades and the buildings' `trains`), done at
the building that trains it once you're in that age: age 2 costs 150 food and 100 wood, age 3
250 food and 150 gold. Workers still follow the age. The bot buys an upgrade when it has twice
its cost in stock. Supersedes the age half of D-057 (gear still goes up with the ages, now by
upgrade). Claude, on Dominic's call.

**D-101, 2026-10-11: The archery range and armoury open in age 2.** Dominic: they could be
built in the first age, which is wrong for the genre. Age 1 has the barracks, houses, camps,
farms and walls; the archery range, armoury, stable, market and watchtower come with age 2
(Sharp Sticks moved with the armoury). The bot builds its range in age 2.

**D-102, 2026-10-11: Small rules from Dominic's play.** A shift-queued build lays its foundation
at once (paid), so you see the plan, and the workers come to it in turn. Builders of a camp
(mill, lumber camp, mining camp) go and gather what it takes in. A claimed sheep walks to its
owner's nearest Town Center. Double-click selects only your kind of unit with the same owner
that you can see. The age-up button shows only at the building that does it (a missing
requirement made every building offer it). Claude.

**D-103, 2026-10-11: Sound is rendered files from our own synth; the creatures talk; the theme
grows by age.** Dominic asked for the effects reworked "from ground up" and for music. The
placeholder GDScript synth is gone. `tools/audio/` (pure Python, deterministic, no dependencies
and nothing downloaded) renders every effect (two to four takes, physical: wood, stone, hide,
reed, bronze), eight creature voices (select, ack, die) and one theme as six seamless stems
into `assets/audio/`, which the game plays through buses (`src/view/audio.gd`,
`data/audio.json`). The stems are mixed by age (lute and drum from age 1, flute and drone from
2, horns from 3) with a battle layer while your units fight on screen. Stings share the
music's instruments and key. Nobody has listened yet; Dominic's ears decide what changes.
Claude.

**D-103, 2026-10-11: Easy keeps a small army and sends a few at a time.** Dominic: the AI came
straight at him and wiped him out as he reached age 2. Easy only delayed its waves and halved
their minimum size, but a wave sent the whole army and the bot never stopped training. Levels in
`data/ai.json` can now cap the soldiers kept (`max_army`, Easy 10 population) and the soldiers
per wave (`wave_max`, Easy 5); a capped level's home guard stays home. Against a passive player
Easy's first kill is at about 10:47. The lobby says what each level does. Normal is unchanged.

**D-104, 2026-10-11: Normal is gentler; the lobby just says Easy and Normal.** Dominic: the
lobby shouldn't explain the levels, and Normal should be gentler. Normal's first wave comes at
6:00 instead of 4:00, it sends at most 8 soldiers a wave and keeps at most 20 population of
soldiers. It still beats a passive player (about 12:00); bot matches run 10:37-11:19.

**D-105, 2026-10-11: Levels differ in how the bot plays, not in caps (supersedes the caps of
D-103 and D-104).** Dominic: a capped army bores a human in a long game (40-minute games to the
last age are normal in the genre), and easier bots in the genre focus less on fighting and build
up more. No level caps the army now; every bot can grow to the population limit (200 per player,
the genre's usual). Data in `data/ai.json` levels: `army_ratio` keeps soldiers in proportion to
workers and grows with each age (Easy 35% per age, Normal 70%, Hard no limit); `wave_pct` sends
part of the army each wave and the rest defend (Easy 40%, Normal 70%, Hard all); `build_up` has
Easy and Normal research gathering and line upgrades before soldiers; first waves at 9:00 (Easy),
6:00 (Normal), 4:00 (Hard: the rushy one, Dominic agreed). Easy has about 24 population of
soldiers in its first ten minutes; Hard beats Normal.

**D-106, 2026-10-11: The full land tech tree is planned as data, in two milestones.** Dominic
asked for a tech tree page showing what a race can do and its bonuses, with the whole planned tree
on it (no icons for what isn't made), and for a complete land tree with every building, walls,
the castle and towers; no ships or flying craft yet. The tree is in `docs/milestones/m12-tech-tree.md`.
Planned items live in `data/` with `"status": "planned"`: the page draws them as blank frames,
the sim and menus skip them. Dominic's calls: four ages (age 4 "Shiny Age" for now); the work
splits into milestone 12 (page, race bonuses, age 4, research, walls and gates, towers, garrison,
Castle, University, Wonder) and milestone 13 (the new unit lines, siege, mystics, war beasts);
races lack a few items each, lifted by the host's Full tech tree; the Wonder is in. Race bonuses
become one data field on creatures and cultures, and stat bonuses are applied before pricing so
units pay for them. Names of everything are ours. Plan by Claude.

**D-107, 2026-10-11: Fixes from Dominic's play while planning milestone 12.** The worker's build
menu has two pages, civilian and military (Dominic). The stone wall opens in age 2 (it had slipped
into age 1; supersedes that part of D-101); a wooden palisade will hold age 1. Soldiers no longer
pick animals as targets on their own, and a rival's sheep changes hands when your unit is near it
and none of its owner's are, as in the genre (Dominic: "we auto attack and kill enemy sheep").
Bug bushes hold 150 food, not 2,000, so farms matter early (Dominic: bushes last far too long);
the bot builds a farm for each food worker the wild food near home can't feed, only while its food
stock is low, reseeds worked-out farms, and moves gatherers off any stock over 1,000; its age-1
mix is 50/50. Bots still age up at about 5-6 minutes; bot matches 11-14 minutes. Claude.

**D-104, 2026-10-11: Stuck means no net progress, and the choke map leaves the lobby.** A move
counted as stuck only when a step moved nothing, before the separation pushes; a unit shoved
straight back every tick (a sheep wedged by a planted builder, a gatherer jostling at a full
bush) was never stuck and never gave up, re-planned or re-picked, so it jittered for ever.
Progress is now measured every two seconds along the flow field (a cell's cost per check) or
as the crow flies on the last cell; no progress twice is a give-up (six times for a group at a
gap). Around it: a line-of-sight check as wide as the body for waypoints, bodies eased off
blocked ground at a capped rate instead of teleported, flow fields that lead to a blocked
source's corners, a crowded-off gatherer taking the clump's least busy other tile, claimed
sheep rotating their spot. `choke_test` has no food or wood (a movement test map), so it left
the lobby; it stays in sim_debug. Measured by `tests/path_audit.gd`. Dominic asked, Claude.

**D-105, 2026-10-12: Work animation: baked arm poses (W1), the centaur kneel (C1), head-digging
for armless creatures (A1).** Dominic's picks from the concept sheets (`tests/anim_concept_sheet.gd`,
pictures in `archive/images/2026-10-12/`). The rig keeps its one baked body, but workers' bodies
are baked in three arm holds (their own, "raise", "reach") and the work cycle swaps between them,
the tool following the hand: wound up behind the shoulder, coming down, the blow reaching out and
down; foraging reaches in, then lifts. A fused mount kneels to forage: the front legs fold short
with a small forward knee, the chest dips about the feet, the rider half comes forward. Armless
creatures work with the head and the whole body, rearing back between blows. Attacks and deaths
wait for the next concept round. Dominic picked, Claude built.

**D-106, 2026-10-12: Attacks step in, archers snap on the release, deaths go by body shape (T1,
R1, D3).** Dominic's picks from the second concept round. A blow is a lunge: the body steps
forward and leans, the near leg steps, the arm swings through its baked holds (wound up, then
reaching into the blow); a spear thrusts; an armless creature butts with its head. Every body
with arms is baked in the work holds now, soldiers included. A release snaps the archer forward
and kicks the bow, then settles. The death belongs to the view (`UnitView.die`): a hopper gives
one last hop and lands on its back, a flyer drops to the ground and then topples, four or six
legs fold and the body sinks (a rider slumps), a biped topples backwards away from the blow and
bounces once; `combat_fx` only times the fade and the dust. Dominic picked, Claude built.

(Numbering note, 2026-10-12: two sessions both used D-104 to D-106; entries from here on start at
D-108 to keep numbers unique. Old entries are left as written.)

**D-108, 2026-10-12: Playtest fixes and features, done by parallel agents and merged into main.**
From Dominic's notes while playing: unit stances (aggressive, defensive, stand ground, no
attack) as a per-unit sim field; watchtower arrows drawn (they hit but didn't show; attack 5 to
10 pierce); right-click a drop-off to unload, rally points centred on resources; the bot hunts
sheep, deer and boar; line steps named for what got better, and a step with no new kit isn't
sold; the HUD scales with screen density (a saved UI size, 60% of density by default; Cmd/Ctrl
minus and plus); the panel groups its buttons; house variants keep their door in view; ranged
units hold their ground in range (the attack-move's walk-back pulled them forward); fog keeps
what each side last saw (enemy farms and buildings don't leak); research queues with units in a
building's one queue; queued orders show as routes with a baked waypoint pennant; one farmer
per farm (data `workers`), only your own farms; builders go on to nearby foundations;
gathering research opens in age 2; archers and skirmishers start at age 2 with their range; the
armoury is a civilian building. Centaurs struggling against spiders is the genre's counters
(every centaur is large and mounted), left to pricing. Claude, on Dominic's reports.

**D-109, 2026-10-12: Walls and gates as built.** A palisade (age 1, wood) and the stone wall (age 2);
gates are 3 tiles long, placed into a wall line (they replace the tiles under them, `replaces`),
open only for their own team (a walk grid per movement class and team, flow fields keyed by
lane), and stay shut with an enemy near. Buildings have rectangular sx x sy footprints. Walls
join in every direction from a baked post plus up to eight baked arms; a diagonal step needs both
corner cells open, so walls touching at a corner hold. The walls' look skipped a concept round
and waits for Dominic's eye. Claude.

**D-110, 2026-10-12: Three ages, no Temple, a healer at the Town Center; nothing thrown away.**
Dominic: "lose age 4, and the temple", then "don't throw anything away". Age 4 and its fourth
steps, the Temple, mystics and their research are parked whole in `data/later/age4_and_temple.json`
(not loaded) and listed in milestone 12 and the backlog. The healer (age 2, Town Center) heals
3 hp every 1.5 s within 2.5 tiles, never fights, costs mostly gold, its own random stream so
other lines keep their kit; looks from concept sheet HL1 (A for most, cheese for rats, lily for
frogs) await Dominic's pick. Sharp Sticks starts an all-melee track. Claude, Dominic's calls.

**D-111, 2026-10-12: Research effects share one data shape.** A scope (a unit tag with an
optional `not`, or a building), a stat, and an `add` or a signed `pct`, instead of a key per
effect kind; milestone 14's race bonuses will reuse it. 19 more research are live (Town Center,
camps, the armoury's six two-step tracks, barracks, range, stable, market), each with its own
icon; the bot builds an armoury and a mill and buys research. Claude.

**D-112, 2026-10-12: Reed Meadow in two sizes; the 1v1's resources come before new units.**
Dominic: the test map ran dry. One symmetric layout from `tools/maps/reed_meadow.py` at 64 x 64
and 88 x 88, about three times the wood, twice the gold and 2.5 times the stone per start, sheep,
deer and boar; `tests/resource_audit.gd` shows nothing near home runs out before 25 minutes
(the first map's ran out at 21-23). Claude recommends the 88; Dominic picks by playing.

**D-113, 2026-10-12: Milestones 13-19 planned.** 13 unit lines (siege, castle units, war beasts;
the 1v1 map first), 14 race identity and heroes (bonuses mixed from group, creature and culture,
the same count for every race; one signature mechanic per race from a shared vocabulary;
land-shaping only as reversible race abilities; a generated hero per race), 15 maps and land
(trees, rivers, bridges, worn paths instead of road building, high ground, a 2v2 map), 16 sieges
and the first game modes (walkways, ladders, breaches; Fortress and Siege modes; the tick budget
measured, not assumed), 17 living towns, 18 match rules, 19 UI that feels like the game (the UI
wears the race; loaders; a lobby redesign). Battle mode is in the backlog. Dominic's directions,
Claude's plans.

**D-114, 2026-10-12: The lobby rolls the dice.** Every side starts with a rolled race (random
words from the lexicon); a big dice above an empty prompt box rolls a new race, or another roll
of typed words; no presets menu. Dominic's call.

**D-115, 2026-10-12: The working title is "Age of Anything".** Renamed from "Age of Whatever"
(Dominic: "sounds better for now"); the folder and repo keep the old name; a trademark check is
still due before any public release. Claude offered names without "Age of"; Dominic kept the
pattern for now.

**D-116, 2026-10-13: Rats are human-sized; no tiny found objects for new rat art.** Dominic, on the siege
concepts (a pencil ram, a spoon catapult, bottle-cap wheels, a sardine-tin shed): "I think we need to
accept them as human sized rats and not do stuff like that." New rat engines and gear are built at human
scale from the sewer's own junk (scrap timber, pipes, rope, rusted iron). The rats' existing tiny-object
gear (thimble and spoon helmets, bottle-cap shield and armour, sardine-tin armour) is left as it is until
Dominic decides on it. Cheese stays: it's the rats' food, not a joke about size.

**D-117, 2026-10-13: The forest ram is a giant beetle.** Dominic asked whether the beetle battering ram
would be better as a giant beetle; Claude agreed: the forest family's ram is a living siege beast, a
giant horned beetle that charges walls with its armoured head (crew riding or goading it), instead of a
beetle pushing a log.

**D-118, 2026-10-13: Siege engines show their crews.** Dominic: "I like crews very much, sad when games
don't show them." Every engine is drawn with the race's own workers working it (pushing, winding,
loading, aiming), placed so the machine's silhouette still reads at game scale. The catapult and bolt
thrower keep the round-1 A machines (arm and cup on wheels; a wheeled carriage), now crewed.

**D-119, 2026-10-13: Siege picks; the frogs' engines get a new direction.** Dominic picked from round 2: the
rats' open pipe-and-chain ram, the ridden giant beetle for the forest, and the rest as shown ("looks
amazing"): crewed timber engines for humans (ram B, catapult and bolt thrower A, crewed), the rats' junk
catapult and bolt thrower. The frogs' takes are the weak point ("overusing lily pads and stuff"): their
direction is rethought in a new concept round before any frog engine is built.

**D-120, 2026-10-13: Cavalry isn't infantry; prices can move without moving races; workers cost food.**
Large units lost to massed archers mainly because a mounted unit kept its rider's "infantry" tag, so the
archers' bonus against infantry hit cavalry too: mount bodies now carry `rider_loses: ["infantry"]`. A part
can have `price_points` (pricing uses them; the generator still spends `points`), so mounts and a few parts
were re-priced without changing any race key (168 checked). Workers (Dominic: "yes, do them"): food only,
at least 50 before the creature's cost (`rules.cost.roles`); the start is 300 food / 200 wood so openings
don't stall (Claude's call, Dominic may overrule). Superseding D-076's single price and refining D-078.
The equal-cost round robin can't reach ±20% for every unit with four slots (large units counter two,
archers one); that's a roster design question (a swordsman line?), not a price.

**D-121, 2026-10-13: The frogs' siege is swamp beasts; the newt may become frog cavalry.** Dominic picked
round 3's B ("swamp beasts, looks great"): the snapping turtle ram and the toad-borne bolt thrower. He's
not sure of the newt as the catapult carrier and wonders if it suits cavalry better: a concept round
tries the newt as the frogs' mount and other catapults for the frogs.

**D-122, 2026-10-13: The snail carries the frogs' catapult; frogs ride newts.** Dominic: "snail yes, the
newts look amazing". The frogs' siege is three beasts: the snapping turtle ram, the snail catapult, the toad
bolt thrower. Frog cavalry rides a giant newt instead of a beetle (the beetle stays the forest's); all three
colourings are kept as the newt's skins (fire as the usual one; the red eft not under red-skinned frogs).

**D-123, 2026-10-13: No generic Raider line; raiders are a castle unique-unit theme.** Dominic: "Raider isn't
really a thing, sounds race specific like a castle unit." The Barracks trains spears and swordsmen; fast
light raiders become one of the themes a race's Castle unique unit can take (chosen by data, like the others).

**D-124, 2026-10-13: Rats ride cats.** Dominic: "Cats are great, just hind looks a little too big." The reworked
alley cat (C2: a real cat body, four-beat walk, sits when idle; ginger, black-and-white and grey coats) becomes
the rats' mount, its hindquarters made smaller. The capybara stays in the game as a mount anyone can ask for.

**D-125, 2026-10-13: Soldiers cost about 1.7x; age-3 sword picks; the tiger dropped for now.** Dominic: "yes raise
soldier prices, your sword picks. Tiger we can drop for now." The cost base goes from 60 to 100 (an age-1 spearman
35 -> 55, about a worker and a bit, as in the genre); workers keep their 50-food floor and siege engines keep their
prices (rules.cost.roles pct 60). The age-3 swordsman kit (S3): hellenic B (long xiphos, Attic helmet), steppe B
(heavy sabre, spiked helmet), han B (dao), swamp B (river-stone mace), forest A (chitin blade), spooky B (hooked
sickle), plus a plain iron sword as the fallback; built once the placement checks are in (unit work is paused).
The tiger concept stays in the repo, unused.

**D-126, 2026-10-13: Bear heads picked; helmets by rank.** Dominic: "the snouts look perfect" (round B2) and left
the rest to Claude: the open-faced helmet (the bear's ears out) for line soldiers, the ear-cup helmet for the giants
and elites (a visible step up), and the polar bear's neck shortened a little so it reads as a bear, not a long-necked
animal. The mounted bear's neck still reads broken; it gets fixed (and a placement rule for it) before bears go in play.

**D-127, 2026-10-13: Picks from the milestone 13-14 concept rounds.** Dominic: the new (sculpted) horse head and the
bear mount (B3) stay. Trade carts: the race's own beast pulls a cart; for frogs a snail pulls it. Rats' scrap barrow
and handcart become what rat workers push when they carry stone and gold home. Heroes (HR1) are a good start but need
real character: a named champion with a personality that shows ("Ratty the Gnawer", "Ratty the 10000th of his name"),
not a dressed-up soldier. War beasts: not the capybara for rats (doesn't fit); a war boar, but bigger; spiders get a
tarantula on its own, not a spider riding a spider. The great sling (traction trebuchet) gets bigger and sturdier,
siege-weight, not thin. No carried charge for the sapper (its look stays plain).

**D-128, 2026-10-13: The sapper is parked.** Dominic: "remove the sapper unit, not needed." Its roster slot is set to
planned (the generator skips it), the Castle trains the unique unit and the great sling, the bot no longer keeps one;
the code, model and test stay, and the backlog says how to bring it back.

**D-129, 2026-10-13: War beasts, the great sling, carts and barrows picked.** Dominic: war beasts: the war boar for the
rats ("looks amazing"), the giant tarantula for the spiders (its back needs more texture: too single-colour), the heron
for the frogs, the praying mantis for the beetles, the elephant for humans. The siege-weight great sling (GS2) is
"much better"; the frogs' take is open (the turtle-mounted one is wrong, the plain one too boring: another round). The
rats' wheelbarrows and the hauled trade carts are "perfect". Heroes: liked (HR2); a pick to come.

**D-130, 2026-10-13: Walls go tall (W2 B), scaled down; the sci-fi mod is parked.** Dominic: the tall curtain looks
better ("thick is too thick"), but everything is a little too big: scale it down 10-20% so units don't look tiny
beside it and it still plays; the gates must be built into the walls properly (they read as confusing). The sci-fi
example mod is fun as a later, optional age by a setting, but parked: what he wanted to see was a wholly new
concept and race, not our units in the future, with real lasers only and no melee or bows. Milestone 21 keeps the
loader and tooling; the sci-fi content waits.

**D-131, 2026-10-14: The bullfrog leaper; Claude's calls on the rest.** Dominic: the frogs' great sling is FS1 A, the
bullfrog leaping onto the counterweight ("fun!"); "rest as you choose". Claude's calls: war beasts get a bonus against
mounted units (the genre's beasts break cavalry; spears and skirmishers stay their counters); centaurs stay not-large
(fast cavalry, one population place); the new skins stay (raspberry and teal frogs, the orange eft); tower hoardings
stay part of the base look. Heroes: all of HR2's characters are built, as a pool: each race gets one, picked from its
creature's and culture's characters by the race key.

**D-132, 2026-10-15: The pad's controls, settled (Claude).** Dominic asked for "a clean pass over the controls so we
can use it with a controller" before the Steam Deck build. Milestone 20's design gave some buttons two jobs; Claude
settled them: the triggers zoom (LT out, RT in); a held LB is the modifier (queue orders, add to the selection, train
five) while a tapped LB still cycles the selection's kinds; control groups 1 and 2 sit on the d-pad's sides (tap to
recall, hold to store), since the Deck's back buttons reach the game only if Steam Input maps them; View goes to the
last alert, Menu pauses. The wheel shows the command panel's own buttons rather than its own list, so anything the
panel gains is on the pad too, and in pad mode the panel keeps only who's selected and the queue. The last input used
decides the mode, so the trackpad (a mouse) and the sticks mix freely. The table is in docs/milestones/m20-steam-deck.md.

**D-133, 2026-10-15: The pad's wheel opens with A (supersedes D-132's hold-RB wheel).** Dominic, after the first go on
the Steam Deck: holding RB while picking with a stick was uncomfortable, and the stick that picked also moved the
camera; "just copy" the classic console RTS: open the menu with A, no camera move. The hold-A circle stays (it "worked
really well"), so the wheel opens with a tap of A on your own building (it selects it and opens its wheel at once) or
on a unit you already have selected (Claude). On the wheel the camera holds still, A chooses and the wheel stays up
for more, B closes, LB turns pages; it closes itself once there's something to aim (a building, an armed order) or
after an order or stance. RB is only "your soldiers" now; the global wheel is gone, the tech tree moved into the pause
menu. Also from that run: every asset the game reads raw (SVG, WAV, GLB, TTF) is imported as "keep", so exports carry it.

**D-134, 2026-10-15: A first tap on a building only selects it.** Dominic: "tap is a little confusing, because I tap a
building to see build progress, and it opens the build panel too." Buildings now work like units (refines D-133): a tap
selects, a tap on what's already selected opens its wheel.

**D-135, 2026-10-16: No double tap on the pad's A.** Dominic: tapping a unit for its build menu kept selecting all of
that kind; "double tap is very sensitive". Tap, then tap again, is how a selection's wheel opens (D-134), so the double
tap could never be told apart from it. "All of these on screen" is now the first button on a unit's wheel. Also: the
mouse takes over from the pad only after a real swipe (80 px within 0.4 s) or a click, and the menus keep their focus
when it does (on the Deck the stick's focus kept jumping back to the top button).

**D-136, 2026-10-16: War beasts are creatures, not carts (Claude).** Dominic saw the war elephant slide with no leg
movement. Each beast was one rigid sprite moved like a siege engine (a rock, a whole-body lunge, a cart's tip-over). Now
its legs bake per hip and its head at its neck, cut by its body, as on the mounts, and UnitView walks it like any creature
with its riders on its back. Its blow and fall are data (parts.json `beast`): the elephant rears and stamps its tusks
through, the boar lowers its head and gores, the tarantula rears and bites, the heron draws its neck back and stabs, the
mantis snaps its arms out. It falls like a creature: the elephant and boar go over on their side, the tarantula curls,
the heron topples, the mantis folds flat, and its riders are thrown clear. The concept rounds' models stay whole. The
placement check now also walks each beast on its own (feet, legs, stance in every step); the notch rule reads a howdah
as a shoulder, so the elephant and boar get 2.5 and the mantis (no neck) 9 in their stance data.

**D-137, 2026-10-16: War beasts' legs bend (Dominic).** After the first walking beasts (D-136, stiff legs swung from
the hip), Dominic: "bent knees are required for sure". Each beast's leg is now jointed and baked in 8 walk steps
(parts.json `legs.poses`, as the cat's): the foot goes back along the ground while it bears weight, then lifts and
swings forward, and the knee follows by two-bone IK (siege_models.gd `beast_step`, `ik3`). The elephant's knee and
wrist bend forward, the boar's fore knee forward and hind hock back, the heron's knee forward and heel back with the
foot folding as it lifts, and the tarantula's and mantis's high knees rise. The stiff swing is off (`gait.swing` 0).
**D-138, 2026-10-16: Every race gets all of its heroes (supersedes D-131's one hero per race).** Dominic, resuming the
paused heroes: "heroes i thought we'd do all of them, so each race has some variety." A race now gets every hero its
creature and its culture name; one with fewer than three (in the base game: humans, whose heroes come only from their
culture, spooky spiders and forest beetles) is topped up from its culture's two kindred cultures (`kin` in
data/heroes.json), so every race has three or four. Claude's calls on how they play: each hero is trained once at the
Town Center from age 2 and only one of each is ever out, but a race's heroes may all be out together; a fallen one is
revived there for 60% of its price after a minute; auras don't add up (the strongest of each stat). Balance: flat
stats (+120 hp) made a rat's hero five times its swordsman and a centaur's twice, so the hero line is a share of its
swordsman (three times the hit points, a third more attack, no armour bonus) for 30 price points, healing a point
every three seconds. Art: every hero look must pass placement on every body it can come to, so bodies may declare a
`drape` socket and scale for hanging capes, and a hero may wear a low-slung variant of its hat, or keep its race's own
weapon, on a creature it doesn't fit (`fit` in data/heroes.json).

**D-139, 2026-10-16: Hold RB for the wheel too (refines D-133).** Dominic, from the Deck: "when a unit is walking its
hard to click on them to open it using A", so both ways open a selection's wheel: tap A on it (D-133/D-134), or hold RB
for 0.3 s wherever the reticle is. Claude's call on the details: the wheel stays up once RB is let go, so nothing is
steered while holding a shoulder button (D-133's complaint), and a quick RB stays "your soldiers" (it now acts on
release). A worker's wheel also always opens at the top of its build pages.

**D-140, 2026-10-16: Saving a match: a snapshot, with the replay to fall back on (Claude; Dominic asked for save/load).**
Nothing had been decided about saving (the MVP plan cut it: "replays cover it"). Two ways were weighed: a save as a
replay up to now, loaded by playing the match forward headless (small and exact, but the sim step costs 2 to 6 ms a
tick late in a bot match, so a 20-minute match would take about 100 s to load on the Mac), or the World's state
written out. A probe of the World's and the bots' object graph found only ints, packed arrays, data dicts and a few
Vector2i, no callables, Nodes or shared objects, so a save is a generic snapshot (every script variable, sub-objects
and all) plus the replay. Loading builds the match as at its start, pours the snapshot over it and checks the state
hash (about 0.1 s); if it doesn't fit the build, the replay plays forward instead, and a build whose sim plays
differently goes on from where its re-run got to and says so. Bots' own commands aren't stored. A new file per save
(`user://saves`), none overwritten or deleted, until Dominic picks slots, autosave and what happens to old saves
after an update (docs/milestones/save-load.md).

**D-141, 2026-10-16: Saves survive game updates without replaying (refines D-140).** Dominic: "we just keep them all
for now. After game updates needs real though, replaying is bad." So loading never replays: a save loads from its
snapshot whatever build made it. The races, rules and data tables (unit types, buildings, tech, the bots' config) keep
the save's values, so an old match goes on under the rules it was started with, and gain any key a later build added
(lists of dicts pair up by id or slot). A variable a later build added keeps its constructor's value; units and
buildings pad their per-unit arrays to their count, and a class whose new variable needs better calls `after_load
(missing)`; a variable a build dropped is ignored. A save needs only its map's file. The replay stays in the save for
watching back. Every save is kept (Claude's call on the details: no slots, no autosave yet).

**D-142, 2026-10-16: A loaded save plays on with this build's stats (refines D-141).** Dominic: "if we're not
replaying, then seems we could migrate a save if not totally too old, because updated stats aren't something the save
should worry about." So a save keeps the state (where everything is, what's built, stock, ages, research done) and
takes the stats from the build loading it: the races as it generates them, its rules (the save's host choices, such as
the mode, kept), its data tables, then every player's unit types and building stats worked out again from the
research the save has, units and buildings keeping their share of health. Claude's call on "too old": units,
buildings and research point into those tables by place, so this needs them to line up with the save's (the same
rosters, buildings, research, resources and armour classes, in the same order); when they don't (a building or
research added or removed, a race prompt that generates differently), the save loads frozen on its own stats as in
D-141. Remapping by id so those migrate too is a possible next step.

**D-143, 2026-10-16: The bake keeps the screen moving (Deck: the UI froze while the army baked).** Claude, from
Dominic's Deck report. A bake's main-thread work is budgeted per frame (`BakeClock.BUDGET_MS`, 8 ms while the window
draws smoothly; 500 ms while hidden, as before): model builds, tree adds and removes and atlas work wait for a frame
with budget left (`breathe`), the forced draws stop at one building frame's worth of pixels a frame (`DRAW_PIXELS`), and
renders are read back asynchronously (`BakeClock.read`, the GPU copies them out while frames go on). Only work on
Images and arrays runs on worker threads (`off_thread`: pixelize, shadows, cuts, cache writes, atlas packing). Model
building on a worker thread was tried and dropped: now and then it and the game's frame waited on each other and the
game hung. A body a part is cut by is built once per baker and copied after (a war beast's body was built 32 times).
A slow frame only counts as "hidden" after three in a row that kept to the small budget (one GPU hiccup, or a frame
slowed by the bake's own work, flipped it before and made the next frame half a second long). Portraits are posed once
at their seeded time (they posed a frame or two on, so a portrait changed with how long those frames took).

**D-144, 2026-10-16: A unit's cost mix comes from what its gear is made of.** Dominic: "different unit lines have
resource differences. I think spears cost some wood and less food, swords only food or food and gold", as the
genre does. Every soldier cost about half food, half wood (28 weapons shared one 40/60 mix; bodies and armour fell
back to 50/50). Now each part's `cost_mix` (data/parts.json) follows its material, and a unit's mix is its parts'
weighted by points, as before (Claude's table): a creature's body and mount eat (food); a wooden shaft, bow, club or
shield is wood; a metal blade, helmet or armour is gold (a metal spearhead or lance mostly wood, so the spear line
stays the cheap counter); cloth, leather and leaves are food. Totals don't change, only the split. No age-1 gear
carries gold (bots mine none before age 2; the rats' thimble and bottle-cap shield are scrap, not metal). The bots'
gold share in ages 2 and 3 goes from 15 to 25 percent (data/ai.json). A spear is now 40-50F 25-45W in age 1; an
age-2 swordsman 60F 25W 80G; an archer wood and gold with a little food for the body.

**D-145, 2026-10-16: Unit portraits are busts with a role glyph; a line upgrade shows what it gives.** Dominic,
from two concept rounds (pictures 22, 23) and how the genre's games do it. A unit's portrait frames its head,
chest and the weapon in hand (`ArtKit.bust_icon`; engines and carts keep the whole-body frame) with a drawn role
glyph in the corner (`assets/art/icons/glyph/role_*.svg`: spear, sword, bow, sling, horse, staff, by the weapon's
tags; a rider with a lance or blade the horse; workers none). A line upgrade's button shows the portrait of the step
it gives, in a gold frame, named "Upgrade: X -> Y", its tooltip saying every X you have and all you train becomes
a Y (it showed the line as it was: the same picture as the Train button beside it). Train buttons, the queue, the
unit card and the selection tray show a line's current step (they showed its first step, upgraded or not).

**D-146, 2026-10-17: Milestones 5, 13, 14, 16, 19 and 21 close; the sapper leaves the tech tree.** Dominic: "anything
requiring my checks can close, anything else we move forward." What waited only on his look or pick closed with its
milestone (the placeholders in play stay: the wall tower, rubble, siege tower and ladder, trade cart, the unique
units' themes); the work left moved to `docs/backlog.md` §0b (bugs riding newts, the structural balance outliers, the
unique units' new parts, race mechanics, race balance, bears, the end screen's story, the rest of modding). The art
pass is superseded and the art and UI track closed. Milestone 20 (the Deck) stays open; 22 (battle feel) is planned;
18 not started. Dominic: "Sapper we killed. Should be gone from tech tree": a roster slot can be `"status": "parked"`,
out of the game (the generator skips it) and off the tech tree page; the sapper is parked (D-128's code stays).

**D-147, 2026-10-17: Multiplayer starts as lockstep over ENet on the home network; HyperDHT next.** Dominic asked for
the fastest way to multiplayer with no server of ours and no NAT trouble; Claude compared Godot's ENet (built in, no
NAT traversal), WebRTC (needs a signalling server and TURN), Steam networking (relays, but a Steam app id), and a
HyperDHT sidecar over Bare (no server, holepunching, the host's key as the join code). Dominic: "we can solve that
next using enet like you said and we do local tests". So phase 1 is lockstep over ENet, 1v1 on the LAN, to prove two
machines (macOS and Linux) stay in step; phase 2 is the HyperDHT sidecar behind the same transport interface. The sim
already ran on stamped commands two turns ahead, so only commands travel: at each turn's end a machine sends its
commands with a done mark and its state hashes, and a turn starts only once every player's turn two before it is in.
A match is its setup (the host's race, the joiner's own race, map, mode, teams); games are found by a LAN beacon (no
address to type on the Deck; a subnet broadcast, since macOS won't send to 255.255.255.255). A network match has no
pause, saving, speed change or testing keys; a desync or a player leaving ends it with a note.

**D-148, 2026-10-17: A saved match can be played on the network, a person taking over an AI.** Dominic: "load
saved game and human can replace an AI. I have a 2v2 saved we should test it with." The host picks a save and the
AI seat to open; the save travels in the setup, both machines load it, the people's seats lose their bots and the
other AIs play on both machines alike (bots are deterministic and the save holds their state). The lockstep starts
from the save's turn and carries only commands issued after it (the save's queued ones are on both machines). Found
on the way: the join page read the host's first turns in the same batch as the setup and dropped them (now handed
back to the match), and the lockstep trusted the latest turn mark over a gap (now a missing turn stops the match);
a bot loaded from a save mid route search (land.gd) called the search it no longer had (now it starts it again).
Tested with Dominic's 2v2 save (26 minutes in): the joiner took the ally, 600 ticks in step.

**D-149, 2026-10-17: A prompt can name its hero (refines D-138).** Dominic: "shouldnt we randomly get only one option
based on race description? so its possible to deterministically always get the same hero if you want". Heroes were
already the same every time (derived from the race key), so the ask was really about choosing one. Claude proposed, and
Dominic took, a middle way: a prompt that names a hero ("spooky spider widow", "sewer rats with a crown") gets only that
hero; a prompt that names none keeps all of its heroes (D-138's variety). The words are data (data/lexicon.json entries
with a `hero`: one or two per signature, its look or its epithet). Naming several of the race's own gives those; a hero
that isn't the race's own ("roman widow") is ignored with a note, since every hero's look is only checked on the bodies
it can come to. The heroes asked for are kept on the race (`hero_asked`) and hashed into the key only when there are
some, so every existing race keeps its key.

**D-150, 2026-10-17: Each unit line has one cost mix; the parts set only the total.** Supersedes D-144's split.
Dominic, on the swordsmen still paying 40-60 wood (for their shield and banner): "We're using the parts too
literally... Different lines don't have clear cost benefits... I'm concerned we're making it too confusing with such
variable costing - especially if each individual part is adding different resource requirements". He wants it "super
balanced" and simple to read: fine if centaurs get fewer, stronger units. So a unit's total still comes from its
parts' points (cost stays the balancer, and a stronger race still pays more), but what it's paid in is its line's,
the same for every race (`rules.cost.roles` mix, Claude's table, Dominic agreed): spear 35 food 65 wood, skirmisher
40/60 food/wood, scout food, swordsman 60 food 40 gold, archer 55 wood 45 gold, heavy 55 food 45 gold, mounted
archer 45 wood 55 gold, war beast 60 food 40 gold, healer gold, unique 40 food 60 gold, siege engines 60 wood 40
gold, the great sling 40 food 60 gold; heroes, traders and workers as they were. The cheap counters (spear,
skirmisher, scout) never cost gold. In age 1 a gold share is food (`rules.cost.early`; `Pricing.evaluate` takes the
age). Prices round to tens, not fives. Totals move only by that rounding, so equal-cost fights are as before.
Claude's second idea, a cap on how far a line's total strays by race, was dropped: it would make a stronger race
cheap. Parked: a race perk that drops a line's gold cost (Dominic: one race maybe, "carefully balanced"; backlog §8).
**D-151, 2026-10-17: Vikings get a Norse culture of their own.** Dominic asked whether Vikings ever got a shield wall
(they hadn't: "viking" only added horned helmets and round shields to whatever culture a race drew, and the only
Shield Wall is the imperial research) and wanted them to have their own culture. Claude built it as data: a `norse`
family (sea-blue and madder-red cloth, ponies, the thatch architecture, boardwalk paths, an iron-framed wood UI with
a longship crest), its three bonuses (Plunder: every kill brings in 3 gold, alt Raiders, foot soldiers +3 against buildings; Linden shields:
shield-bearers +1 pierce armour; Seafarers: no slowdown in shallows or fords, for allies too), its own research
Berserkergang (infantry +2 attack), no archers' age-3 step, the Berserker as its unique unit (fur cap, bearded axe;
quick and hard-hitting, no armour) and the Raven-Feeder as its hero (a raven-winged helm, a raven on the shoulder;
shield-brothers: friends +1 melee armour). "viking", "vikings", "norse", "norseman/men", "northman/men", "nordic"
and "berserker" name the culture; "horned" now asks for horns (so "horned vikings" get the Horned Raider, the old
viking unique) and "raider" for light kit. New gear, favoured by the Norse and signature (only when asked) for
everyone else: a bearded axe (age 2, wood and gold by its haft and head, D-144), a long broad axe (the swordsman's age
3), a fur cap, a conical iron cap with a nasal, a spectacle helmet, a rune healer's staff. Helmets follow round 1's
Viking suggestion, which Dominic never picked, minus the braids and beards: they hung into a frog's, rat's or
beetle's chest, and the concepts had shown they vanish at game scale. Not in scope: the tight shield wall formation
(milestone 22, step 4). Found on the way: no culture's shield was ever checked on a spider or a rearing beetle, and it
cuts them (fixed by D-152). Balance: Raiders first (priced into every foot soldier) left the Vikings 0 of 12 in
race_matches; with Plunder first, 1 win, 7 draws (8%, level with imperial humans, inside the 8-41% range).

**D-152, 2026-10-17: Frogs, rearing beetles and spiders carry their shields slung on their backs.** Dominic, on the
shields found clipping with the Norse culture: "Fix the shields etc for spiders and bugs. Or just put them on their
backs instead." Every shield and back piece was put on every body (`gear_cases` in tests/placement/cases.gd): every
shield cut a spider's head and a rearing beetle's armour, most went into the ground at a frog's low off hand, and the
cloth cape cut frogs' and beetles' haunches. Claude went with the backs: a body's `"shield"` in parts.json says how
it carries one, `slung` (upright behind the shoulders: frogs) or `slung_flat` (flat on top: the spider's abdomen, the
beetle's wing cases), and its model gives a `sling` socket; the shield bakes as `<shield>@slung`, the hand's model
turned to lie there (unit_models.gd `slung`), and the placement check holds it to the back-gear rule. Humans, rats
and centaurs keep their shields in hand. The cloth cape isn't worn by frogs and rearing beetles (`not_worn_by`, like
`not_ridden_on`); the leaf cape fits them. (The Norse decision, first written as D-149, was renumbered D-151 at merge:
main's D-149 names heroes.)

**D-153, 2026-10-17: Workers are checked at work; a 2D pose on the bakes takes its directions from the facing.**
Dominic saw a foraging centaur from behind in a network match, drawn broken ("i thought our tooling and tests
protected against this needing visual checks"). The kneel to forage (D-105's C1) was a 2D pose written side-on: it
picked the front legs and the pivot by screen x and bent as if the body faced right, so it was right only in facing 0;
the placement check never drew a unit at work. Claude: every worker is now drawn foraging in all 8 facings by the 2D
check (`tests/placement/work_2d.gd`, rules K1-K5 for a fused mount's kneel, measured against the model and the bake
camera), and any pose UnitView puts on the bakes takes fore, hind and forward from the model and the facing
(`UnitView.ahead_on_screen`, `side_on`), never from where things happen to be on screen. Facing 0's kneel is unchanged.

**D-154, 2026-10-17: Rivers get a deep middle nobody crosses; flyers no longer cross trees.** Dominic, after a 2v2 on
Reed Meadow: frog races swam the river anywhere, and enemies walked round behind the wood lines, both "very one sided
too early on". His idea: shallow, deep, shallow. A new terrain, `deep_river`, that no movement class crosses (not
amphibians, not flyers; Dominic said yes to flyers too), runs down the middle of both Reed Meadows' rivers, now wider
(the 2v2's 7 tiles across, 3 of them deep; the 1v1's 5, about 2 deep). Fords cut through all of it and bridges stretch
to the banks, so the crossings are the only way over for everyone; the map edge where the river runs off is deep too,
so no flyer goes round its ends over the edge rock. The swimmable bands keep `river` (amphibians and flyers) and draw a
little lighter than the deep middle. The wood lines behind each base now reach the map edge (they stood a tile in, a
lane behind them): one tile deeper, the inner edge where it was (moving it outward instead cost the 1v1's age-3 bot
its University and Castle in test_ai), so each start has more home wood (1v1 19,100 from 14,900; 2v2 13,000-14,000
from 11,100-12,100). Trees block flyers too (Dominic: flying over the woods "feels again too imbalanced"); soaring over
trees is to be something special, a winged race's castle unit with extra big wings, concept-first (a later piece).
Other maps' rivers stay all `river` for now. Stone, gold and food per start unchanged (one stone tile on the 1v1
moved a step back from the wider river). Then, "while we're there": walls run straight over high ground (Dominic: "I'd rather I can
build a wall straight over them with no issue"). Wall and palisade pieces may now stand on cliffs and ramps (each piece
is one cell, so it sits at its own level and the line steps up the hill); gates still may not stand on a cliff (an
own gate is open to its side, and a gate on a cliff would be a way up it), and a gate's cell on a cliff never opens
in the walk grids either. And the hills' edges are bevelled in the view: a raised cell's outer corner drops to the
ground below, so diagonal edges read as slopes, not a staircase of tiles (`Iso.corner_heights`; the sim's levels and
cliffs are unchanged).

**D-155, 2026-10-17: Battle feel starts (milestone 22): formation by role, counter-aware targeting, attack lines, a
Norse shield wall.** Dominic approved the plan with three choices. A group's formation goes by role: foot soldiers in
front, shooters behind, engines, healers and carts at the back, and every mounted unit on the flanks, horse archers
too (his pick: fast units on the outside); with no foot beside them, riders form the centre. Units pick a foe they
counter (their attack has a bonus against one of its classes) as if it stood `counter_pull` nearer, 2 tiles (his
pick, "medium": the rider beside the footman, not one across the field); the spreading into duels (D-054) stays.
Selected units show a thin team-coloured line to the foe they're fighting. The Norse shield wall is look only and
always on (his pick): Norse foot with shields march shoulder to shoulder (`form_gap` -160, a sim effect on the
Linden shields bonus, both its forms, since a culture has exactly three bonuses), no stat beyond the bonus's own.
Balance: mass_battle in ages 2 and 3 and balance.gd unchanged in every single-type fight, mixed fights a win or two
either way. (Claude)

**D-156, 2026-10-17: The battle setup is the network lobby, with seats.** Dominic, after the first Mac vs Deck join:
"Hosting a new game, dont seem to get the option for other player to join the lobby and customise there side", then
"shared lobby means we should be able to make 2v2 games, and players can choose what side theyre on". Host a game
now opens the battle setup listening (src/view/net_lobby.gd); every side but the host's starts as an AI, and up to
three players join, each into the first open side, free to Take any other AI's side (so they pick their team). Each
player edits their own race; the host the map, the mode and the AI sides. The host holds the lobby and sends the
whole of it to everyone when it changes; any change un-readies everyone; Start is Ready, and when every player is
ready (two at least) the host sends go and every machine starts loading at once. The AI sides play on every machine
alike (bots are deterministic, as in D-148's saved matches); the host relays each player's turns to the others (a
star over ENet). The join page lost its race box: the race is picked in the lobby. Claude's calls: the host owns
the AI sides; the host's map arrows skip maps with too few sides for everyone in. Found on the way: the host's setup
message only left when its match first polled the link (after its load), so the joiner timed out ("host isn't
answering") or loaded only after the host; sends now flush, the link is serviced while loading and ENet waits
15-60 s. Saved games on the network keep D-148's page.

**D-157, 2026-10-17: A network match can be saved (refines D-147).** Dominic: "i cant save muliplayer?!" D-147 left
Save out of a network match. Every machine runs the same world, so any player can save it on their own machine; the
other people's sides go into the save as Normal AIs (fresh bots from that moment). Loaded alone, the AIs play them
on; hosted again on the network (D-148), a person takes one over. The match isn't paused while the menu is open.

**D-158, 2026-10-17: Stone walls stop flyers; flyers draw over the buildings they cross.** Dominic: "flying units
also can go over pallisades. Probably fair - just annoying early game. But big walls they shouldnt be able to go
over. That said, is it just too unbalanced either way?" Claude's view: flying over everything made walls worthless
against a winged race for 4 points of wings; flying over nothing (after D-154's trees and deep river) would leave
wings little more than speed for hit points. The middle gives flight an arc: a nuisance early (no walling it out with
stakes), answered by stone walls and towers from age 2, and leaves the soaring castle unit (backlog) the one thing
that crosses everything. Dominic: "yeh block with stone walls". A building type's `blocks_flyers` (buildings.json:
the stone wall, stone gate, wall tower) closes its cells to flyers too (SimMap.high; a side's own stone gate still
opens for its flyers); palisades, houses and the rest they fly over. A save from before marks its standing walls on
load (World.after_load). And, Dominic: flying over buildings "is weird though because they just ghost through
them": a flyer over a building is sorted after the building's front corner and climbs 12 px, so it's drawn over the
roof, not through the walls (sim_debug `_over_roof`; farms and pens lie flat, nothing to climb). The Castle doesn't
block flyers (not asked; easy to add with the flag).

**D-159, 2026-10-18: One hero a race (supersedes D-138's all of them; keeps D-149's named hero).** Dominic, after
seeing three heroes to buy at the Town Center: "no there should never be 3 heroes to buy". A race's pool stays as
D-138 built it (its creature's and culture's heroes, topped up from kindred cultures), but the race gets one of
them: the first one its prompt names (D-149), else one picked from the pool by its race key, so a reroll may bring
another. Claude's calls: naming two of the race's heroes brings the first named, with a note that the other "stayed
home"; a named hero who isn't in the pool still gets a note and the key's pick. The sim keeps supporting several
heroes a player (training, revival, auras that don't add up), since allies' heroes still meet. Old saves whose race
had three heroes no longer line up with today's tables and load on their own frozen races (D-141).

**D-160, 2026-10-18: Colour words pick the skin.** Dominic: "red spiders" didn't work, spiders had few colours and
a colour in the name was ignored. Colour words are lexicon entries (`"colour"`), each skin lists the colours it
answers to (palettes.json `skin_colours`), and a race's skin is picked from the ones in a colour it asked for (any of
them, if it asked for several), then narrowed by its culture as before. A creature that doesn't come in the colour
keeps its own skins and the race gets a note. Spiders gain red, white, yellow and blue skins, kept clear of the team
colours. Claude's call: human skin tones answer to no colour word, so a colour never picks a person's skin. Adding
skins changes which skin some existing spider prompts roll (the key changes with it; saves keep their races).
**D-161, 2026-10-17: Bears are in play.** Dominic: "lets get the bears going on a branch". He had picked the heads
(B2, D-126) and kept the B3 mount (D-127) and left the rest to Claude, so Claude took the B1-B2 recommendations
and brought them into the game's data, with no new concept round: the kits go into data/creature_kit.json, the parts into
data/parts.json (DataLib completes kit bodies on load), the creatures, skins and words into their files, and the
helmets into scenes/art_pixel/bear_models.gd. There are three playable bears: brown ("bears", "grizzly"), black
("moonbears", "blackbears") and polar ("polar bears"), all folk, with hellenic or forest culture by roll.
- Bears walk: no pony, cat, newt, beetle, spider, hummingbird or other bear carries them (`not_ridden_by`), so
  their large line is a giant bear and they have no mounted archers.
- Others ride bears: a word that names both a race and a mount ("bears") is the mount when a word that rides comes
  first ("romans riding bears", "rats riding bears"), and the race otherwise (race_generator.gd interpret).
- Placeholder identity: thick fur (+4 HP, priced), honey hunters (food +10%); own research Winter Coat (Castle,
  soldiers +1/+1 armour); they lack Quick Draw; they pour boiling honey. They get a bear voice of their own
  (tools/audio voices.py `bear`: a huff, a low "hrrm", a falling roar), which Dominic hasn't heard yet.
- The polar bear as the brown bears' giant and a culture and architecture of their own wait in the backlog.
(Written as D-160 to D-162 on the `bears` branch; renumbered at the merge into main, 2026-10-18: main had taken D-159 and D-160.)

**D-162, 2026-10-17: How a broad body takes the game's gear.** Putting every helmet, armour and held piece on the
bears (D-163) showed what a body twice as wide as a human needs. Each fix is data, so the same tools work for the
next broad creature:
- Head gear: the bear head's `top` socket now sits on the skull, because a cap or a leaf hat has to touch the head.
  The bears' own helmets are lifted by the same drop, so they sit where Dominic saw them.
- A body can give a back piece a place of its own, a socket named for the part (`"cape.cloth"`, `"hero.lion_pelt"`).
  Without it the cloth cape cut through the bear's back. A bear's `banner` socket is higher too, so tall helmets
  clear the crossbar.
- Stock helmets whose rim covers a bear's eyes stay off bears (`not_worn_by`): the Attic on every bear, the bronze
  on the black and polar ones. Bears have their own helmets. The cloth cape isn't worn by bear riders
  (`not_ridden_on`), and the jaguar hero wears its low helm on bears (heroes.json `fit`).
- `"crew": "wide"`: a bear is too big for a ram's frame or a war beast's back, so it works them from beside, on the
  `_wide` sockets, as a centaur does.
- `ridden_idle_poses`: a ridden bear only settles back a little. Sitting all the way up, its raised head ran into
  the rider's lance and a frog's head.
- A body that rests in idle poses while holding its weapon its own way is baked in both at once,
  `"body.bear@draw@ease"`: a bear archer at ease keeps its bow drawn while only its feet move. The 2D check found
  the bake missing, and the game would have drawn a magenta marker.
- The siege tower gets a `_wide` place for the crew member at its back corner, where a black bear's shoulders showed
  past the tower.

**D-163, 2026-10-17: A new body is checked against every piece it can come to.** Any culture can come to a bear
("aztec bears"), so `bear_cases` (tests/placement/cases.gd) puts every helmet, hat, body armour and held piece of
the game on each bear body. Hero, siege, concept and carried-load parts are left out. Each piece goes on the unit of
the race that would wear or hold it, together with the bear races in PROMPTS, every rider on the bear mounts, and
the Norse, hero and gear sweeps that already ran over every playable body. The first run had 191 failing checks
(102 before the sweep) in 3D, and 205 in 2D; after D-162, none. Carried loads aren't in the 3D check for any creature (UnitView's carry
hold isn't posed by the rig); that's in the backlog.

**D-164, 2026-10-19: The game's icon is N4, the parts kit, ink on gold.** Dominic picked N4 from the fresh icon round
(`docs/concepts/icon/fresh/`): a model kit's frame with its parts still on it (a frog's head, a horned helm, a round
shield, a sword), the game in one picture: an army built from a kit of parts. Drawn navy and bone; Dominic asked
whether it should match the website's colours, Claude showed it in lacquer red, gold on dark and ink on gold, and he
chose ink on gold (the site's gold accent, the brightest tile in a dark Discord or library list). Files in
`docs/concepts/icon/chosen/`: `icon.svg`, `discord_server_icon_1024.png`, a favicon set; it is the website's favicon.
Not in the game yet (`project.godot` `config/icon`, the export icons): a later step. At 16 px it reads as a framed grid
on gold rather than its parts; a hand-drawn 16 px version can come later if that matters. Round I1's race marks stay
as Discord stickers and emoji (`docs/concepts/icon/stickers/`).

**D-165, 2026-10-20: The frogs die laid down in 3D, face down in a sprawl; supersedes D-106's hopper fall.** D-106
gave a hopper one last hop that turned its whole sprite over, meant as landing on its back; on a flat pixel sprite
it read as a frog drawn upside down (Dominic, from a battle screenshot: they "look upside down"). Round HF1 turned
and squashed the sprite other ways (onto its side, a belly flop, a kick); Dominic: "those are all terrible. Just
rotating or squishing the image". Round HF2 posed the dead frog in 3D and baked it: belly up, on its side, face-down
sprawl. He picked the sprawl ("probably the most realistic, but shadow makes it look like it's floating"), so HF2b
gave it its own baked shadow and laid it on its belly for real (limp arms, a slumped body: it had been propped on
one hand). Now a body with a `corpse` pose in parts.json (only `body.frog`) bakes a few frames of its fall per
recipe (`src/view/art/corpse.gd`, `art_kit._corpse_job`), and UnitView plays them after a short last hop
(`_corpse_fall`). The 3D unit assembly moved from the tests into the game for it (`src/view/art/rig3d.gd`,
`geom.gd`). New placement rules D1 (a corpse lies on the ground) and D2 (dropped gear on the ground, clear of the
body), with a fixture for the frog propped up on its hand. Cost: ~0.6 s of renders per frog recipe on a cold load
(six workers at once, then the bake cache).

**D-166, 2026-10-20: A corpse may lie turned differently in each facing, so every view reads.** Dominic, on the frog's
sprawl looking like legs stood on from behind: "slightly different views from different sides so it always looks good is
fine". The dead aren't tied to the facing they fell in: `corpse.turn` (8 degrees, parts.json) turns the laid-down body
on its spot per facing before it bakes, its shadow with it. The frog's is [0, -45, -30, 0, 0, 30, -30, 0], picked from
round HF3 (`tests/sheets/frog_fall_hf3.json`: the sprawl turned -60 to +60 in every facing); no facing now sees it end
on from behind.

**D-171, 2026-10-26: Destruction goes the way of study AQ1's direction 2: buildings break up in baked stages.** Dominic on
the art-quality study (`docs/concepts/art-quality/`): "Destruction looks great". The pick: a building broken up in 3D
before it bakes (pieces fall from the top, others tilt and scorch, rubble heaps from its own materials, walls become
ragged stumps with breaches), five stages from whole to ruin, the fall with pixel dust, and a ruin that stays; it would
replace the drawn cracks, keeping today's fire and smoke. Not built yet: Claude asks Dominic to go ahead, with the
ruin's sim questions (does it block, can it be built on, how long it stays). (Numbered D-171: the Lobster port's
branch uses D-167 to D-170.) In the same note Dominic set unit and building fidelity as a key goal ("units being more
detailed and higher quality"): direction 1's "not a global 2x" no longer stands as the recommendation; a fidelity round
comes next.

**D-172, 2026-10-26: Go-ahead on destruction (D-171); a ruin is decoration only, can be built over, and fades.** Dominic,
asked whether a ruin blocks, can be built on, and how long it stays: "Destroyed buildings should probably able to be
built over? Same as [a classic RTS]. Destruction is for looking cool not game mechanic. Destruction staying until built
over is cool but can get frustrating and ugly. I think wrong game for that". So destruction is view-side only: the sim
frees the footprint when a building falls, as today; the ruin is drawn there with no effect on movement, placement or
sight; building over it clears it; otherwise it fades away after a while. Supersedes the "ruin that stays" in study
AQ1's direction 2.

**D-173, 2026-10-26: Unit fidelity goes heroic: humans 5.5 heads tall, everything baked at 2x.** Dominic picked from
round F1 (`docs/concepts/fidelity/`): "go with heroic 5.5 heads at 2x". Supersedes the toy proportions (~3.4 heads)
of today's human and the 1.5 art pixels per canvas unit of D-042's bake: the art scale becomes 3.0 (a tile 192 art
pixels across, one art pixel a screen pixel at play zoom), units and buildings alike; the painted value bands and
the dark outline stay (they are what keeps it a classic RTS). The human body is rebuilt at the genre's heroic
build (about 5.5 heads, broad shoulders), its gear refitted; rats, frogs and the other creatures follow in their own
concept rounds. Team colour moves toward a smaller region over natural colours as the pieces are remade. Milestone 23
(`docs/milestones/m23-fidelity.md`).

**D-174, 2026-10-27: Banners only when a prompt asks for them.** Dominic: "remove the banners, unsure why we have them
on so many units". `banner.team` (+1 attack, a back part any unit with a free back took) is `only_if: ["banner"]` now:
a race gets it when its prompt says banner(s) or flag(s) (lexicon). Two unique units keep one by design (the Big Cheese,
the Aztec obsidian guard: data/uniques.json). Races generated from the same prompt change (their keys too).

**D-175, 2026-10-27: The human tunic is wool in the culture's colour; the team colour moves to a sash, the hem, shields and
crests.** Claude's call (milestone 23 step 2b, after Dominic: the clothes "feel cheap still", and his liking for the
F1 figure: a red tunic, the team on the shield and crest); open to Dominic. The culture's cloth colour is mixed into
undyed wool (45%) so the team colour stays the brightest thing on a unit: in a battle the Roman red tunic read as the
red team's. Supersedes D-055's team-coloured tunic for humans.

**D-176, 2026-10-27: War elephants carry their riders in a walled howdah, from the hips up.** Dominic, on two heroic
humans standing on an open platform: "the elephant with units standing makes no sense now". Crew on a howdah's "_box"
sockets aren't drawn below the hips (their legs hidden; the 3D check leaves them out too), set down so the tunic's hem
meets the walls' top (12 over the floor).

**D-177, 2026-10-27: The rats are rebuilt as rats (round F2's B).** Dominic: "rat b looks great". The rat becomes a rat as
a rat is: hunched forward on its hind legs, a long body, short arms, the head carried low, a real rat's snout, ears and
tail (`tools/blender/concept_creatures.py` rat B is the concept), at the heroic humans' quality (milestone 23). The frogs'
take (A or B) is still open. Not built yet. (On the Lobster branch rats and frogs are drawn a fifth smaller on foot,
creatures.json draw_scale 80, Dominic's call there.)

**D-178, 2026-10-27: The frogs are rebuilt as frogs (round F2's B).** Dominic: "and frog b". The frog becomes a frog as a
frog is: squat on folded haunches, a forelimb planted, a wide flat head with the eyes on top, webbed feet
(`tools/blender/concept_creatures.py` frog B is the concept), at the heroic humans' quality (milestone 23), like the rats
(D-177). Not built yet; the animation option (study A2) is still open.

**D-179, 2026-10-27: Animation goes by keyed limbs baked per body (study A2's B), with A's timing on top.** Dominic: "B
yes". Every creature's legs are cut at the hip and baked in 8 knee-bent walk steps (as the cat's are), its arms in more
holds (walk swing, wind-up, contact, follow-through), its tail and head as parts of their own in a few poses; the
composer plays them as keyed cycles, with anticipation, contact holds, lag and sway in its timing. Built body by body,
the rat first (D-177), each through the placement check. Whole-unit pre-rendered frames (C) stay for heroes or war
beasts if ever.

**D-180, 2026-10-27: Capes only when asked; every unit baked at the size it's drawn.** Dominic, playing the Lobster
game: "still unsure why our units have capes. looks out of place as a standard thing", and "sheep look pixelated".
Capes go the way of banners (D-174): the cloth cape only when a prompt asks for capes or cloaks, or for the royal
culture (its signature); the leaf cape only when asked (parts.json `only_if`). A unique unit's signature kit keeps its
cape (sworn knights, bog lurkers, moss wardens), and heroes keep theirs. This changes race keys and prices (a cape was
a point). Units drawn at a scale other than 100 (sheep 135, boar 115, giants 150, tiny races 80) were sprites baked at
100 and stretched; now each part bakes at its unit's size (the bake key carries it, `PartShape.size`, `PartBaker.bake(..., at)`),
so a big sheep or a tiny viking keeps the art's own pixels. The composer still scales the unit's node (sockets, legs and
offsets stay in part units); a sized sprite draws at 1/size, so the two cancel. Claude's design.

**D-181, 2026-10-28: The frog as built (D-178, D-179).** Claude, building frog B: no quiver on frogs (it stood off the
sloping back like a post, as on the rat: parts.json `not_worn_by`, which changes race keys and prices); its heel just off
the ground (the concept held it up, and seen from behind no foot showed on the ground); its head baked cut by its body;
slung shields lie along the back (`slung_lean`); frog crews stand 7 back from their place at an engine (`crew_back`), the
squat body being well ahead of its hips; crew at work on a platform stand back too, riders don't.
**D-168, 2026-10-26: Races and the match start are made in Lobster; Godot only bakes the art.** Dominic, on the
Lobster port: "Let's do it! Primarily because ... it opens us up to generation at army creation time and during the
game." Supersedes the port's first call (generation stays in Godot). The generator, pricing, identity and heroes
(`tests/lobster_spike/gen/`) and World's setup (`gen/setup.lobster`, `gen/start.lobster`) run in Lobster and give
the same races (keys, recipes, stats) and the same start, token for token, as GDScript; the game makes both from the
pack's prompts and map. Next, the units drawn from baked parts in Lobster (6b), then the baker itself (6c). Claude.

**D-169, 2026-10-26: Any race draws at once from a part library; the Lobster baker becomes the art-quality step.**
A part's bake holds its skin and cloth colours, so a race needs its own bakes. Most parts (230 of 290) are fixed
colour; only bodies, heads and legs vary with a creature's skin and six parts with a culture's cloth. So Godot bakes
every part in every colour a race can wear, once (about 90,000 bakes, 160 MB), and the Lobster composer draws any
generated race from it, looking exactly as in Godot. Porting the baker (6c) is no longer needed for new races; it
becomes where art quality is raised. Claude.

**D-170, 2026-10-26: Prices are set by fights when races are made: before a match, and mid-match.** The lobby's
loading time runs the equal-cost round robin between the match's races (the GDScript balance tool's fights, in
Lobster), prices each line by its win rate and bisects, a few rounds (about 5 s for two races). A race made mid-match
(N) is balanced the same way against the others while the match waits, the running world set aside and brought
back. Dominic, 2026-10-26: "the match load time is all balance testing etc - or we do it before the match starts".

**D-183, 2026-10-26: The Lobster game bakes its own art; Godot is no longer needed to play.** Every 3D model
(unit parts, siege engines, props, trees, buildings, their materials) is built in Lobster, checked triangle for
triangle against Godot's, and baked by Lobster's part and world bakers; the pack's tables come from data. A match
runs with no pack (`play.sh none`), the parts kept in `bake_cache/` after the first start. A mod's code-built parts
are written in Lobster too (`lobster_models` in mod.json, beside its GDScript ones while both games exist).
(Numbered 183: the art study's branch has D-171 to D-181; first written as D-173, which the art study's "heroic at 2x" also took.) Claude, for Dominic's goal: "port the whole game over to
lobster".

**D-182, 2026-10-27: The Lobster game runs on Lobster's default JIT, not `--mir`.** The voxel check for the
placement port caught `--mir` miscompiling model and rig code (the timber ram's hides tilted 128 degrees instead of
48, levelled spears turned 90 degrees the wrong way, trees' leaves and wood piles' logs misplaced), depending on
the program around them, so a check could pass in one program and the same model come out wrong in the game. The
checks had run on the default JIT while the game ran `--mir`. Without it everything matches Godot (races, starts,
models, props, buildings, the 26 parity runs), and a 10-minute bot match ran faster (66 s against 93 s: `--mir`
compiles longer than it saves). `LOBSTER_FLAGS=--mir` still tries it. (Numbered 182: the art study's branch has up
to D-181.) Claude.

**D-184, 2026-10-28: Godot retired; the game is Lobster.** Dominic's goal: "actually complete the migration to lobster.
Godot should be gone, performance for all tests should be optimised." The art study's work (rat B, frog B, heroic humans,
keyed limbs, sized bakes, 2x art, destruction) was ported and held to Godot's (models triangle for triangle, 3D
placement identical, the composer's draw lists the same), then the GDScript game, its tests and the parity tools were
deleted and the Lobster code moved to `src/`. What the parity checks proved is kept in golden files (`src/golden.sh`:
races, starts, every model and building, research text); the Godot test suites live on in Lobster (run_tests, test_sim,
test_ai, test_2v2, heroes, race identity, the balance and audit tools); `./tests/batch.sh` runs them side by side, 4 at
once by default (Dominic's fans). Supersedes D-168's "Godot only bakes the art" and D-183's "Godot left for parity".
Left over: `docs/backlog.md`, "Left from the Lobster port". Claude, for Dominic.

**D-185, 2026-10-29: Buildings and props ship baked; a unit part bakes on the GPU.** Dominic, on a 480 MB match start
for one 2v2's buildings: "Saving masses of pngs to disk at game start seems nuts"; "work smarter not harder". The
game is generative in its races, not its buildings: a culture's buildings and the props are the same for every prompt,
so they're baked once on the build machine (`src/prebake.sh` -> `src/baked/`, compressed, 152 MB for all six
architectures) and shipped; a match start bakes none of them (134 s -> 3 ms on the Android emulator) and loads a sheet
the first time it's drawn. A race's own parts still bake where it's played, but faster: meshes made once a part in
model space, projected in the shaders, and the shrink to pixels on the GPU (two races 67 s -> 9 s on the Mac, a match
start 9 s on the emulator), the same pixels as before. Claude, for Dominic.

**D-186, 2026-10-29: A match start bakes only the age it starts in; one loader.** Dominic, on the phone: "Android unit
generation is just too slow, few mins. Are we generating things we don't immediately need? Also we should only have
one loader." We were: of the 487 parts two races' units wear, 322 (two thirds) are their Age 2 and 3 line steps. The
start now bakes the steps each player can field in the age it starts in (Mac, cold cache: 28.8 s -> 4.8 s); the rest
queue for play to bake a facing a frame, the next age's first (a part's bake is now a job of eight facings,
`BakeJob`), done in about 20 s of play on the Mac, well before anyone ages up. The bake drives the match loader's own
bar and line ("Making the armies"), instead of a frozen picture of it with a second line underneath; the title and
setup pages lose their own "Making the armies" bar, and a unit there shows once all its parts are baked (not a spear
floating on its own). Claude, for Dominic.

**D-187, 2026-10-30: The game's icon is the parts kit; the boot screen shows it in gold.** Dominic picked the Discord
icon (a frog, a horned helm, a shield and a sword on a model-kit sprue, ink on yellow: `docs/concepts/icon/chosen/`)
as the game's icon. Its source is now `assets/art/ui/game_icon.svg`: Android's launcher icon (an adaptive icon, the
yellow behind and the ink inside the safe zone; the splash shows it on the dark brown), the Mac's Dock icon through a
new `gl.window_icon` in Dominic's Lobster fork (SDL_SetWindowIcon), the Deck build's `icon.png` and a desktop
launcher. The boot screen (before the title) was only text; of three concepts (`docs/concepts/boot/`: the yellow tile
on the wood, a yellow card, the ink as gold inlay on the wood) Dominic picked C, the gold inlay, of a piece with the
title's gold crest, with a bar over the start's steps. Claude, for Dominic.

**D-188, 2026-10-31: The drawing's cost is checked in the real window; frames make no GPU buffers.** The laptop ran
hot and no test saw it: every speed check ran headless. `perf:<seconds>` (`src/game/perf.lobster`) plays a watched
match in the window with vsync on and the frame cap, the Town Center selected, and fails when a frame's work (outside
the swap's wait and the cap's sleep) is over 6 ms median or 9 ms at the 95th percentile, when it draws more than 66
frames a second, or when a frame creates GPU buffers (`gl.buffers_made`, new in Lobster). Measured on the MacBook:
3.3 ms, 4.6 ms, 60 a second, none. It runs in the full batch, alone. Shapes drawn every frame use `gl.draw_mesh`
(new in Lobster: a mesh's arguments drawn from pooled buffers), never `gl.new_mesh` + `gl.render_mesh`: the UI made
about 1,500 buffers a frame that way, 13.7 ms of a frame's work. Claude, for Dominic.

**D-189, 2026-10-31: The bears' bodies are one lofted mass (B4 option A).** Dominic, on bears "made of spheres" with
"a weird bit out the back of their neck", picked A of round B4: a biped bear's torso, neck and shoulders are one mesh
lofted through the kit's volumes (`body.loft` in `data/creature_kit.json`, `kit_loft` in `src/model/kit_bodies.lobster`),
round in section and smoothed, so the hump is a swell of the back and the neck widens into the shoulders. Worn
armour is fitted to the loft. The lump itself was a bug: the neck ended where the head would be if the bear stood
straight. The mount bear (four legs) keeps its volumes for now. B (carved planes) and C (tapered limbs) stay in the
sheet `tests/sheets/bears_b4.json`. Dominic picked, Claude built.

**D-190, 2026-11-03: The long-term shape is an RTS engine with the game as content on it, the way Spring (now Recoil)
splits engine and games.** Dominic, on how the open-source engine built for the commander game handles games ("sounds
like a good option"). The engine owns the deterministic lockstep sim, pathing, rendering, sound, networking and
saves; a game is content plus scripts on it, and a mod is more of the same that may depend on and override another.
Our steps toward it: content as data (voxel units first, then buildings, props, effects as voxel pieces and recipes),
buildings, tech, AI and sound mergeable by mods, our own content loaded as a base pack like any mod, then small
deterministic script hooks for rules (like Spring's synced gadgets) and free client-side UI extras (like its
widgets), and multiplayer refusing a match whose packs don't match. Not a separate engine product yet: one game, and
the boundaries still moving. Claude's recommendation; the order is in `docs/backlog.md` (section 00).

**D-191, 2026-11-03: Engine split, first answers (Dominic, on `docs/engine-plan.md`).**
- **Structure as drafted, one repo for now** (`engine/` and `games/age-of-anything/`): "we should move towards
  splitting this out more cleanly, and see what hooks are needed".
- **The engine will be open source.** The game stays ours. Licence still to pick (the plan leans MPL 2.0 or Apache 2.0;
  not GPL, which would reach the game through Lobster compiling it all into one program).
- **Hooks broad enough not to box modders in:** "I don't want to force people to only develop based on our
  expectations - but if they need the whole source to do anything it's a lot of extra effort for them too." So the
  hook list is found from real needs (the sci-fi mod, our own content as a pack), and the open engine source is the
  escape hatch for anything hooks don't cover.
- **Race keys never change with content updates:** "races can't change with content updates surely, that's
  terrible". The base pack's signature stays out of race keys; a race names only the extra packs it was made with.
- **Name:** Dominic floated "Age Engine"; not settled.

**D-192, 2026-11-03: Buildings play roles; the sim and the bots look them up by role, never by id (Claude, engine
plan step 1, as D-190 and D-191 asked).**
- `data/buildings.json` gives a building `roles`: `hub`, `housing`, `trade`, `barracks`, `tower`, `defence`, `wonder`
  (documented in its `_roles_doc` and `docs/modding.md`). The sim keeps them as a bit per role in `bt_roles`
  (`lib/state.lobster`: `has_role`, `btype_with`); an unknown role asserts at the start.
- Every building keeps exactly what it did: the town center is the hub, the house housing, the market trade, the
  barracks barracks, the watchtower tower and defence, the bastion and castle defence, the wonder the wonder.
  Matches play tick for tick as before (test_sim, test_ai, save_check, the golden starts unchanged by it).
- No role where a field already says it: a farm is `becomes`, a pen is `pen`, a camp is a drop-off that isn't the hub
  (the lumber camp the bots lay by a road is the first camp taking wood).
- What stays by id is data naming data: the bots' build order, `research.wait_for`, `military.raid_targets` and
  `expand.camps` in `data/ai.json` name buildings, and `btype_named` finds them.
- Saves outlive builds (D-141): a save from before roles comes back with each type's roles read from
  `buildings.json` by its id (`roles_from_data` in `gen/start.lobster`, called by the load); so does a scenario file.

**D-193, 2026-11-03: Race generation is a toolkit module, not part of the engine.** Dominic: "clear race generation
should be part of a tool kit and game, not the engine. If people want the randomised selection it's available as a
module to use in their game." The engine has three layers: the core (sim, bots, view, UI, net, tools), optional
modules a game can import or leave (`modules/racegen/`: prompts to races, pricing by points, identity, heroes,
balance by fights), and the game (ours brings its words, parts and cultures on top of racegen). So a game with fixed
factions loads them from data and never touches the generator; the unit type seam in `docs/engine-hooks.md` is what
makes that work. `docs/engine-plan.md` section 3 updated.

**D-194, 2026-11-03: The lobby draws at 30 frames a second, a match at 60, a minimised match not at all; the HUD and
the world batch their draws (Claude, on Dominic's "my laptop still gets hot").** Frame pacing lives in
`game/pace.lobster`. Every baked frame is still a sheet of its own on disk and in memory, but sprites are drawn from
shared atlas pages (`game/pack.lobster`): a small sheet is copied onto a page the frame after it's first drawn, so
nothing about baking or the bake cache changes. Flat UI fills, lines and studs inside `ui_batch` gather into one
mesh until anything else is drawn, which keeps the layering exact (the panel, top bar and minimap captures are byte
for byte the same). The `perf:` check now also guards the main thread's busy share (22%).

**D-195, 2026-11-03: Prices are fixed per unit, calibrated offline by fights; a match loads without fights
(supersedes D-170).** Dominic, 2026-10-31: "why are we balancing? we control all the inputs, but we act like the
outputs are an unknown?", and 2026-11-03: "We were trying to simplify, so remove the need for all the testing before
matches." The fights only existed because adding up part points doesn't add up strength, and D-170 priced each line
as a percent of its price against whoever it met (a unit's price depended on its opponent). Now
`src/calibrate.lobster` fights a few hundred generated races' lines against a fixed panel (the lines of three random
races) at equal cost, finds each line's fair price, and fits every part's `price_points`, each line's roster
`price_points` and the giant and tiny price points (`rules.cost.giant_price_points`, `tiny_price_points`: the
generator still spends `GIANT_POINTS`, so recipes and race keys don't move) by weighted, regularized least squares;
`tools/balance/write_prices.py` writes them into the data. Measured on held-out prompts at the same data, with no
fights at load: one pool of 124 lines (about 140 fights each) went from 71 lines more than 10 win-rate points off the
mean to 30 (sd 16.7 to 10.7); round robins of 2 to 5 races (as matches are) from 87 of 145 to 55; the setup's default
pair from 7 of 14 to 5. Even each line at its own exact panel price (no fit) left 39% of the pool off at pass 1: a
group's round robin gives a line 13 fights, so coin flips alone put half the lines 10 points off; the pool is the
fair measure. The cost: counters are weaker at fair prices (the counter fights 90% to 72%, the check now 70%):
infantry pays for beating most of the field and loses its fight with cheaper spears; the counter bonuses are
Dominic's call (`docs/backlog.md`). The match start, a race made mid-match and the loader's "Balancing the armies"
step are gone; the Race Lab's Test still shows one round of fights. The batch checks the held-out round robins
(`calibrate.lobster measure check:45`), and `mod_check.sh` prices a mod's new parts. The commits say D-194 (that
number was taken the same day). Under D-193 the calibration, like balance by fights, belongs to the race-generation
toolkit module (`modules/racegen`), not the engine core.

**D-196, 2026-11-03: The engine's licence will be Apache 2.0** (Dominic: "apache is fine"). It matches Lobster's own
licence, lets anyone use it in closed games (ours stays closed) and grants patent rights; engine changes aren't forced
back, which MPL would have done. Not GPL: Lobster compiles the game and its mods into one program with the engine
(D-191). The reference bot ships with the engine as its default AI, tuned through `ai.json` or replaced through hooks.

**D-197, 2026-11-03: Text is drawn from atlas pages; a window in the background draws at 10 frames a second, the idle
title at 15 (Claude, on Dominic's "We definitely can't have text slowing down the game").** `game/text_cache.lobster`
draws each distinct label once into a page (premultiplied, so its edge and text composite as on the screen) and then as
a quad, a batch's labels in a draw a page; at most 24 new labels a frame, the least recently used page emptied when
they're full. `perf:` fails a match whose text costs over 0.1 ms a frame. Lobster gains `gl.window_focused()`;
`game/pace.lobster` paces a window without the focus at 10 frames a second (the sim and lockstep keep their pace;
tests and captures are exempt) and the title at 15 after two seconds without input. Lobster's frame cap sleeps in one
long sleep instead of 1 ms steps.

**D-198, 2026-11-03: A bot clearly ahead presses home its lead; the bot-against-bot check asks a leader to win, not
equals to (Dominic: two equal bots stalemating isn't surprising; a bot with a big lead not pressing home is the bug).**
Claude. Before, frogs against rats ran to 30:00 (and 45:00) with no winner although the rats had 49 workers in age 3
against 21 in age 2: both sides traded armies of 2 to 12 all match. Now a bot that is clearly ahead of the enemy it
knows of (`military.press` in `ai.json`: from 10:00 with 20 workers, an age up or 130% of the enemy's workers as it
knows them, those seen lately or one a remembered building, and 75% of the army it remembers) masses an army first
(24 population, or 150% of the enemy army it remembers), saving for those soldiers instead of the next age; while
massing its soldiers stay home (no answering a tower's arrows or chasing raiders home, which is where the rats' armies
had been bleeding away); then the whole army goes for the Town Centers, past raids and contain waits, rams for the
Town Center first, reinforced by every 4 soldiers that gather at home, and comes home to mass again only when it's
down to 30%. It never masses longer than 4 minutes. Easy wants a bigger lead (160%) and masses 20, Hard presses a
smaller one (120%) with 20. The losing side is unchanged. `test_ai`: a side clearly ahead by the real state (an age
up, or 150% of the other's workers with 20 or more, two minutes running) must win within 12 minutes of it; a match
with no clear lead may run to the limit. Heroes are checked over the three bot matches (a match won early can end
before either side affords one).

**D-199, 2026-11-03: Counters keep their edge: prices are fitted against what the counter chain expects, not
against the whole field's average (refines D-195).** Dominic: "swords should beat spears. Basic rule across most
games of the genre, no?" D-195 fitted each line to win half its fights against a panel, so a counter's wins were
charged as strength: infantry got dearer until equal-cost spears beat it (counters 90% to 72%). Now each panel fight
has an expected result by the counter chain, infantry > spear > large/mounted > ranged > infantry and skirmishers >
archers: 80% where the line has a counter's edge (one of its attack bonuses is for a class the other has), 20%
where the other has, 50% where neither has. A line is fairly priced where its score meets that. (Pricing on neutral
fights alone, as first asked, left archers unpriced: the bow's +2 against infantry is an edge over nearly every foot
unit.) test_sim checks each pair on its own, at least 70% of its equal-cost fights on every race and both sides.
Skirmishers beating infantry is not one: the roster gives swords +3 against them, they're for archers. To pass,
the roster gives infantry +6 against spears (was +3) and the large line +6 against ranged (it had none; lances
only), both in data (`data/rules/*.json`). Measured on held-out lines, each line's wins against what the chain
expects of its fights: 78 of 124 lines more than 10 points off at points-only prices, 42 at D-195's, 38 now
(sd 18.6, 10.6, 10.3); the round-robin groups the same way, 32% off, which the batch checks (45% fails). The
commit says D-196 (taken the same day by the engine's licence).

**D-200, 2026-11-03: Prices are fitted in the state fights happen in, by a lean calibration.** Dominic: "are you
taking into account the armory upgrades?", "Upgrading for example someone's armour against arrows should have clear
but balanced effect", and "I don't think we need 165000 tests to check balance". The fights of an age give both sides
the soldiers' research of that age and before: the armoury's, barracks', archery range's and stable's (16), not a
culture's or creature's own (castle research is race identity: measured, never fitted). The calibration is lean: a
fixed panel of 8 lines (a line of each role and an odd creature), each training line fought at 80% and 125% of its
price (a third price only when the two don't bracket), training races chosen so every part is in at least 6 lines;
19,800 fights in 67 s on 4 cores. Every fight's result is kept, and the fit reads them by the rule in use, so changing
the rule refits in a fraction of a second, without fighting again (passes 6 to 9 had rerun 40-minute fights for
changes of rule only). The rule: a counter by the chain (`gen/counters.lobster`) is expected to win 80% whatever
bonuses the other carries, else a bonus edge 80%, else 50%. For the chain to hold with upgrades on, the roster gives
swords +8 against spears, spears +8 against mounted, the large line +8 against ranged and 2 pierce armour,
skirmishers +4 against archers. The pairs are checked in ages 2 and 3 (`calibrate.lobster pairs`, in the batch);
spears against horse archers (they stand off at range 6) and the large line against archers in age 2 stay short,
listed open for Dominic. Held out, with upgrades on, against what the chain expects: 57 of 124 lines more than 10
points off at points-only prices, 47 calibrated (sd 14.2 to 11.9); plain win rate 65 to 43.

**D-201, 2026-11-03: Units are voxel bodies by default; the composed units stay behind `composed`.** Dominic: "replace
all units with voxels", with "a clean simple pipeline, ideally configurable so other people can make tweaks". Every
unit type is one procedural voxel body read from `data/voxel/` (bodies, gear, holds, materials, the part-to-gear rules;
a mod adds its own), baked into whole-unit frames in 8 facings: standing, walking, working, attacking, and falling dead
then lying (the body turned onto its side, then a puff of dust and a fade, as the composed ones did). A look is what a
line step looks like, so most of a line's steps share one. The start bakes only what each player fields in the age it
starts in, standing and walking (and working, for workers), in their first look: sewer rats against Romans, cold, 2.1 s
(it was 42 s for everything); a warm start loads them from the bake cache in 13-18 ms. The rest (attacks and falls,
the other looks, the later ages' steps) bake in play at 6 ms a frame, a fill sliced over frames and each cache PNG
written in a frame of its own (the engine's `gl.save_texture`); a step drawn before it's baked is asked for first and
drawn in the step before meanwhile. Voxel units draw cheaper than composed ones (perf: 1.9 ms median against 2.4).
Engines with a crew (siege, war beasts, the trade cart), the stables' tethered mounts and the lobby's pages are still
composed, their parts baked as before; the panel's and the tech tree's portraits are voxel frames. Claude, for Dominic.

**D-202, 2026-11-03: The composed units are gone; units are voxel bodies only.** With voxels the default (D-201), the
lobby voxel and the engines and war beasts voxel bodies with their crews, nothing needed the composed pipeline, so it
was removed rather than kept beside the voxels ("don't leave two pipelines"; Dominic, relayed). Out: the composer
(`view/unit_view`), the part baker and its queue (`view/part_bake`, `game/bake_missing`), the 3D corpses and rigs, the
unit models in code and Blender (`model/units*` and the rest, `assets/models`' 72 `.glb`, `tools/blender`), the
placement check (`placement/`, `placement_check`), the sheet tool and its 53 specs, mods' Lobster models
(`mods_gen`; a mod's parts need no model now: their looks are voxel gear by `data/voxel/`'s rules), the Godot art
packs and flipbooks and the `composed` option. The unused definitions left in the shared files (the baker, art, node,
the model kit) went too: about 27,000 lines in all. The checks that replace the placement check are `voxel_check` and
the feet-on-shadow check (in the quick batch, which went from about 100 s to 25 s). Lost for now: workers' tools and
loads by job (the rats' barrow and handcart), the stables' mounts grazing, the engines' packed and throwing poses,
the culture styles' shapes (they're colours only). Claude, for Dominic.

**D-208, 2026-11-03: Buildings and props go voxel; the Creel name and its mock site stand.** (Numbered D-203 at first, a
clash with the voxel session's D-203 the same hour; renumbered. The building choice itself is D-203.) Dominic, after the
building experiment's second round (pictures 30-32, 39): "buildings yes" (a pediment bug to fix first). The rollout
is planned in its own milestone, as the units' was (D-201, D-202). He also turned down a charge for spears against
horse archers ("charge, no"; backlog, open counter pairs) and approved the Creel mock site (`docs/engine/site-mockup/`,
"creel site looks good"); Claude picked the name Creel from the engine plan's shortlist.

**D-203, 2026-11-03: Buildings and props go voxel: the models voxelized first, voxel data culture by culture after.**
Dominic, after the building experiment: "voxel buildings yes"; on the plan's three ways (voxel data per look,
voxelizing the existing models, or both): "C, go. I will have another agent review all the art afterwards." So every
building, stage, wall and prop is first its existing 3D model rasterized into voxels (the shapes he likes, every
look at once), shaded by the voxel light, its materials' textures sampled into the voxels; then the looks that show
most (the Town Centers and houses first) are replaced, culture by culture, by voxel data with voxel-native detail
(tile rows, patterns, lights). The baked-building pipeline goes once nothing needs it (milestone 24). Claude, for
Dominic.

**D-204, 2026-11-03: Horse archers are countered by heavy cavalry and scouts, not spears.** Dominic: "aren't heavy
horses counter to horse archers? whats the norm in the genre?", then "change the horse archer counters and run
fights" (and earlier: no charge for spears, D-203). In the genre what catches a horse archer beats it: heavy and light
cavalry; spears can't close. The chain (`gen/counters.lobster`) drops spear > mounted archer and adds large > mounted
archer and scout > mounted archer, checked by `calibrate.lobster pairs`: 8 of 8 and 8 of 8 in age 2, 8 of 8 and 6 of
8 in age 3. Skirmishers > mounted archer stays in the chain as an open pair (5 of 8, 2 of 8; +8 against archers didn't
fix age 3, so it went back to +4). The refit from the stored fights is the same under the old and new chain (the
lines' bonus edges already set those expectations), so no price moved; held out against the chain, 50 of 145 lines are
more than 10 points off (51 under the old chain). The line's description reads "weak to heavy cavalry and scouts".

**D-205, 2026-11-03: Prices refitted from fresh fights; every counter pair holds but one.** Dominic: "apply the 21
price moves too". Those 21 came from fights taken before the current prices were written (13:34, prices at 13:43), so
applying them counted the same correction twice: held out, 65 of 145 lines went more than 10 points off (from 50), and
skirmishers > archers and scouts > horse archers broke. Reverted; the lean calibration rerun at today's prices (ages 2
and 3, 3 minutes) and refitted: 33 parts and slots moved by a point (horse archers 1 -> 3, skirmishers 0 -> -1,
swords 3 -> 2, scouts -4 -> -5, giants 2 -> 1). Every counter pair now holds in ages 2 and 3, skirmishers > horse
archers included (7 of 8, 8 of 8), except the large line > archers in age 2 (8 of 12, open). Held out, 53 of 145 lines
more than 10 points off (50 before: within the noise). Golden races and starts updated (costs only).

**D-206, 2026-11-03: Balance closed.** Dominic: "I want to stop going in circles with balance now. Whats left? please
solve and close". In one pass, one fight run at the end:
- **Padded coats +2 pierce** (was +1), so armour against arrows is felt (Dominic, D-200). Quilted vests and leather
  jacks stay +1: +2 turned the large line's fights with archers.
- **Prices refitted once** from fresh fights at the final data (32 parts by a point). Every counter pair holds in ages
  2 and 3, the large line against archers included (9 and 10 of 12); `RR_COUNTERS_OPEN` is empty. Held out against
  the chain: 54 of 145 lines more than 10 points off (37%, the batch fails over 42%).
- **Bot levels:** no setting made a bot stronger than normal's (over 8 mirror matches, hard from each start: the old
  hard 3-4, faster ones 1-5), so normal's settings became hard, and normal waits longer (200 s) with smaller waves (80%
  of the army): hard wins 3, loses 2, draws 3. The test plays the mirrors from both starts instead of one rats-frogs
  match (which swung with any price set: the starts aren't equal, and rats beat frogs at every level).
- **The backlog's balance section is closed** to what's design rather than tuning (calibration's reach, kiting
  archers, smarter hard play), each waiting for a reason to reopen; the batch keeps the pairs and the round robin.

**D-207, 2026-11-03: The bots save for the next age, gather less stone, and the level checks pass.** Dominic: "fix the
failing easy and normal level checks". `test_ai -- levels` (a bot left alone with a passive one) had failed since
before D-206, for three reasons:
- **The bot won early**, and every 20-minute check read an empty match: D-198's pressing a clear lead isn't "left
  alone", so `no_waves` turns it off too. Winning outright later (around 20 to 30 minutes, its lead clear) counts as
  the army still growing.
- **The build order spent what the age-up was saved for** (the University, a market, towers out of the age's wood):
  while saving for the next age, the bot builds only houses and what that age needs, as a player would. Age 3 went
  from 17:41 to about 15:00.
- **Stone piled up unused** (330 to 580 by 20:00, while food ran dry and research waited): the gathering mix is food
  40, wood 30, gold 25, stone 5 in age 2 (was 35/30/25/10) and food 45, wood 20, gold 25, stone 10 in age 3 (was
  35/20/25/20). Normal and hard save for age 3 at 24 workers (was 26).
All 11 level checks pass; hard still beats normal over the mirrors (3 won, 2 lost, 3 drawn).

**D-208, 2026-11-03: Buildings and props bake only as voxels; the old baker is gone.** Following D-203: every model
voxelized through `view/voxel_mesh.lobster`, in the old baker's frame so the art kits place everything as before; the
GPU baker (`view/world_bake`, `view/baker`) removed (Dominic: "lets get the old baker stripped out"). Hand-built looks
culture by culture are Dominic's, later ("dont do any hand building for cultures, ill do that later"). A rule that came out of it, from
Dominic on the wall pieces: "They MUST end before next model": a wall tile bakes whole; a gate's towers, posts and
middle are frames sorted where each stands. Gates also open now (their open look had been baked but never drawn since
the port). Claude, for Dominic.

**D-209, 2026-11-04: The still ground is a picture.**
The ground and hills go through a window-sized texture while the camera holds still (`draw_ground_cached`, game/ground.lobster), redrawn at 15 Hz for the water (its `time` in the same steps) and when the masks, paths or wear change. A moving camera draws them straight, because the picture cost 1 W more than drawing live when redrawn every frame. GPU 2.1-3.1 W to 1.0-1.3 W with the camera still. Water moves at 15 Hz. Claude, for Dominic's hot laptop.

**D-210, 2026-11-04: Issues first, and the game on a clean Lobster fork.** Dominic: things were getting out of hand. Everything implemented gets a GitHub issue first; the backlog and every upstream Lobster change are issues. The game builds only against the `game` branch of `Drache93/lobster`: upstream master plus one commit per fix, with a message detailed enough to split later. No stashes, no patching the engine in a build. A change stays only if removing it breaks something. Python goes (#114). Rules in CLAUDE.md. Dominic.

**D-211, 2026-11-04: No Python in the project (#114).** Dominic: "we need to really remove how much Python we use." About 6,500 lines, left over from the Godot days. Everything a build or check runs, the mod tools, the price writer, the crests and the audio synth are now Lobster or shell, each checked against what the Python wrote. Retired rather than ported, Dominic's call: the map generators (`data/maps/*.json` rows are the source now; two of the four already failed their own crossing check), the one-off concept scripts, stickers and the icon cutter (all in history at 3d0a1e2a). The bakes' PNG squeeze is now ImageMagick: 151 MB against zlib's 124 MB, with better compression left for #118. `.claude/launch.json` still starts `python3 -m http.server` for page previews: nothing in the game or its tools.

**D-212, 2026-11-05: Staple resources and formation bands are data (#20, engine plan step 1).** The lib no longer reads a building's name: the bots compare kinds, and only `data/ai.json`'s names go through `btype_named`. The two resources a bot buys when short are `staple` in `data/resources.json`, in a sim global beside `gather_spots` (not the AI config, whose tokens the golden hash covers; a save without it reads the data, as `roles_from_data` does). The classes behind the rear and flank formation bands are `band_machine` and `band_mounted` in the rules' `combat`. Single-purpose lookups such as `resource_index("gold")` for trade stay: the plan only asks for the lists. Claude.

**D-213, 2026-11-05: What a mod can take out of the game (#18, engine plan step 2).** Every data file is read through `lib_data`: the game's file with each mod's change merged on top. Mods can change `buildings`, `tech`, `ai` and `audio`; `resources` and `terrain` stay shut, as the sim's arrays and the bots' mixes are indexed by them. A mod's removals apply to the whole match, and `lacks` stays for one culture. A new building needs `extends` and uses that one's model. Taking a building out takes its research and an age's need for it, rather than refusing the mod (a change from #18's plan, which refused a broken `requires`: having to list every research at a removed building would be clumsy). Sound stays out of a mod's signature. The glowing bolt counts as a laser for now; a beam is its own issue. Mod matches are local until step 4. Dominic took each recommendation; the requires change is Claude's.

**D-214, 2026-11-05: Shot looks are knobs, not types (#127).** Dominic: a sci-fi range needs straight bolts, pulses, scatter and beams, and to mix them, so no `"draw": "beam"` type. Every shot look, the game's and a mod's, is the same knobs (arc, form, len, w, hold, pulses, scatter, wobble, jag, col, glow, fade) in `data/shots.json`. All view only: the sim fires one shot and decides one hit, and extra pulses and pellets are drawn on the view's own timers. The game's looks moved there as presets with the same numbers and the same drawing routine. Dominic chose the direction; Claude the knob names.

**D-215, 2026-11-05: A body may carry a gait (#142, #143, #151).** Dominic liked the 7-head humans but found their animations uncanny. The motion was made for smaller figures: same-side arm and leg, skating feet, a hop every other frame, arm-only blows, a frozen stand. A `gait` in a body's data now gives a walk with planted feet, a split stance and body drive in blows, and a slow standing sway; only humans have one for now, so rats and the rest keep their motion until Dominic has seen it. Claude's call: loads are by resource for every body from `gear.json` (`loads`), so `push_home` (D-127) is no longer what draws a barrow.

**D-216, 2026-11-06: Aim lives in the sim, and only a turret has one (#176, #177).** Dominic tried tanks in a match: they had to stop to fire, and their turrets didn't point at anything. He chose aim in the sim over a view-only turn, because it decides who can shoot when (and real air units next, not a flying skin). The sim had no facing at all, so a unit type now opts in with `turn` (degrees a second) and `arc` (degrees): a gun with its own `u_aim` and its own target `u_gun`, which turns at that rate, fires only within the arc, fires on the move, and comes back over the hull. A hit doesn't stop a turret under a move order; its gun answers. Any type without `turn` plays tick for tick as before (Claude checked a bot match against main with the new columns masked out of the hash: identical at every checkpoint). A hull that must turn to aim, a casemate, waits until the sim has a hull turn rate.
