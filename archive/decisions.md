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
