# How the art is made (rendering pipeline)

Everything you see in a match is a 3D model baked to a pixel sprite once, when the match loads,
packed into one atlas and drawn as 2D sprites. The sim never sees any of it. This page is the
map; the code says the details.

## Units

1. **Models.** Each part (a body, head, leg, helmet, weapon, shield, armour...) is a 3D model:
   - Most are built in code from primitives in `scenes/art_pixel/unit_models.gd`
     (`_body_rat`, `_helm_spoon`...: the function is `_` + the part id with dots as underscores).
   - Some are **modelled in Blender by script**: `tools/blender/*.py` (run headless, see below)
     export `.glb` files to `assets/models/`, which `unit_models.glb(name, materials)` loads at
     bake time. Their materials are named (`skin`, `hair`, `team`, `cloth`...) and swapped for
     ours, so skin palettes and team colours still work. Today: the human head, torso and leg, and
     body armour fitted to the human torso (`armour_<kind>_<body>.glb`: `unit_models.fitted()` hands
     it to the worn-armour bake, which then skips `torso_fit`).
   - A model returns its node plus, for bodies, `sockets` (3D points where the head, hands,
     torso armour, back and seat go), leg `anchors`, and fitting data: `torso_scale` (2D,
     legacy), `torso_fit` (3D scale for worn armour), `torso_tilt`, `gear_scale` (on heads).
   - Concept options live in `scenes/art_pixel/concepts.gd` (`concept.*` ids), shown with
     `tests/concept_sheet.gd`; nothing there is in play until picked.
   - **Holds.** A body is baked with its near arm posed for what it holds (`unit_models.arm_pose`:
     `body.frog@throw`, `@draw`, `@aim`...). Workers are also baked in the work holds `@raise` and
     `@reach` (D-105): `UnitView.set_hold()` swaps the body's bake through the work cycle and moves
     the tool to the new hand; soldiers swing their weapons through the same holds in a lunge
     (D-106), and the view plays each death by body shape (`UnitView.die`). Animation concepts
     render through `tests/anim_concept_sheet.gd` and `anim_concept_sheet2.gd`; the live result
     through `tests/art_anim.gd` (work) and `tests/anim_fight_sheet.gd` (attacks and deaths).
2. **Bake** (`scenes/art_pixel/part_baker.gd`): each part is rendered by an orthographic
   camera from above (elevation 30) at **8 facings**, 45 degrees apart (azimuth 35 + 45k; D-087),
   lit by one warm key light from the viewer's upper left and a cool fill, with self-shadowing,
   at 4x supersampling. Each facing's bake keeps its sockets projected to 2D, how near each
   socket is to the camera (for draw order) and which way the model faces on screen.
   - **Worn armour** (torso slot) is baked on its wearer (`armour.leather~body.rat`): put on at
     the body's 3D torso socket, scaled by `torso_fit`, with the body rendered as a flat green
     holdout and cut out, so the armour wraps the body and hides where the body hides it.
     (Every body is painted as the holdout, built ones too: until 2026-10-13 the built bodies kept
     their colours, so every frog, rat, beetle and spider's armour carried a whole copy of its
     body, in the skin of whichever unit baked it first.)
   - **Cut legs and heads**: a body listed with `"cut": ["legs"]` / `["head"]` in parts.json bakes
     each leg (`leg.newt~body.newt^2`: at the body's anchor 2) or its head (`head.pony~body.pony^head`)
     in place on it, the body as the holdout (a second, flat render masks it): the sprite keeps only
     what the body doesn't hide, its origin at the hip or neck so it still swings and turns there.
     For bodies whose hips sit inside them (a newt's sprawl, a horse's thighs, a frog's haunches)
     and beasts whose head goes behind the rump facing away; and every body whose leg isn't the same
     on both sides (one sprite can't be a mirrored leg). Each hip's leg is turned to its own side
     (`UnitModels.leg_basis`: legs are modelled for the near side pointing forward; a far hip's leg is
     mirrored across the body, a flipped rear hip's fore and aft, and an anchor's 6th value fans it out,
     a spider's legs). Today: newt, pony (and the centaur's horse half), capybara, frog, boar, sheep,
     rat, spider, both beetles (the mount's head too). A body's parts.json anchors are its model's hips
     one for one (they're what's drawn before the bake, and which legs get baked).
3. **Pixelize** (`scenes/art_pixel/pixelize.gd`): down to art pixels, value posterised into
   painted bands (`ArtKit.UNIT_BANDS`: the paint-over look) and a dark outline.
4. **Team colour**: parts bake in a magenta team key; `src/team_mask.gdshader` swaps it for the
   unit's team colour (in `self_modulate`) when drawn.
5. **Compose** (`src/unit_view.gd`): a unit is its parts as sprites placed on the body's
   sockets for its current facing, layered by depth (a cape draws over the body walking away, a
   far shield under it), animated in 2D (walk cycles, hops, work blows, attacks). A unit picks
   the facing that best fits its movement on screen, with hysteresis, and rebuilds when it
   changes. The bake's alpha is hard, so see-through is the view's job: a part with `blur`
   in parts.json (a hummingbird's wings) is drawn at that opacity over the body and flickers.
   Walking, the body rides on its lowest foot (`UnitView._planted`, from the leg sprites' soles: no
   foot through the ground, none floating mid-stride). A rider's hips (its body's `sit` socket, else
   the middle of its hips) go on its mount's `seat`; it shows the leg on the flank facing the camera
   (the bake's anchors carry which side faces it), stretched down to the mount's `girth` (the baker
   finds it under the seat) unless it rides folded (`creatures.json rider_legs`).
   A hopper (`creatures.json gait: "hop"`, the frogs) hops by the ground its node covers (one hop per
   `UnitView.HOP_LENGTH` of ground, so at the sim's speed whatever it is): it crouches, pushes off with its
   legs flung back, tucks, reaches for the ground and squashes on landing, its legs bending by squashing
   (each foot rising by the same amount, the body riding down on them) and swinging only in the air. It is
   drawn ahead of or behind its node (`_hop_off`) so it stays planted on the ground while the node moves on
   and covers the ground in the air; over a hop that averages out on the node (selection and bars stay
   put). Turns and stops are made up in the air; stopped, it finishes its hop and lands on its node.
   `tests/hop_check.gd` measures it (planted feet within an art pixel, the average on the node, every facing,
   smooth and stepped); `tests/hop_sheet.gd` draws it frame by frame. Riders don't hop (their mount walks).

## Placement rules

**No unit, mount, gear or pose change is shown until `tests/placement_check.gd` passes** (Dominic,
2026-10-13, after the newt's legs folded up facing left passed the layering check). It measures,
it doesn't look; every unit of eight races at every age of its line, every rider on every mount,
winged mounts, every newt skin, the animals and the siege crews (`tests/placement/cases.gd`).

**3D** (`tests/placement/geometry_check.gd`, headless, also in `run_tests.gd`): each unit is put
together from its models as UnitView composes it (`tests/placement/rig3d.gd`: legs at their hips
turned by `leg_basis`, head on its socket, gear on its sockets, worn armour fitted as the bake fits
it, a rider's hips on its mount's seat) in every pose the game draws: standing, the swings it goes
through (a worker's tool wound up and landing, a melee blow, a spear's thrust levelled and driven
forward; ranged units only loose), and the walk at 8 phases. Meshes are read in world space and
voxelized on a 0.5-unit grid (`tests/placement/geom.gd`: primitives filled exactly, modelled meshes
by ray parity; decals left out). One part unit is 1.275 art pixels at game size.

- **A1 ground**: standing, every foot within 1 unit of the ground; nothing below -1; the centre of
  mass within 3 units of the feet's support polygon (`legs.stance.support`). Walking (the body rides
  on its lowest foot, as UnitView does), a foot within 1 unit of the ground and none below -1.
- **A2 attachment**: a leg's or head's joint touches its body (or is within 1 unit of it) and isn't
  buried more than 4 deep (`legs.stance.bury`); at least half of a leg (`legs.stance.inside`) or head
  is outside its body (a leg under a skirt shows 3 units below the hem); a held item's grip within
  1 unit of the hand; head gear on the head, leaving every eye in sight (nothing within 3 units out
  along its look) and, on a head with a modelled brow, an open cap's lowest edge over the eyes at
  least 0.5 above the brow (face guards say `"face": "covered"`); back gear touching the back; worn
  armour at most 25% more than 1.5 units off its body, its middle within 1.5 of the middle of the
  body inside it; a rider's seat within 1.5 of its mount's back, at most 30% of the rider inside the
  mount; siege crews on the ground (or something to stand on just under a riding one), at most 12% of
  a crew member inside its engine (too big for the frame, it takes the `_wide` sockets beside it),
  a beast hauling it (a trade cart's pony on a `haul<n>` socket, the recipe's `haul`) on the ground
  (the rest of a composite: see Composites below);
  a body whose leg isn't the same on both sides bakes its legs at each hip; data anchors = model hips.
  **Head join** (four or more legs, the head ahead of the fore legs; Dominic on the bear mount, B2:
  "mounted bears I think have broken neck still"): the side silhouette's top line, body and head
  together, from a quarter of the way back from the fore hips to the head's middle, dips at most 1
  unit (`legs.stance.notch`) below the lower of its highest points either side (thin spikes, an
  ear's tip or a buckle, levelled first). A head set low on a thin neck with a step behind the skull,
  or floating off it, fails; a neck flowing from the withers into the skull passes. The fixture
  rebuilds B2's bear mount and must fail it.
- **A3 interpenetration**: pieces not jointed share at most 12 voxels + 3% of the smaller; jointed
  ones only within 4 units (or 45% of the child's reach) of the joint (armour against what hangs from
  the body, outside the body; a rider's held item against its mount; a blowgun at the lips); a leg or
  head comes out of its body in one piece (12 voxels + 3% of strays: a leg through the body and out
  of its back is two pieces).
- **A4 stance** (`legs.stance` in parts.json): a standing leg's drop (hip to foot) at least 60% of its
  reach (`drop`: not folded up), its foot out to its own side of its hip by `sprawl` (-2 to 6 units:
  a far leg's foot under the belly fails).

**2D** (`tests/placement/projection_check.gd`, needs the bakes): every unit composed by UnitView in
all 8 facings, standing and at three walk phases, each part's sprite laid onto a grid in the unit's
space in draw order. The layering rules below, every part drawn has its bake, and:

- **B5 ground**: standing, each weight-bearing leg's lowest pixel within 2 px of its foot's ground
  point (the 3D sole projected by the bake camera); a near leg (on the flank facing the camera and
  the camera's side of the middle) has its own foot in sight in the 3D truth. Walking, the lowest
  foot within 2 px of the standing ground line.
- **B6 visibility**: the 3D truth (the body's model, each hip its own leg part turned as baked, the
  head on its socket, in flat colours from the bake camera) matches the unit's legs one for one; legs
  and head show where it shows them (rule 2 below); a rider shows the leg on the flank facing the
  camera, and a person's reaches at least 80% of the way from the seat to the girth (a clinging or
  folded-legged rider's, `creatures.json rider_legs`, at least onto the flank).

**Composites** (2026-10-13, after TC1 A for rats passed every check while broken: Dominic, "this is
bugged, did the tests not catch it?"). A composite is more than one body drawn as one unit: an engine
with its crew (`crew`) and the beasts hauling it (`haul`), and a rider on its mount (the seat and
"rider over the mount" rules above). Until then an engine was checked as the engine, each crew member
only for how much of it sat inside the engine, standing: the members never against each other, never
walking, a hauler never as a unit, the traces and the cart's attachment not at all; and in 2D only
whether each member was over or under the engine. So the cat drew over the rat beside it in every
facing (its layer was its side's plus a little, over every crew member there), the traces ended in the
air by its chest and the cart floated behind. Now (`tests/placement/composite_3d.gd`, `composite_2d.gd`;
members composed as UnitView composes them, `UnitView.engine_sockets`, `crew_recipe`, `haul_recipe`):
- **C1 members apart** (3D, standing and at every walk step; crew riding on top don't walk): no member
  inside another beyond contact (12 voxels + 3% of the smaller); a hauler not inside its cart but within
  3 units of a hitch (where the harness meets the shafts); crew in their engine at most 12% (they grip it).
- **C2 hitched**: every `haul<n>` socket has `hitch<n>_near` and `hitch<n>_far` on the engine's solid (its
  shafts reach them); the hauler wears a harness (a torso part tagged `harness`) whose trace ends
  (`trace_near`, `trace_far` sockets) are on those hitches, within 1.5 units standing and 2.5 walking (the
  beast rides on its planted foot, the cart doesn't); the harness hugs the hauler (at most 10% of it more
  than 1.5 off its body, the trace tails behind the rump aside).
- **C3 no loose ends**: every rope of an engine (traces, lashings, guy ropes, drag lines: a rod whose
  material carries the `rope` meta, `siege_models.gd _style`) ends on something at both ends: the rest of
  the engine, a member, or the ground. (A pole's tip, an antenna or a goad may end in the air.)
- **C4 depth order** (2D, every facing standing): the whole composite rendered in 3D from the bake camera,
  a flat colour per member, says who is in front; where it shows a member, no other member's sprite is
  drawn over it (6 px or 8% slack). UnitView layers crew and haulers in one depth order. Known limit:
  crew inside a frame (`_in`) draw behind the whole engine sprite (rule 10), so its far posts cover them
  too; C4 leaves the engine against `_in` crew out (splitting an engine into near and far layers would fix it).
- **Members as units**: each member is checked with the unit rules (A1 to A4 in 3D; layering, B5, B6 in
  2D), standing and walking, under the composite's label. A beast in harness never sits (`"idle": 0`).
- **B6 walk steps** (every unit): walking, each hip's leg is drawn, in the walk step the 3D rig has for
  that phase, one for one.
- **No silent passes**: every sprite in a view belongs to the unit, a member the checks composed, or the
  engine ("every drawn part is checked"); a script error inside a check fails the run
  (`tests/placement/script_errors.gd`: it used to abort the check quietly and read as a pass); the sheet
  tool fails a row no rule ran on, in 3D or in 2D.

The concept composites are in `cases.gd` (`composite_cases`: TC1 A for every family and the covered wagon,
staged from `data/later/trade_carts.json`).

**Fixtures** (`tests/placement/fixtures_3d.gd`, `fixtures_2d.gd`): every placement bug Dominic caught,
put back (an old anchor, lean, model, rule or z), must fail its rule, and the unit as it is now must
pass it. A fixture that stops failing is a check gone blind: the run fails.

## Layering rules

Every composed unit obeys these; `tests/placement_check.gd` checks them on the drawn pixels, for every
body, every mount with and without riders, the animals and the siege crews, in all 8 facings,
standing and at three walk phases (see Checking art). Draw order is child order by the `z` meta
(`_sort_layers`), never `z_index`. "Depth" is a socket's bake depth in that facing (> 0: nearer the
camera than the body's middle); "near" is depth >= 0.5, "far" depth < -0.5.

1. **Shadow first**: the unit's shadow draws under every part.
2. **Legs and head show where the 3D model shows them.** The body's model with its legs at their
   hips and its head on its socket, rendered in flat colours from the same camera, is the truth: a
   leg or head never draws over the body where the model's body is in front of it, and the body
   never covers a leg or head the model shows (slack: 6 pixels or 8% of the part, for the outline
   and rounding). A plain leg sprite drawn over the body shows its whole top, so a body whose hips
   sit inside it bakes cut legs (above); likewise a head that goes behind the body.
3. **Far legs behind the body** (z -2), unless cut (then 0.5: over the body, under the near legs).
   Near legs over it (z 1), or under it where clothes hang over the hips (`legs_under`, z -1).
4. **The near arm** (a body's `front` layer) draws over the body and its worn armour (1.5), under
   the head; behind the body (-1) when the facing turns that side away. (Known limit, not checked:
   a raised arm can't pass in front of the face.)
5. **Worn armour holds no body**: baked on its body with the body cut out, it never covers more
   than 80% of the body's pixels (a whole copy is 100%).
6. **Back parts** (capes, quivers, banners, wings): behind the body when the back socket is far
   (the unit faces the camera), over it when near (it walks away). A mount's wings at its withers:
   over its back unless the withers are far (then the rump hides their roots), always under the rider. A wing blur (a hummingbird's own wings, parts.json `blur`) draws like any back part instead.
7. **What the hands hold**: in a near hand, over the body; in a near or middle hand, at least 3
   pixels show in every facing and pose (a weapon never vanishes). A far hand's shield may hide.
8. **Riders**: no mount part (body, legs, head, wings) draws over any rider part; the rider's near
   leg draws over the mount's flank.
9. **Team cloth never covers the face**: on a head facing the camera, at most 30% of its pixels
   under team-colour pixels of later parts (head gear aside).
10. **Siege crews by socket**: `_in` behind the engine, `_top` over it, the rest (crew and haulers
    beside it) over or under it by which is in front where they overlap on screen (the bake's `front`,
    `part_baker._members_front`: the engine's meshes sampled against a column up the member), else by
    the socket's depth sign; the members among themselves by depth, the nearest last.

**Siege engines** (milestone 13, D-119) are one baked part each, `siege.<engine>.<take>` (slot
`engine` in parts.json; models in `scenes/art_pixel/siege_models.gd`, which `unit_models.gd` hands
those ids to), baked in 8 facings like a body, in the race's colours (the timber take wears the
culture's cloth). The crew are not baked in: the recipe carries `crew` (the race's age-1 worker), and
`UnitView` composes one worker UnitView per crew socket of the facing (`crew<n>_f<k>[_reach|_raise][_in|_top]`:
turned k facings, the arm hold it keeps, behind the frame or riding on top). Crews walk while the
engine rolls, heave with a ram's blow, snap with a shot, and fall when it's destroyed. Check them with
`tests/siege_lineup.gd -- out.png [zoom] ["prompt" ...]` (every take, four facings, a worker for size;
`SIEGE_FACINGS=8` for all eight). The human (timber) ram is covered: a pitched roof of lashed hides on
corner posts, open at the sides so the crew show under the eaves (`TIMBER_RAM_ROOF`: "hides", "planks"
or "" for the open ram); its two "in" crew stand one each side of the log so one always shows.

**Haulers** (the recipe's `haul`: `{creature, skin, parts}`, from the engine part's `haul` in parts.json;
the trade cart since D-127): UnitView composes the bare creature on each `haul<n>_f<k>` socket
(`UnitView.haul_recipe`: its mount body, never sitting), in one depth order with the crew. It wears
`harness.draught` (`parts: {"torso": ...}`), which `siege_models.gd harness_fitted` builds on its body from
the body's model (a breast band, two back bands, a trace down each flank past the rump) and bakes like worn
armour; the cart's shafts end where the traces end (sockets `hitch<n>_near/_far` = the haul socket + the
harness's `trace_near/_far`). The placement check holds them together (C2 above). The trade cart
(`siege_models.gd trade_cart`): the take's beast pulls it (`CART_BEAST`, the same creature as the part's
`haul`: pony, cat, beetle, spider), the frogs' a small snail baked in with the cart (`_cart_snail`), a worker
leading at the beast's head. ArtKit asks for an engine's crew and haulers as units: probed before the
engine's bake, the engine has no sockets yet, so its members were never baked.

**Pushed home** (D-127): a worker whose creature has `push_home` (creatures.json: the rats, stone in the
scrap barrow, gold in the handcart) is drawn, while it carries that load home, as that engine with itself
as the crew (`town_life.gd tool_for` gives `push:<engine>`, `UnitView.push_recipe`); home, it is itself
again. View only: the sim's worker carries as before. The placement check has each as a composite
(`cases.gd composite_cases`); `tests/sheets/rat_push_home.json` shows them beside the old carry.

## Mods

A mod's parts (milestone 21, `docs/modding.md`) bake like the game's: its model script extends
`unit_models.gd` and is added to `UnitModels.extra`, or a part names a `.glb` in the mod
(`UnitModels.glb_file`, materials by name: `mod_materials`); its textures load by path
(`tex("res://mods/<id>/textures/<name>")`). The bake cache's version hashes every file of the mods in
use. Mod units are placement cases (`tests/placement/cases.gd` `mod_cases`, labels "mod <id>: ...")
when the mod is in use (`AOW_MODS=<id>`), and `tests/mod_check.gd -- <id>` runs the 3D half on them.
Head gear with `"face": "sealed"` (a closed helmet) is exempt from the eyes-in-sight rule.

## Buildings, props, terrain

- **Buildings** (`src/view/art/bake/models.gd`, baked by `src/view/art/bake/baker.gd` via
  `ArtKit._bake_building`): one builder per type dressed in each architecture's kit (walls,
  frame, roof, base: `KIT`; the timber towns stand on timber sills over packed earth, no stone plinths). Baked once per culture, plus four construction stages. Data
  shapes them further (`data/buildings.json`): `scale` per culture and type, `variants` (houses
  bake four looks, turned or mirrored and resized, each building picks one; the model declares
  its `door` (and `window`) direction and a variant only uses turns that keep the door on a wall
  the camera sees), and `age_looks` (a building's
  model from an age on, e.g. the rats' oil-drum town hall at age 3).
  Live parts (banner, vane, smoke, lights) are drawn over the bake.
  Walls and gates are one tile each. A gate's model returns its closed `body` and an `open`
  one, both baked; it also bakes a quarter turn (`^z`) for wall lines running along sim y, and
  the view picks the turn from its neighbours and shows it open while a friendly unit is at it.
  **Walls you stand on** (milestone 16): a walkway piece's walkway height is `Models.WALK_H` (model units;
  `ArtKit` gives it as `walk_px`, canvas px), and units up on it are lifted by it, so they stand on the stone.
  Its merlons are made with `Models.merlon`; the ones on the camera's side of the wall's line bake as a
  separate front layer (`ArtKit.front_split`; walls compose it per link set like the body), drawn by a node
  of its own beside the building in the y-sorted layer, `BuildingArt.FRONT_SORT_PX` below the piece; units on
  the piece sort between the two (`BuildingArt.perch_sort_y`), so defenders stand between the merlons. Wall
  arms meet a joined piece's faces (a wall tower fills its tile). Check joins with
  `tests/wall_join_check.gd` (below).
- **Props** (`scenes/art_pixel/prop_models.gd`): bushes, reeds, boulders, quarry stone and
  gold, carcasses, crops, the rally flag; resources bake in used-up stages.
- **Trees** (`scenes/art_pixel/tree_models.gd`, milestone 15): broadleaf, pine and swamp trees,
  each in a few concept looks (`style`; `ArtKit.TREE_STYLE` picks the one in play), built like
  the bushes (leaf and needle cards over dark lobes, bark-textured trunks), baked two to a
  render with room for long shadows (`baker.shadow_reach`), in four stages: standing, felled
  (the log by its stump), sawn up, stump. The sim has one `tree` terrain; the view picks the
  species from the ground round it (`src/view/art/land_view.gd`: swamp trees by water, pine and
  broadleaf groves by a smooth noise). Stumps stay until something is built there.
- **Bridges** (`scenes/art_pixel/bridge_models.gd`): neutral timber, no team colour; every size
  the maps use is baked (`ArtKit.bridge_sizes` reads `data/maps`), along sim x and y, standing
  and broken, one to a whole frame (`baker.bake_many` asserts every model fits its cell: a long
  bridge in a third of the frame lost its ends). Drawn in the flat layer (walked across, under units).
- **Terrain** (`scenes/art_pixel/terrain.gdshader`): one shader paints the ground from blurred
  terrain masks (water depth and sky, swamp, rock, paths); not baked. Rivers draw as water,
  fords as shallows with the bed showing, forest floor like reed-bed ground. Worn trails come
  from the sim's wear grid (`src/sim/trails.gd`), handed over as a small texture once a second
  (`land_view.gd`) and drawn as the culture paths' earth trail.
- **High ground** (milestone 15): a map's `heights` lift the ground by `Iso.LEVEL_PX` per level.
  `Iso.set_relief(map)` keeps four corner heights per cell (ramps slope from their foot to the
  level above); `Iso.lift(x, y)` is the lift at a sim point, `Iso.to_ground` the raised screen
  point, `Iso.pick` the sim point under the mouse (the highest ground drawn there wins).
  `TerrainView.build_relief` draws the raised ground as meshes: tops through the terrain shader
  again (UV.x tells it how far a vertex was lifted, so it paints that cell's ground; UV.y shades
  slopes), cliff faces down every edge that drops towards the camera (`scenes/art_pixel/cliff.gdshader`,
  three looks: earth bank, layered rock (in play, `CLIFF_STYLE`), mossy boulders; concept sheet
  `archive/images/2026-10-13/180`, `AOW_CLIFF_STYLE=n` in the environment picks one for a shot),
  and a dark line along back edges. Level by level under everything; and copies of the tops near a
  back edge go into the y-sorted layer, one per screen row, so a hill hides what stands behind it.
  **Everything in the y-sorted layer sorts on the base plane**: its node sits where the flat map
  puts it and its art is raised inside it (`UnitView.lift`, `BuildingArt` raises its parts, props
  raise their sprite, piles and flags their `offset`); overlays use `UnitView.ground()` and
  `Iso.to_ground`. The fog shader walks down the screen to the frontmost ground drawn at each
  pixel and takes that cell's fog. The minimap lightens each level and darkens cliffs.
- **UI art**: SVG icons and cursors in `assets/art/icons/` and `assets/art/cursors/`,
  rasterised at load.

## Blender

Installed with Homebrew (`/opt/homebrew/bin/blender`, Dominic's yes, 2026-10-11). Scripts build
models from code so they're reviewable and repeatable:

```sh
blender -b --python tools/blender/human_head.py -- assets/models/head_human.glb
blender -b --python tools/blender/human_torso.py -- assets/models/torso_human.glb
blender -b --python tools/blender/human_leg.py -- assets/models/leg_human.glb
blender -b --python tools/blender/human_armour.py -- assets/models/ leather      # and bronze
```

Model in the game's part units, facing +X, up +Z (glTF export turns it into Godot's +X forward,
+Y up). Name every material for what the game should put there. Keep the primitive version as
a fallback when a `.glb` is missing.

## When the bakes run (and how long they take)

Every bake is a job in `ArtKit` (`src/view/art/art_kit.gd`): one unit part in all its facings,
one look of one building (with its stages and extra parts), nine props to a render.

- **On demand, never on frames.** A bake asks `BakeClock` (`src/view/art/bake/bake_clock.gd`)
  to render its viewport: the clock flushes the viewport's transforms and forces one draw of
  every viewport waiting, then wakes them. Waiting on the engine's frames stalled whenever macOS
  stopped drawing the window (hidden, covered, minimised). `tests/bake_hidden.gd` bakes with the
  window minimised.
- **Several at once.** Four part bakers and four building bakers share each draw.
- **On disk.** `BakeCache` (`src/view/art/bake_cache.gd`) keeps every bake in
  `user://bake_cache/<version>/`, the version a hash of the bake code, models, textures and art
  data: change any of them and everything bakes fresh. A race or culture seen before loads in
  milliseconds.
- **Only what's on screen first.** The lobby bakes just the few units a side's stage shows, at
  their first age (`ArtKit.bake_steps`), for the side that changed only; parts draw from their
  own textures until a match builds the atlas. Once every stage stands, the rest warms up behind
  anything asked for up front (`ArtKit.warm`, cancelled when a prompt changes): every age of every
  line, the portraits, the animals, props and buildings. The kit then goes to the match.
- **Portraits once.** `ArtKit` paints a portrait once per recipe and team; a side rerolled
  repaints only its own.
- **The tech tree page** bakes what it shows and isn't ready yet (`ArtKit.bake_tree`: every line's
  ages, their portraits, the culture's buildings) under its own loader (the forge veil and a bar).
- **The match loader** (`scenes/match_loader.gd`) shows `ArtKit.progress()`, the share of the
  asked-for jobs done, weighted by their renders. A job asked for twice runs once, so what the
  lobby warmed only loads (or is already there).
- **A modelled part is built once** and the camera goes round it for its eight facings; a cut part
  then renders its eight cut masks, and the cut is an engine blit (`PartBaker._keep_white`), not a
  pixel loop.

`tests/art_bake_time.gd -- cold|warm|off` times a match start (two races, all their buildings).
`tests/bake_profile.gd -- "prompt" [workers]` profiles a cold unit bake: time by kind of part, the
slowest jobs, the baker's phases. `tests/lobby_bake_time.gd` times the lobby (both stages, a
reroll, the tech tree, a match start) with no unit part loading from the cache.

## Checking art

**Run the placement check first** (needs a window; about 2 minutes cold, a little over 1 warm):
every placement and layering rule above and the fixtures, FAIL lines with their measurements, exit 1
on any failure. Unit, mount, gear and pose changes must pass it before they're shown.

```sh
godot --path . --audio-driver Dummy --always-on-top --script res://tests/placement_check.gd -- [filter] [3d|2d] [metrics] [debug] [nofixtures]
godot --headless --path . --script res://tests/geometry_check.gd -- [filter] [all] [time]     # the 3D half alone, headless (~35 s)
godot --path . --audio-driver Dummy --always-on-top --script res://tests/layer_check.gd -- [filter] [metrics]   # the 2D half alone
godot --path . --audio-driver Dummy --always-on-top --script res://tests/placement_shot.gd -- out.png 5 "frog on newt_fire" ["label" ...] [walk:2.1]   # look at a flagged case in 8 facings
```

Walls, gates and wall towers have their own check (a measurement, not a look): it bakes each fixture
(runs, corners, a T, diagonals, gatehouses, towers, units up top) once in 3D with an id colour per piece
and compares it with the game's own sprites laid out in the game's draw order; overlaps, gaps, joins that
don't meet and hidden, floating or sunk units fail with pixel counts (`debug`: truth | game | difference in
/tmp/wall_join_<n>.png; `legacy`: units as drawn before the 2026-10-13 fix, to see the fixtures catch it):

```sh
godot --path . --audio-driver Dummy --always-on-top --script res://tests/wall_join_check.gd -- [filter] [arch] [debug] [legacy]
godot --path . --audio-driver Dummy --always-on-top --script res://tests/sim_screenshot.gd -- out.png flat_test walljoins:5 "romans" "sewer rats"   # the same joins in the game
```

`metrics` prints the measurement behind each 2D failure (3D failures always carry theirs), `debug`
writes the 3D truth beside the composed unit for each standing view (/tmp/placement_*.png). A filter
matches case labels ("sewer rats", "on newt", "animal"); add a new body, mount or gear to a race in
`tests/placement/cases.gd` if none of the races there uses it.

Look at every change before showing it (Dominic catches floating parts, wrong layering and odd
shapes at once). Close up and at game size:

```sh
godot --path . --script res://tests/facing_sheet.gd -- out.png "prompt" [zoom]          # a roster in all 8 facings ("animals" too)
godot --path . --script res://tests/concept_sheet.gd -- out.png 14 1 "prompt" [az=215] "gear=..." ...   # one unit, close, options side by side
godot --path . --script res://tests/concept_sheet.gd -- out.png 4 2 "forest folk" unit=large "mount=concept.x;mounthead=concept.empty;mountback=concept.w;mountalpha=70"   # mount concepts under a rider
godot --path . --script res://tests/building_sheet.gd -- out.png 2 type:arch prop.quarry.1300.0 ...
godot --path . --script res://tests/building_sheet.gd -- out.png 2 stilt_house tree.1.pine.0 tree.1.swamp.1.3 bridge.1.3.0.1   # trees (seed.species.style[.stage]), bridges (seed.length.style[.broken])
godot --path . --script res://tests/building_variants.gd -- out.png 1.5   # every variant of every culture
godot --path . --script res://tests/sim_screenshot.gd -- out.png flat_test ai-look:x:y:zoom   # the map as played
```

**Check facings in the facing sheet, not the concept sheet.** The concept sheet's `az=` turns the
bake but keeps the classic view's layering, so from behind it draws the near arm across the back
(a false alarm Dominic caught). `facing_sheet.gd -- out.png "prompt" 8 <unit index>` shows one
unit's real 8 facings close up. Bodies whose clothes hang over the hips set `legs_under`.

**Legs that bend, and resting poses (C2, the cat).** A leg is normally one sprite swung about its hip.
A body can instead bake its legs posed: `legs.poses: n` bakes each leg as `"<leg>@w<i>_<n>"`, step i of
an n-step walk, and UnitView shows the step for where the leg is in its cycle (the anchor phases set the
footfall order); `legs.hind` gives the hind legs their own part (a hock), marked by `true` as a hip
anchor's last element; `legs.gait` overrides the walk's cadence, bob and rock. `idle_poses` (e.g.
`["sit1", "sit2", "sit"]`) are whole-body poses baked as `"<body>@<pose>"` with their own sockets and hips
(and the legs as `"<leg>@<pose>"`): the view steps down through them when the unit has stood still a few
seconds and back up when it moves (a rebuild, like turning). The model reads the pose from `hold`, also
for a cut part (`"leg.cat@w3_8~body.cat^1"`, `"head.cat~body.cat@sit^head"`: a cut head is cut by the body
in its pose). `UnitView.pose_parts()` lists the extra bakes; `art_kit` bakes them with the rest. The
placement check covers both: the walk at its baked steps, and each resting pose as standing
(`legs.stance.poses` may relax the stance in one: a sitting cat's folded hind legs drop less).

**The horse** (round H1, 2026-10-13; Dominic: "horses heads need a real re-work"): `UnitModels.pony_look`
picks the pony's look: `classic` (the head before: a round-ended rod of a face on a straight neck),
`h1` (a head built from shapes) or `h2` (in play: the head sculpted in Blender, `tools/blender/horse.py`
-> `assets/models/head_horse.glb`). h1 and h2 share the new neck (deep at the base, arched along
the crest, flat-sided, a mane from the poll into the withers, narrowing to the throat latch and
running into the head without a line), the small upright ears, the forelock and the bridle. The
centaur's horse half has no head, so it is unchanged. Sheet: `tests/sheets/horse_h1.json`
(`data/later/horses.json` stages each look under its own ids).

The cat is the rats' mount (D-124). Its body is `tools/blender/big_cat.py` `lean` (re-run it after a
change: `blender -b --python tools/blender/big_cat.py -- assets/models/body_cat_lean.glb body lean`);
its legs, tail, tack and poses are the cat section of `unit_models.gd`. Dominic thought the back end
too big, so the rump, haunch and thighs were made leaner, the hips narrower than the chest, and the top
of the rump only slightly higher than the withers. Sheets: `tests/cat_mount_sheet.gd -- out_dir [zoom]
[facings,walk,sit,sit1,sit2,cycle] [cat_ginger,cat_tuxedo,cat_grey]`.

## The creature kit

`scenes/art_pixel/creature_kit.gd` (2026-10-13; Dominic: "start the creature kit and concept sheet
tool, bear first") builds a creature from a parametric skeleton in data instead of a hand-built model:
- a **quadruped**: shoulder and hip joints on a spine, each fore leg shoulder blade, humerus, forearm
  and pastern, each hind leg femur, tibia and metatarsus;
- or a **biped**: hips, a torso leaning `lean` degrees about them, shoulders, elbows, hands, thighs,
  shins and feet.

Feet are plantigrade (the sole lies flat: bears) or digitigrade (the hock stands high: cats) by
their bones and the lowest bone's `tilt`. From the numbers it makes:
- the body: named torso volumes (chest, waist, rump, belly, pelvis, hump), markings, a neck, a tail
  (a chain, a stub, or tucked round when sitting), the tack, and a biped's arms. The near arm is in
  the front layer, posed for the hold by `unit_models.arm_pose`. A body can also be a modelled mesh
  over the same skeleton (`body.mesh`).
- every leg in every pose: standing, each step of the walk (`legs.poses`, two-bone IK from where the
  paw or foot goes, the knee forward and the elbow back), and the idle poses. A quadruped sits down
  in steps (the body pitched about its hips). A biped's idle moves only its feet, so worn armour
  baked on the standing body still fits.
- the head: skull, cheeks, the stop, muzzle and roman bridge, nose, eyes (named, for the placement
  check) under a modelled brow, round or pointed ears, whiskers, and a bridle for a mount. A head can
  also be a mesh.
- the sockets: head, seat and girth (from the top and bottom of the volumes under the seat), harness
  hands, torso, back and wings; a biped's hands; `torso_fit` for worn armour (from the chest);
  `gear_scale`.
- the part's data (`CreatureKit.complete`): sockets and anchors in 2D, cut legs (and a cut head on
  four legs), the posed walk, the gait, idle poses and stance. A kit part's data anchors are the
  model's hips by construction.
- a mount's own head: a kit can take its head from another kit (`head_of`) and change only what it
  names (the bear mount carries the biped's head pitched nose-down, low on a short neck).
- a neck that runs into the head (`neck.into`: a point in the head's frame, in the back of the
  skull; round B3): the neck is one thick mass from the withers into the skull wherever the head
  sits and however it's pitched (sitting too), and the bakes join head and neck without a line: the
  body is baked with its head in place held out of it, the cut head is cut by the body as before,
  and neither is outlined along the other within `seam_r` of the join (the body's `join` socket);
  each grows a pixel into the seam, since their bakes sit on slightly different pixel grids
  (`part_baker.gd`, `pixelize.gd`'s `seam`). Any hand-built body can do the same (`seam_head`,
  `seam_r`, a `join` socket): the capybara and the reworked pony do. A creature
  names it as `mount_head`, which UnitView and the placement rig use under a rider (falling back to
  `head`). A sitting pose can raise the head on its neck (`sit.poses.<pose>.head`).

Kits live in `data/creature_kit.json` (`kits`; `_params_doc` lists every parameter; a kit can
extend another with `base`, and a `null` removes a volume). A body part with `"kit": "<name>"` is
completed from its kit when a data file is staged (`CreatureKit.stage(lib, path)`), which also adds
the file's creatures, skins, words and concept model files (`models`). `unit_models.gd` builds any
kit part (`CreatureKit.has_part`) and any part from a staged model file (`UnitModels.extra`).
**Nothing in `data/parts.json` uses a kit yet:** only tests and sheets stage these files. To put a
kit creature in play, move its kit and parts into the game's data and have `DataLib` complete kit
parts on load.

**The cat through the kit** (`kitcat`, `kitcat_built`): `kitcat` is the cat's modelled body and head
on the kit's skeleton, legs, poses and sockets. Side by side with the game's cat, no difference shows in any facing,
walk step or sitting pose (`archive/images/2026-10-13/392`, `393`), so the skeleton reproduces the
hand-built cat. `kitcat_built` makes the body and head from the kit's primitives too. It reads as a
cat but is blockier than the modelled one, so the game's cat stays as it is. The kit's job is new
creatures (bears first: `data/later/bears.json`, `docs/concepts/bears/`). Kit creatures are in
`tests/placement/cases.gd` (`kit_cases`, labels "kit: ...") and pass both halves of the check.

## The sheet tool

`tests/sheet.gd` draws every concept and lineup sheet from a small spec (`tests/sheets/*.json`) and
replaces the per-round scripts. A spec gives:
- rows: a unit from a prompt, slot and age (with recipe overrides, a mount, a rider on the right);
  a bare creature or its mount body; a creature-kit creature with changed parameters; one part alone;
  or every prompt x slot (`each`, for lineups and siege engines)
- columns: 8 facings; walk steps; a cycle; idle poses; holds
- size references, zooms and labels

It bakes through ArtKit and the bake cache, lays out a labelled sheet per spec sheet and zoom, and
runs the placement checks (3D and 2D) on every unit it shows, a composite (an engine, its crew, the
beasts hauling it) as a whole with each member as a unit. It prints PASS/FAIL per row, frames a
failing row in red with the rules it broke, and exits 1 on a failure. A row no rule ran on (in 3D or
2D), or any script error inside the checks, fails: no silent passes (TC1 A passed while its beast,
handler and traces were never checked). A row can `expect` to fail
named rules (an earlier round beside its fix, failing the rule written for it): it passes when it
fails exactly those, and says so.

```sh
godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/bears_b1.json out_dir [sheet,...] [zoom,...] [nocheck]
```

Specs so far: `bears_b1` (round B1), `bears_b2` (round B2, with each B1 row rebuilt as a kit
variant: a prompt unit or a mount can name `kit` + `params`), `kit_cat` (the kit against the game's cat),
milestone 13's `trade_carts_tc1`, `war_beasts_wb1` and `_wb2`, `sapper_sp1`, `great_sling_gs1` and `_gs2`, the heroes' `heroes_hr2_*` (D-127: named champions; `tests/hero_names.gd` prints the names the naming contract in `data/later/heroes.json` gives a race) (concept files staged
from `data/later/`; a staged concept model file must be listed in `bake_cache.gd` SOURCES, or a stale
bake of it is reused; concept hand parts carry `only_if: ["concept_only"]` so the generator never
picks them for a staged race), `trade_carts_play` and `rat_push_home` (D-127 in play; a unit ref may
name `push`: the unit pushing that engine, `UnitView.push_recipe`), and ports of
`cat_mount_sheet.gd` (`cat_mount`), `siege_lineup.gd` (`siege_lineup`) and `line_lineup.gd`
(`line_lineup`). **New art rounds write a spec, not a script.** Once their rounds are closed, the
sheet tool covers what these one-off scripts drew, and they can go: `anim_concept_sheet.gd`,
`anim_concept_sheet2.gd`, `capybara_sheet.gd`, `cat_mount_sheet.gd`, `newt_cavalry_sheet.gd`,
`rat_mount_sheet.gd`, `siege_concept_sheet.gd` and its `_r2`, `_r3`, `_r4`, `sword3_concept_sheet.gd`,
`line_lineup.gd`, `siege_lineup.gd`, `unit_lineup.gd`, `healer_lineup.gd` and `facing_sheet.gd`
(a `facings` sheet).

These stay, because they draw what the tool doesn't:
- `concept_sheet.gd`: gear swapped by socket on one unit, `az=`
- `town_concept_sheet.gd`, `building_sheet.gd`: buildings and props
- `ui_sheet.gd`, `cursor_sheet.gd`: UI
- `anim_fight_sheet.gd`: attack and death frames in time
