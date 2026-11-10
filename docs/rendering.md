# How the art is made (rendering pipeline)

Everything you see in a match is voxels baked to pixel sprites and drawn as 2D sprites. Units are **voxel bodies** made
from data (`data/voxel/`), baked by the voxel builder; buildings and props are 3D models in code, voxelized when
they bake (`view/voxel_mesh.lobster`, D-203). The game is written in Lobster (`src/`, run from there); the bakes are kept on disk
after the first one (see "When the bakes run"). Since D-173 the art scale is 3.0 art pixels per canvas unit
(`ART_SCALE` in `src/view/art.lobster`; a tile is 192 x 96 art pixels, and at play zoom an art pixel is a screen
pixel). The world keeps the coordinates it had (`ART_BASE` 1.5: a tile is 96 x 48), so a sprite baked at
`ART_SCALE` is drawn at 1 / `ART_K` of its texture's size and everything shows at the size it always did. The sim
never sees any of it. This page is the map; the code says the details. How to make voxel art well (what makes a
subject read, colour, checks, review) is the voxel-art skill (`.claude/skills/voxel-art/`).

## Voxel units (data/voxel/)

Sizes live in one table, `data/voxel/sizes.json` (a mod has its own): each body's `size` and its height `h` in voxels (a human 58, 32 art px), and each mount's `ride`, its size under a rider of the human's height, scaled by the rider's height. `size_check.lobster` (quick batch) fails when the drawings and the table part. A mod body not in a table keeps its own `size`.

Models drawn in MagicaVoxel (`.vox`, #313): `view/vox.lobster` reads the file; a `model` shape samples it as a distance grid like any other part, and a body with `"vox"` takes its posed limbs, parts and points from it (`docs/modding.md`, "Drawing it in MagicaVoxel"). Checks: `vox_check` (the reader), `vox_model_check` (placement, facings, materials, the bake key, the `creel.vox` palette), `vox_body_check` (joints from the drawing, the walk, bad files). A mod can ship `.vox` models (`voxel/models/*.vox`, hashed into its key); `mods/vox_example` is the worked example, and `vox_mod_check` holds it. How to design a unit that way (scale, faces, clothes, holds, riding) is in the voxel-art skill, "Units drawn as .vox".

Every unit is a procedural voxel body (D-201; Dominic, 2026-11-03: "replace all units with voxels"; the composed
units of parts were removed after it). Everything about how a unit looks is data in `data/voxel/`; `src/view/voxel.lobster` is a small
builder that reads it, fills a voxel grid at a voxel a baked pixel, and draws 8 facings with banded light,
self-shadows, an outline and a ground shadow of their own. `src/game/voxel_units.lobster` bakes a match's unit types
(cached in `bake_cache/` by look, keyed by the builder's source and the data). A look is what a line step looks like; each look bakes in jobs (a mode or two, one
look, an atlas each): the start bakes its players' start-age looks standing and walking (and working), everything else
queues for play, 6 ms a frame (`vx_tick`: a fill sliced over frames, `vx_fill_begin` / `vx_fill_more` / `vx_fill_end`,
and each cache PNG written in a frame of its own). Dying is the standing pose turned onto its side (`vx_fallen`), 6
steps. A frame drawn before its look is baked asks for it first (a unit
of a later age put down). The lobby's armies, the panel's and the tech tree's portraits and the stables' mounts are
the same looks, baked through the same queue and cache.

Coordinates are body units: z up, y forward, x right, the ground at z 0. A body unit is about a world pixel.

- `materials.json`: `name -> {rgb, fur}`. `skin` and `pale` are the race's (palettes.json), `coat` a mount's, `team`
  the sprite shader's key.
- `bodies/<creature>.json` (the id is the generator's creature): `size`, `fur` (flecks), `skin`/`pale` (when the race
  gives none), `skin_scale`, `reach` (a foot's swing: the walk steps by ground covered with it), and:
  - `points`: named points, `{at, bob}` (bob: how far it rises in the walk); with a `gait`, also `lean`, `sway`, `drive` (how far it goes forward walking, over the planted foot, into a blow).
  - `gait` (optional; without it a foot's sine and an arm's reach): `heel`, `toe`, `toes` (the foot's roll), `arm`, `held` (hands' swing against the leg), `twist` (shoulders walking), `front`, `back`, `dip`, `turn` (a blow's stance and body).
  - `legs`: a pair each (the right one given, mirrored): `hip` (a point and offset), `foot` (where it stands),
    `stride`, `lift`, `phase` (degrees: a back pair 180), `bones` (two lengths), `pole` (where the middle joint
    bends: a knee forward, a beast's front elbow back), `r` (thigh and shin radii), `mats`, and `shapes` on `hip`,
    `knee`, `ankle`.
  - `arms`: `shoulder` (the right one), `bone`, `thick`, `sleeve`, `hand` materials.
  - `helm` (`at`, `r`: where a helmet sits, the skull's size), `armour` (`a`, `b`, `r`: a capsule over the trunk),
    `seat` (a rider: `z`, its seat's height, and `astride` materials; a mount: `at` where its rider sits, `wide`).
  - `looks`: per look a skin shade and a hair colour (a unit picks one from its id, the view only).
  - `shapes`: the body.
- A shape: one of `cap` (to `to`, `r: [a, b]`), `ball`/`bead` (`r`; a bead is hard), `disc` (`n`, `r: [radius,
  thick]`), `box` (`n`, `half`, `round`), `chain` (points, `r: [first, step, least, taper]`, `mats: [first, rest]`),
  `ring` (a scarf: `r: [radius, tilt]`), `helm` and `fit` (gear only: the body's helmet and armour spots, `r` added).
  Each on a point and offset: `["head", x, y, z]`. Also `mat`, `hard` (no melting into the body; gear's default),
  `mirror` (a left one too), `if` and `unless` (flags: `look:1`, `helm`, `helm:galea`, `armour`, `seated`,
  `wear:vest`, `has:<gear>`, and any gear's `flags`).
- `gear.json`:
  - `holds`: how a hand holds (`rest`, `dir`, and for a blow `wind`, `wind_dir`, `hit`, `hit_dir`; a bow's `raise` and `draw`).
  - `gear`: held items (`hand`, `hold`, `dir`, a left item's `face`, `shapes` in the hold's frame: `[hand, along,
    out, side]`; `draw` is the drawing hand) and worn ones (`fits` per body, `*` for any other, `flags`).
  - `loads`: what a worker takes home, per body id or `*`, per resource: `gear` (held), or `push` (`barrow`, `cart`) and `heap` (a material).
  - `parts`: rules mapping a recipe's parts to gear: `part` (an id or prefix), `tag` (parts.json's), `slot`; the first
    that matches wins.

- Engines and war beasts (`bodies/siege.*.json`, written by `src/voxel_engines_gen.lobster`): a recipe's
  `siege.<kind>.<style>` finds `siege.<kind>`, its `styles` (per culture style: `skin`, `pale`, `mark` are its frame,
  iron and cloth, as the materials `frame`, `frame2`, `trim`); `crew` (spots its crew stands on, walking with it) and
  `seats` (where its crew sits, a howdah) take the recipe's `crew`, the race's own creature in its own kit. An
  engine's ground is its own z 0 (under its wheels, not its crew's feet).
- `base` (a body built on another: its fields, these over them, `add_shapes` after its shapes) and `remap` (its
  materials renamed: a war boar's hide its own, not its crew's skin).
- `check`: a body's own limits for `voxel_check` (a frog's folded knees), with the reason in a `_doc`.
- A material's `pattern` (texture in the colour, laid per voxel by its place on the shape: `blocks`, `planks`,
  `ripples`, `tiles`, `wear`, `mottle`; `size` in body units, `depth`, `mix` of `color2`, `round` for a round wall)
  and `glow` (a light, unshaded, with a halo). The buildings experiment uses them (`data/voxel/buildings/`, written by
  `src/voxel_buildings_gen.lobster`, drawn by `src/voxel_buildings.lobster`; the game doesn't load it).

A mod adds its own `data/voxel/` (the same files; a body or gear of the same id replaces the game's, its `parts` rules
go first).


### Parts that turn on their own

A body can list `parts`: `{"name": "turret", "pivot": [x, y, z], "shapes": [...]}`, its shapes in the body's frame. Each becomes a
body of its own (`<id>#<name>`, round its pivot, at its own height), baked once per facing; the hull (`<id>#hull`) is baked without
them, in every mode. The composer (`add_parts`, `game.lobster`) draws the hull, then each part over it in list order, at the pivot
for the hull's facing. A part named by a mount (`stats.mounts`) faces that mount's aim; any other part faces with the hull. A body can have several, as `tests/voxel/parts/bodies/test.twin.json` does. The body itself
keeps everything, for falls and portraits. A part's `points` (`{"muzzle": [x, y, z]}`, in the body's frame) are found on the stacked figure by
`vx_point_px`; a shot starts from its mount's `muzzle`, or 12 px up from the shooter's feet if there's none.
 `voxel_proto -- <out.ppm or -> parts <body> [voxels:<dir>]` draws every pair of facings and
checks that each pivot lands on the hull; the batch runs it on `tests/voxel/parts`.

### Running gear

A body can say `tracks` (`x`, `half`, `pitch`, `mat`, `bar_mat`, and `round`: the circles `[y, z, r]` the belt goes round) and `wheels` (`at`, `r`,
`mat`, `face`, `face_r`, `hub`, `hub_r`, mirrored across the hull; `axis` and `blades` for a prop or rotor). They are made per walk step: one cycle
moves the belt one link, the cycle's length comes from the pitch, and `voxel_proto ... parts` checks that a cycle on is the same picture.

### How a vehicle dies

A body with arms and legs crumples as it dies (`vx_slump`): its hips drop and its trunk folds forward, then it goes over. `voxel_proto -- - falls` checks it.

A body's `"death": "knocked_out"` keeps it upright when it dies: burnt (`wreck`, `wreck_rust`), its parts knocked askew (`vx_knocked_out`), burning then smoking, then fading (`collect_wreck`). `voxel_proto -- - bodies` checks that it keeps its outline.

A flier's `"death": "crash"` comes down burning, nose down and in one piece, and lands level (`vx_crashed`). `voxel_proto -- - bodies` checks that a flier never grows as it dies and ends on the ground.

### Real subjects are traced

A real vehicle is carved from real drawings scaled to published dimensions, not modelled by eye (D-235): `src/carve.lobster` and a spec in `mods/ww2/trace/`, with the references fetched by `tools/trace/refs.sh` into gitignored `reference/`. The method is in the voxel-art skill, "Real subjects".

## Mods

A mod's parts (milestone 21, `docs/modding.md`) need no models: their looks are the voxel kit's, by
`data/voxel/gear.json`'s rules (a part id, a tag or a slot to a gear), and a mod can bring its own voxel bodies, gear,
materials and rules in its `data/voxel/` (its rules go first). Head gear with `"face": "sealed"` (a closed helmet)
keeps its face covered. `src/mod_check.sh <id>` loads the mod (or says why not) and shows who wears its parts.

## Buildings, props, terrain

- **Buildings** (models in `src/model/buildings.lobster` and `buildings2.lobster`, materials in
  `build_mats.lobster`; voxelized by `voxel_bake`, `src/view/voxel_mesh.lobster`, from `akb_bake_look` in
  `src/game/art_kit_buildings.lobster`): one builder per type dressed in each architecture's kit (walls,
  frame, roof, base: `KIT`; the timber towns stand on timber sills over packed earth, no stone plinths). Baked once per culture, plus four construction stages (`AKB_BUILD_STAGES`). Data
  shapes them further (`data/buildings.json`): `scale` per culture and type, `variants` (houses
  bake four looks, turned or mirrored and resized, each building picks one; the model declares
  its `door` (and `window`) direction and a variant only uses turns that keep the door on a wall
  the camera sees), and `age_looks` (a building's
  model from an age on, e.g. the rats' oil-drum town hall at age 3).
  Live parts (banner, vane, smoke, lights) are drawn over the bake.
  **Destruction** (D-171, D-172): every building look but walls and gates also bakes four broken-up stages
  (`src/game/ruin.lobster`: the model broken in 3D before the bake: pieces off the top, others tilted and
  scorched, walls cut to ragged stumps, rubble from its own materials, charred beams; four to a render when
  they fit). The building's view shows battered, breaking and collapsed as it loses hp (with today's fire
  and smoke); when it falls, the collapse in `src/game/fx.lobster` leaves the ruin under a cloud of pixel dust (puffs drawn as
  one cloud in three passes, shade, mid, light, on the art grid). The ruin is decoration only: it burns out,
  fades after 45 s, and goes when anything is laid
  on its cells. A game capture shows a fall (`hurt:<percent>` for its damage stages; `lookframes:<arch>,<type> dump:<folder>`
  writes a look's stages and ruins as PNGs).
  **As voxels** (D-203): `voxel_bake` samples a model's triangles into a sparse shell at 1.5 art px a voxel, each voxel
  the colour its material gives there (the texture sampled, triplanar where the material is), its normal the model's
  smooth one; a lit or unshaded material glows. It draws with a smooth light ramp from the old baker's sun, its own
  shadow, occlusion in the creases, a soft outline, a ground shadow and a contact shadow, in the old baker's camera and
  frame. A model that draws nothing fills as an empty grid.
  Walls are one tile each, a tile **baked whole**: its post and the arms it has, one model ending at its edge
  (`akb_wall_tile`, one a frame the first time those joins are drawn, in the bake cache; the separate pieces draw until
  then). A tile with a diagonal join turns its post 45 degrees (shrunk inside its arms at a corner). A wall's shadows are
  frames of their own (`~shadow`) on the ground layer, so none falls on a wall.
  A gate's model returns its closed `body` and an `open` one; its parts are marked (`gate_part <side> gate_centre <x y z>`).
  Each tower or post is **a frame sorted at its own footprint**, the middle another (`:shut:mid`, `:open:mid`, with the
  arch's near parapets over a unit in the passage), so a unit in the archway or beside a tower sorts where it stands. A
  gate stands open while one of its team's units is within a tile and a half (`gate_used`). It also bakes a quarter turn
  (`^z`) for wall lines running along sim y, and the view picks the turn from its neighbours.
  **Walls you stand on** (milestone 16): a walkway piece's walkway height is `WALK_H` (`buildings2.lobster`; model units, given to the view as `walk_px`, canvas px), and units up on it are lifted by it, so they stand on the stone.
  Its merlons are made with `merlon`; the ones on the camera's side of the wall's line bake as a
  separate front layer (`akb_front_split`; a whole wall tile bakes its own), drawn beside the building in the y-sorted
  layer, a little below the piece; units on
  the piece sort between the two, so defenders stand between the merlons. Wall
  arms meet a joined piece's faces (a wall tower fills its tile). Look at joins and gates in a capture:
  `./play.sh lobby "races:romans|sewer rats" mute place:fort in_gate army:1 look:14,17 shot:/tmp/f.png at:1`
  (`place:palisade_fort` for the palisade; `vbcheck`, in the batch, checks every look for specks and team colour).
- **Props** (`src/model/props.lobster`, town ones in `town_props.lobster`; voxelized from `src/game/art_kit.lobster`; `propframes dump:<folder>` writes them as PNGs): bushes, reeds, boulders, quarry stone and
  gold, carcasses, crops, the rally flag; resources bake in used-up stages.
- **Trees** (`src/model/trees.lobster`, milestone 15): broadleaf, pine and swamp trees,
  each in a few concept looks (`style`), built like
  the bushes (leaf and needle cards over dark lobes, bark-textured trunks), baked with room for long shadows (a tree's shadow is kept apart, `<name>~shadow`, to lie under everything), in four stages: standing, felled
  (the log by its stump), sawn up, stump. The sim has one `tree` terrain; the view picks the
  species from the ground round it (`src/game/doodads.lobster`: swamp trees by water, pine and
  broadleaf groves by a smooth noise). Stumps stay until something is built there.
- **Bridges** (`src/model/bridges.lobster`): neutral timber, no team colour; every size
  the maps use is baked (read from `data/maps`), along sim x and y, standing
  and broken, one to a whole frame (a long bridge in a third of a frame lost its ends). Drawn in the flat layer (walked across, under units).
- **Terrain** (`src/game/ground.lobster`, its `SHADER` blocks): one shader paints the ground from blurred
  terrain masks (water depth and sky, swamp, rock, paths); not baked. Rivers draw as water,
  fords as shallows with the bed showing, forest floor like reed-bed ground. Worn trails come
  from the sim's wear grid (`src/sim/`), handed over as a small texture once a second
  (`ground.lobster`) and drawn as the culture paths' earth trail.
- **High ground** (milestone 15): a map's `heights` lift the ground by `LEVEL_PX` per level
  (`src/game/ground.lobster`). Four corner heights are kept per cell (ramps slope from their foot to the
  level above); `lift_at(x, y)` is the lift at a sim point, and picking walks down the screen to the
  highest ground drawn at the mouse. The raised ground is drawn as meshes: tops through the terrain shader
  again (a vertex's lift tells it that cell's ground; slopes are shaded), cliff faces down every edge that
  drops towards the camera (the `cliff` shader in the same file; layered rock in play; concept sheet
  `archive/images/2026-10-13/180`), and a dark line along back edges. Level by level under everything; and copies of the tops near a
  back edge go into the y-sorted layer, one per screen row, so a hill hides what stands behind it.
  **Everything in the y-sorted layer sorts on the base plane**: its node sits where the flat map
  puts it and its art is raised inside it (a unit's `lift`; buildings and props raise their sprites); overlays use the raised
  ground point. The fog shader walks down the screen to the frontmost ground drawn at each
  pixel and takes that cell's fog. The minimap lightens each level and darkens cliffs.
- **UI art and textures**: SVG icons in `assets/art/icons/` and textures in `assets/art/textures/` are
  rasterised to PNG ahead of time (`src/icons.sh`, `src/textures.sh`; both need `rsvg-convert`; run them again
  after an SVG changes), since Lobster can't read SVG. The PNGs are in `src/icons/` and `src/textures/`.

## When the bakes run (and how long they take)

Units, buildings and props are baked by Lobster code and kept on disk.

- **Units (voxel).** A look bakes in jobs, a mode or two each, into an atlas of its own (`game/voxel_units.lobster`).
  The start bakes its players' start-age looks standing and walking (and working): sewer rats against Romans, cold,
  about 2 s. Attacks, falls, the other looks and the later ages bake in play, 6 ms a frame, a fill sliced over
  frames and each cache PNG written in a frame of its own (`gl.save_texture`). Kept in `bake_cache/vx_*`, keyed by
  the builder's source and the data: a warm start loads them in about 20 ms.
- **Buildings and props: shipped, not baked at the start (D-185).** They don't depend on the prompt, only on the
  culture's architecture, so they're baked once on the build machine: `src/prebake.sh` runs the game with `prebake`,
  which bakes every prop and every architecture's buildings into `src/baked/` (not committed; remade when
  `BAKE_VERSION` changes) and compresses the PNGs (ImageMagick `mogrify`, pixels unchanged). The game reads `baked/` before
  `bake_cache/` (`bake_shipped_dir`); the Deck and Android builds run the prebake and ship the folder. Sheets from
  disk load when first drawn (`add_sheet_later`, `sheet_texture` in `game/pack.lobster`). One look of one building
  with its stages is a job (`akb_bake_look`, `art_kit_buildings.lobster`), a prop with its stages another (`ak_bake`,
  `art_kit.lobster`; `bake_doodads`). A cold start without them bakes the two cultures in play in about 3 minutes (a Town
  Center 0.8 s a frame, a house 0.18 s); all six architectures, about 10 minutes.
- **On disk.** `src/bake_cache/` holds every bake with a record of its frames. Buildings' and props' names hash
  `BAKE_VERSION` (`view/bake_cache.lobster`); raise it once for a batch of changes to their models or `voxel_mesh`, and
  `src/bake_cache.sh` (sourced by `play.sh`) empties the folder when the number differs from the one it stored. The
  voxel units' names hash the builder's source and the data, so they rebake by themselves.

## Checking art

Checks first, then look. A unit, mount, gear or pose change is shown only when these pass (in the quick batch):

```sh
cd src
lobster voxel_check.lobster -- [report]   # standing knees, skins as drawn in every palette and look, kit that keeps the
                                          # creature's shape, no look-alikes, no specks (report: the numbers, no failing)
lobster voxel_proto.lobster -- - check    # every unit, mount and engine in every facing, standing and walking: feet on their shadow
```

When Dominic names a fault, first add a check that catches it, then fix it. Then look, close up and at game size:

```sh
lobster voxel_proto.lobster -- /tmp/s.ppm [creatures|legs <body> [gear,..]|skins|deaths|animals|engines]   # sheets
./play.sh lobby "races:A|B" mute army:1 look:<x>,<y> shot:/tmp/p.png at:20   # the game itself (army: every type by the Town Center)
```

Buildings are also held by golden files: `src/golden.sh` compares every building in every architecture with recorded
digests in `src/golden/`; a change that is meant goes in with `src/golden.sh update`, and the diff is looked at
before it is committed.

## Siege shots

What any weapon fires is drawn by `src/game/fx.lobster` (`shot_style`) from `data/shots.json`, a mod's `shots.json` merging over it. A
look is knobs: its flight (`arc`, `form`, `len`, `w`, `trail`...), what it does at the gun (`muzzle`: flash, smoke, ring, dust, recoil on the
turret), what it does where it lands (`hit`: sparks and a sound; `impact`: blast, smoke, scorch, debris, shake), and its sounds (`sound`, `hit.sound`). It
is all view only: the sim fires one shot and decides one hit.
