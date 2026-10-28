# How the art is made (rendering pipeline)

Everything you see in a match is a 3D model baked to a pixel sprite, packed into one atlas and drawn as 2D
sprites. The game is written in Lobster (`src/`, run from there); the models, the bakers, the composer and the
checks are all Lobster, and the bakes are kept on disk after the first one (see "When the bakes run"). Since D-173
the art scale is 3.0 art pixels per canvas unit (`ART_SCALE` in `src/view/art.lobster`; a tile is 192 x 96 art
pixels, and at play zoom an art pixel is a screen pixel). The world keeps the coordinates it had (`ART_BASE` 1.5: a
tile is 96 x 48), so a sprite baked at `ART_SCALE` is drawn at 1 / `ART_K` of its texture's size and everything
shows at the size it always did. The sim never sees any of it. This page is the map; the code says the details.

## Units

1. **Models.** Each part (a body, head, leg, helmet, weapon, shield, armour...) is a 3D model:
   - Most are built in code from primitives (`blob`, `rod`, `slab`, `dome`, `ring`, `cone`, `box`, `surf`, `plain`,
     `glow` in `src/model/base.lobster`, on the node tree of `src/model/kit.lobster`). The builders are in
     `src/model/units.lobster` to `units5.lobster` (`body_rat`, `helm_spoon`...: the function is the part id with
     dots as underscores). `build_model` in `src/model/models.lobster` finds the builder for a part id. Siege
     engines and beasts are in `siege.lobster`, trade carts in `carts.lobster`, heroes in `heroes.lobster`, the
     bears' helmets in `bears.lobster`, the creature kit in `kit_bodies.lobster`.
   - Some are **modelled in Blender by script**: `tools/blender/*.py` (run headless, see below)
     export `.glb` files to `assets/models/`, which `glb(name, materials)` (`src/model/glb.lobster`) loads at
     bake time. Their materials are named (`skin`, `hair`, `team`, `cloth`...) and swapped for
     ours, so skin palettes and team colours still work. The human is the heroic build (D-173: about 5.5 heads,
     hips at 18 on long legs, a head 0.68 the old size; the scripts with "heroic" write `*_heroic.glb`, and
     without it the build before, kept). Today: the human head, torso and leg, and
     body armour fitted to the human torso (`armour_<kind>_<body>.glb`: `fitted` in `src/view/part_bake.lobster`
     hands it to the worn-armour bake, which then skips `torso_fit`).
   - A model returns its node plus, for bodies, `sockets` (3D points where the head, hands,
     torso armour, back and seat go), leg `anchors`, and fitting data: `torso_scale` (2D,
     legacy), `torso_fit` (3D scale for worn armour), `torso_tilt`, `gear_scale` (on heads). A body may add a `banner` socket: back parts tagged `banner` (the team banner) go there instead of `back` (the rat's low back carried its flag through its helmet).
   - Concept options are staged data (`data/later/*.json`, brought in by `src/view/stage.lobster`) and are drawn with
     the sheet tool (below); nothing staged is in play until picked.
   - **Holds.** A body is baked with its near arm posed for what it holds (`arm_pose` in
     `src/model/units.lobster`: `body.frog@throw`, `@draw`, `@aim`...). Workers are also baked in the work holds
     `@raise` and `@reach` (D-105): `set_hold` in `src/view/unit_view.lobster` swaps the body's bake through the
     work cycle and moves the tool to the new hand; soldiers swing their weapons through the same holds in a lunge
     (D-106), and the view plays each death by body shape (`die`). The sheet tool draws the poses and the attack and
     death frames (its `strike`, `fall` and `loose` columns).
2. **Bake** (`src/view/part_bake.lobster` bakes a part in 8 facings; `src/view/baker.lobster` is the rasteriser):
   each part is rendered by an orthographic
   camera from above (elevation 30) at **8 facings**, 45 degrees apart (azimuth 35 + 45k; D-087),
   lit by one warm key light from the viewer's upper left and a cool fill, with a shadow map for
   self-shadowing and ambient occlusion over the depth, at 4x supersampling (`BAKE_SS`). Each facing's bake keeps its sockets projected to 2D, how near each
   socket is to the camera (for draw order) and which way the model faces on screen. A modelled part is built
   once and the camera goes round it for its eight facings.
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
     (`leg_basis` in `part_bake.lobster`, `siege_leg_basis` for engines: legs are modelled for the near side pointing forward; a far hip's leg is
     mirrored across the body, a flipped rear hip's fore and aft, and an anchor's 6th value fans it out,
     a spider's legs). Today: newt, pony (and the centaur's horse half), capybara, frog, boar, sheep,
     rat, spider, both beetles (the mount's head too). A body's parts.json anchors are its model's hips
     one for one (they're what's drawn before the bake, and which legs get baked).
   - **War beasts** (2026-10-16) are engines that are creatures: `siege.beast.<kind>` in parts.json has
     `cut`, `legs` (its gait and stance too) and `beast` (`head`, `attack`, `fall`), and `src/model/siege.lobster`
     builds the body alone in play, the legs (`leg.beast_<kind>`, one per hip, jointed and baked in 8 walk
     steps like the cat's: `beast_step` moves the foot, `ik3` bends the knee, both in `siege.lobster`; the tarantula's and
     mantis's one straight-out leg fanned by the anchor) and the head (`head.beast_<kind>`, from its
     neck) apart; `build_model` hands those ids to `siege.lobster`. The composer composes it as a creature
     under its riders (`build_engine`), walks it on its planted foot and plays the kind's blow and fall
     (`beast`); its head is ordered among the riders by depth. The placement check walks the beast
     on its own (`beast_recipe`) as well as checking it with its riders.
3. **Pixelize** (`pixelize` in `src/view/baker.lobster`): down to art pixels with a bicubic shrink (the old engine's, kept so
   the bakes match), hard alpha, value posterised into painted bands (the paint-over look) and a dark outline.
4. **Team colour**: parts bake in a magenta team key; the team-mask shader swaps it for the
   unit's team colour when the sprite is drawn.
5. **Compose** (`src/view/unit_view.lobster`; the frames are drawn by `src/game/pack.lobster`): a unit is its parts as sprites placed on the body's
   sockets for its current facing, layered by depth (a cape draws over the body walking away, a
   far shield under it), animated in 2D (walk cycles, hops, work blows, attacks). A unit picks
   the facing that best fits its movement on screen, with hysteresis, and rebuilds when it
   changes. The bake's alpha is hard, so see-through is the view's job: a part with `blur`
   in parts.json (a hummingbird's wings) is drawn at that opacity over the body and flickers.
   Walking, the body rides on its lowest foot (`planted`, from the leg sprites' soles: no
   foot through the ground, none floating mid-stride). A rider's hips (its body's `sit` socket, else
   the middle of its hips) go on its mount's `seat`; it shows the leg on the flank facing the camera
   (the bake's anchors carry which side faces it), stretched down to the mount's `girth` (the baker
   finds it under the seat) unless it rides folded (`creatures.json rider_legs`).
   A hopper (`creatures.json gait: "hop"`, the frogs) hops by the ground its node covers (one hop per
   `HOP_LENGTH` of ground, so at the sim's speed whatever it is): it crouches, pushes off with its
   legs flung back, tucks, reaches for the ground and squashes on landing, its legs bending by squashing
   (each foot rising by the same amount, the body riding down on them) and swinging only in the air. It is
   drawn ahead of or behind its node (`hop_off`) so it stays planted on the ground while the node moves on
   and covers the ground in the air; over a hop that averages out on the node (selection and bars stay
   put). Turns and stops are made up in the air; stopped, it finishes its hop and lands on its node.
   The sheet tool's `walk` and `cycle` columns draw it frame by frame. Riders don't hop (their mount walks).
6. **Sized bakes** (D-180). A unit drawn at a scale other than 100 (sheep 135, boar 115, giants 150, tiny races 80)
   used to be a sprite baked at 100 and stretched. Now each part bakes at its unit's size: the bake key carries it
   as `%<size>` (`key_size`; `bake_model_part_at(id, full, colours, size)` in `part_bake.lobster`) and the
   drawing side looks the frame up by that key (`src/view/art.lobster`).


## Placement rules

**No unit, mount, gear or pose change is shown until the placement check (`src/placement_check.lobster`) passes** (Dominic,
2026-10-13, after the newt's legs folded up facing left passed the layering check). It measures,
it doesn't look; every unit of eight races at every age of its line, every rider on every mount,
winged mounts, every newt skin, the animals and the siege crews (`src/placement/cases.lobster`).
Every shield, cape, banner, quiver and healer's bag goes on every playable body too (`gear_cases`), and the Norse
kit on every body (`norse_cases`). Where off-hand gear can't sit right, the body's data says so: `"shield":
"slung"` / `"slung_flat"` carries a shield on the back from the model's `sling` socket (frogs, rearing beetles,
spiders; baked `<shield>@slung`, D-152), and a part's `not_worn_by` keeps it off a body it doesn't fit.

**3D** (`src/placement/geometry.lobster`, also run by `src/run_tests.lobster -- placement`): each unit is put
together from its models as the composer composes it (`src/view/rig3d.lobster`: legs at their hips
turned by `leg_basis`, head on its socket, gear on its sockets, worn armour fitted as the bake fits
it, a rider's hips on its mount's seat) in every pose the game draws: standing, the swings it goes
through (a worker's tool wound up and landing, a melee blow, a spear's thrust levelled and driven
forward; ranged units only loose), and the walk at 8 phases. Meshes are read in world space and
voxelized on a 0.5-unit grid (`src/view/geom.lobster`: primitives filled exactly, modelled meshes
by ray parity; decals left out). One part unit is 2.55 art pixels at game size (1.275 before D-173).

- **A1 ground**: standing, every foot within 1 unit of the ground; nothing below -1; the centre of
  mass within 3 units of the feet's support polygon (`legs.stance.support`). Walking (the body rides
  on its lowest foot, as the composer does), a foot within 1 unit of the ground and none below -1.
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
- **D1 a corpse lies on the ground** (a body with a `corpse` pose, see Deaths below): laid down, its body, every
  leg and its head reach within 3 units of the ground. The fixture props the frog up on its far hand
  (HF2b: its arms still braced as it stood) and must fail it.
- **D2 dropped gear on the ground, clear of the body**: each item it let go of within 1 unit of the ground,
  sharing no more than 12 voxels + 3% with the body.

**2D** (`src/placement/projection.lobster` and `case2d.lobster`, needs the bakes): every unit composed by the composer in
all 8 facings, standing, at three walk phases and (workers) foraging, each part's sprite laid onto a grid in the unit's
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

**At work** (2026-10-17, after Dominic saw a foraging centaur from behind in a match: "i thought our tooling and
tests protected against this needing visual checks"). The 2D check drew units standing and walking only, and the 3D
check has the work holds as baked bodies, so a pose the composer puts on the bakes in 2D was never drawn anywhere. The
centaur's kneel to forage (`kneel` in `unit_view.lobster`, D-105's C1) was designed side-on in facing 0: it folded the two legs
furthest right on screen and turned the whole sprite about the two furthest left, so in the other seven facings it
folded a flank's legs sideways, swung the shins forward and sank the hind end. Now every worker is also drawn
foraging in all 8 facings (`src/placement/case2d.lobster`): the layering rules hold there, and a fused mount's kneel
is measured against the model and the bake camera, not against the composer:
- **K1** the legs that fold are the body's fore legs (its model's hips ahead of the middle); **K2** a folded shin
  lies back along the ground (towards the model's tail on screen); **K3** it hangs from its knee; **K4** the hind
  hooves stay planted (each hind leg's lowest pixel where it stands); **K5** nothing goes below the standing ground line.
- A pose drawn on the bakes in 2D takes its fore, hind and forward from the facing: `ahead_on_screen(k)` (the
  model's +x on screen) and `side_on(k)` (1 side-on as in facing 0, 0 end-on) scale a turn of the whole sprite, so a
  worker's forage lean is forward in every facing, not sideways from behind.

**Composites** (2026-10-13, after TC1 A for rats passed every check while broken: Dominic, "this is
bugged, did the tests not catch it?"). A composite is more than one body drawn as one unit: an engine
with its crew (`crew`) and the beasts hauling it (`haul`), and a rider on its mount (the seat and
"rider over the mount" rules above). Until then an engine was checked as the engine, each crew member
only for how much of it sat inside the engine, standing: the members never against each other, never
walking, a hauler never as a unit, the traces and the cart's attachment not at all; and in 2D only
whether each member was over or under the engine. So the cat drew over the rat beside it in every
facing (its layer was its side's plus a little, over every crew member there), the traces ended in the
air by its chest and the cart floated behind. Now (`src/placement/composite.lobster`;
members composed as the composer composes them: `engine_sockets`, `crew_recipe`, `haul_recipe` in `unit_view.lobster`):
- **C1 members apart** (3D, standing and at every walk step; crew riding on top don't walk): no member
  inside another beyond contact (12 voxels + 3% of the smaller); a hauler not inside its cart but within
  3 units of a hitch (where the harness meets the shafts); crew in their engine at most 12% (they grip it).
- **C2 hitched**: every `haul<n>` socket has `hitch<n>_near` and `hitch<n>_far` on the engine's solid (its
  shafts reach them); the hauler wears a harness (a torso part tagged `harness`) whose trace ends
  (`trace_near`, `trace_far` sockets) are on those hitches, within 1.5 units standing and 2.5 walking (the
  beast rides on its planted foot, the cart doesn't); the harness hugs the hauler (at most 10% of it more
  than 1.5 off its body, the trace tails behind the rump aside).
- **C3 no loose ends**: every rope of an engine (traces, lashings, guy ropes, drag lines: a rod whose
  material carries the `rope` meta, the style helper in `siege.lobster`) ends on something at both ends: the rest of
  the engine, a member, or the ground. (A pole's tip, an antenna or a goad may end in the air.)
- **C4 depth order** (2D, every facing standing): the whole composite rendered in 3D from the bake camera,
  a flat colour per member, says who is in front; where it shows a member, no other member's sprite is
  drawn over it (6 px or 8% slack). The composer layers crew and haulers in one depth order. Known limit:
  crew inside a frame (`_in`) draw behind the whole engine sprite (rule 10), so its far posts cover them
  too; C4 leaves the engine against `_in` crew out (splitting an engine into near and far layers would fix it).
- **Members as units**: each member is checked with the unit rules (A1 to A4 in 3D; layering, B5, B6 in
  2D), standing and walking, under the composite's label. A beast in harness never sits (`"idle": 0`).
- **B6 walk steps** (every unit): walking, each hip's leg is drawn, in the walk step the 3D rig has for
  that phase, one for one.
- **No silent passes**: every sprite in a view belongs to the unit, a member the checks composed, or the
  engine ("every drawn part is checked"); a script error inside a check fails the run
  (a script error used to abort the check quietly and read as a pass); the sheet
  tool fails a row no rule ran on, in 3D or in 2D.

The concept composites are in `composite_cases` in `src/placement/cases.lobster` ( TC1 A for every family and the covered wagon,
staged from `data/later/trade_carts.json`).

**Fixtures** (`src/placement/fixtures3d.lobster`, `fixtures2d.lobster`): every placement bug Dominic caught,
put back (an old anchor, lean, model, rule or z), must fail its rule, and the unit as it is now must
pass it. A fixture that stops failing is a check gone blind: the run fails.

## Layering rules

Every composed unit obeys these; the placement check checks them on the drawn pixels, for every
body, every mount with and without riders, the animals and the siege crews, in all 8 facings,
standing and at three walk phases (see Checking art). Draw order is child order by the `z` meta
(`sort_layers`, `src/view/node.lobster`), never `z_index`. "Depth" is a socket's bake depth in that facing (> 0: nearer the
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
    `members_front` in `part_bake.lobster`: the engine's meshes sampled against a column up the member), else by
    the socket's depth sign; the members among themselves by depth, the nearest last.

**Siege engines** (milestone 13, D-119) are one baked part each, `siege.<engine>.<take>` (slot
`engine` in parts.json; models in `src/model/siege.lobster`, which `build_model` hands
those ids to), baked in 8 facings like a body, in the race's colours (the timber take wears the
culture's cloth). The crew are not baked in: the recipe carries `crew` (the race's age-1 worker), and
the composer composes one worker view per crew socket of the facing (`crew<n>_f<k>[_reach|_raise][_in|_top]`:
turned k facings, the arm hold it keeps, behind the frame or riding on top). Crews walk while the
engine rolls, heave with a ram's blow, snap with a shot, and fall when it's destroyed. Check them with
the `siege_lineup` sheet spec (`tests/sheets/siege_lineup.json`: every take, a worker for size). The human (timber) ram is covered: a pitched roof of lashed hides on
corner posts, open at the sides so the crew show under the eaves (`TIMBER_RAM_ROOF`: "hides", "planks"
or "" for the open ram); its two "in" crew stand one each side of the log so one always shows.

**Haulers** (the recipe's `haul`: `{creature, skin, parts}`, from the engine part's `haul` in parts.json;
the trade cart since D-127): the composer composes the bare creature on each `haul<n>_f<k>` socket
(`haul_recipe`: its mount body, never sitting), in one depth order with the crew. It wears
`harness.draught` (`parts: {"torso": ...}`), which `harness_fitted` in `siege.lobster` builds on its body from
the body's model (a breast band, two back bands, a trace down each flank past the rump) and bakes like worn
armour; the cart's shafts end where the traces end (sockets `hitch<n>_near/_far` = the haul socket + the
harness's `trace_near/_far`). The placement check holds them together (C2 above). The trade cart
(`trade_cart` in `siege.lobster`; the models are in `src/model/carts.lobster`): the take's beast pulls it (`CART_BEAST`, the same creature as the part's
`haul`: pony, cat, beetle, spider), the frogs' a small snail baked in with the cart (`_cart_snail`), a worker
leading at the beast's head. The art kit asks for an engine's crew and haulers as units: probed before the
engine's bake, the engine has no sockets yet, so its members were never baked.

**Pushed home** (D-127): a worker whose creature has `push_home` (creatures.json: the rats, stone in the
scrap barrow, gold in the handcart) is drawn, while it carries that load home, as that engine with itself
as the crew (`tool_for` in `src/game/town.lobster` gives `push:<engine>`, `push_recipe` in `unit_view.lobster`); home, it is itself
again. View only: the sim's worker carries as before. The placement check has each as a composite
(`composite_cases`); `tests/sheets/rat_push_home.json` shows them beside the old carry.

## Mods

A mod's parts (milestone 21, `docs/modding.md`) bake like the game's: the mod's model files (listed as `models` in
its `mod.json`) are Lobster. `src/mods_gen.lobster` copies them into `src/model/mods/` and writes
`src/model/mods_active.lobster`, which asks each mod's builder in turn (`play.sh` and `sheet.sh` run it first, since
Lobster resolves imports when it compiles). Or a part names a `.glb` in the mod (materials by name). Its textures
are PNGs made by `src/textures.sh`. The bake cache is emptied when `BAKE_VERSION` changes, so a changed mod model
needs a new cache (below). Mod units are placement cases when the mod is in use (`AOW_MODS=<id>`), and
`src/mod_check.sh <id>` loads the mod (or says why not) and runs the checks on its units.
Head gear with `"face": "sealed"` (a closed helmet) is exempt from the eyes-in-sight rule.

## Buildings, props, terrain

- **Buildings** (models in `src/model/buildings.lobster` and `buildings2.lobster`, materials in
  `build_mats.lobster`; baked by the world baker, `src/view/world_bake.lobster`, from `akb_bake_look` in
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
  on its cells. About +8 s on a cold match start. `tests/sheets/art_quality_a1.json` is the art study's sheet; a game
  capture shows a fall.
  Walls and gates are one tile each. A gate's model returns its closed `body` and an `open`
  one, both baked; it also bakes a quarter turn (`^z`) for wall lines running along sim y, and
  the view picks the turn from its neighbours and shows it open while a friendly unit is at it.
  **Walls you stand on** (milestone 16): a walkway piece's walkway height is `WALK_H` (`buildings2.lobster`; model units, given to the view as `walk_px`, canvas px), and units up on it are lifted by it, so they stand on the stone.
  Its merlons are made with `merlon`; the ones on the camera's side of the wall's line bake as a
  separate front layer (`akb_front_split`; walls compose it per link set like the body, `wall_look`), drawn by a node
  of its own beside the building in the y-sorted layer, a little below the piece; units on
  the piece sort between the two, so defenders stand between the merlons. Wall
  arms meet a joined piece's faces (a wall tower fills its tile). The Godot-era wall join check (each fixture baked once in 3D
  and compared with the composed sprites) has no Lobster port yet; look at joins in a game capture.
- **Props** (`src/model/props.lobster`, town ones in `town_props.lobster`; baked by `src/game/art_kit.lobster`): bushes, reeds, boulders, quarry stone and
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

## Blender

Installed with Homebrew (`/opt/homebrew/bin/blender`, Dominic's yes, 2026-10-11). Scripts build
models from code so they're reviewable and repeatable:

```sh
blender -b --python tools/blender/human_head.py -- assets/models/head_human.glb
blender -b --python tools/blender/human_torso.py -- assets/models/torso_human.glb
blender -b --python tools/blender/human_leg.py -- assets/models/leg_human.glb
blender -b --python tools/blender/human_armour.py -- assets/models/ leather      # and bronze
```

Model in the game's part units, facing +X, up +Z (glTF export turns it into +X forward,
+Y up, which `glb.lobster` reads). Name every material for what the game should put there. 

## When the bakes run (and how long they take)

Parts, buildings and props are baked by Lobster code (there is no engine viewport to wait on) and kept on disk.

- **One job per thing.** A unit part in all its facings (`bake_model_part`, `part_bake.lobster`), one look of one
  building with its stages and extra parts (`akb_bake_look`, `art_kit_buildings.lobster`), a prop with its stages
  (`ak_bake`, `art_kit.lobster`; `bake_doodads`).
- **On disk.** `src/bake_cache/` holds every bake with a record of its frame sizes, anchors, look and lights (parts:
  `cache_stem_of`; buildings `akb_stem`; props `ak_stem`). Each name hashes `BAKE_VERSION` (in `part_bake.lobster`)
  with the part. Change the models, the bakers or the art data, raise `BAKE_VERSION`, and `src/bake_cache.sh`
  (sourced by `play.sh` and `sheet.sh`) empties the folder when the number differs from the one it stored. A race or
  culture seen before loads in milliseconds; a match start with the cache warm bakes buildings in 0.13 s and props in
  0.4 s.
- **Only what's missing.** Before a match, `src/game/bake_missing.lobster` looks up every part each unit type wears
  and bakes what isn't there (a new race's colours, a mod's parts, a new part); the buildings and props of the
  cultures in play follow. The bake shows the match loader's bar and keeps the window alive (`bake_breath`,
  `bake_draw_backdrop`). The lobby bakes the few units a side's stage shows (`bake_view_parts` in
  `src/game/lobby.lobster`) and the match builds the rest.
- **A modelled part is built once** and the camera goes round it for its eight facings; a cut part
  then renders its eight cut masks.

`play.sh none` plays with no art pack at all: everything comes from the cache and the bakes.

## Checking art

**Run the placement check first** (needs a window; about 2 minutes cold, a little over 1 warm; run from `src/`):
every placement and layering rule above and the fixtures, FAIL lines with their measurements, exit 1
on any failure. Unit, mount, gear and pose changes must pass it before they're shown.

```sh
cd src
lobster placement_check.lobster -- [filter] [3d|2d] [all] [nofixtures|fixtures] [shard:i/n]
```

`3d` and `2d` run one half; `shard:i/n` runs every n-th case (the batch runs shards side by side); `fixtures` runs
only the regression fixtures. A filter matches case labels ("sewer rats", "on newt", "animal"); add a new body,
mount or gear to a race in `src/placement/cases.lobster` if none of the races there uses it.
`src/run_tests.lobster -- placement` runs the 3D half.

Walls, gates and wall towers had their own Godot check (a measurement against one 3D bake per join fixture); it
has no Lobster port yet.

Look at every change before showing it (Dominic catches floating parts, wrong layering and odd
shapes at once). Close up and at game size, with the sheet tool (below) or a game capture:

```sh
src/sheet.sh tests/sheets/<spec>.json /tmp/out [sheet,...] [zoom,...]     # units, creatures or parts in 8 facings, walking, resting
cd src && ./play.sh lobby "races:A|B" watch mute shot:/tmp/p.png at:5 look:<x>,<y>   # the game itself: a picture after 5 s, the camera on a tile
```

Models and buildings are also held by golden files: `src/golden.sh` compares every part's model (its walk steps,
worn armour) and every building in every architecture with recorded digests in `src/golden/`; a change that is
meant goes in with `src/golden.sh update`, and the diff is looked at before it is committed.

**Check facings with the sheet tool's `facings` columns**, which compose the unit as the game does in each
facing. (A sheet that only turned the bake kept one view's layering, so from behind it drew the near arm across the
back: a false alarm Dominic caught.) Bodies whose clothes hang over the hips set `legs_under`.

**Deaths laid down in 3D** (D-165, the frog; Dominic on turned and squashed sprites: "Just rotating or squishing
the image"). Most bodies fall in 2D (`die_pose` in `unit_view.lobster`: a biped topples, four legs fold). A body with a
`corpse` pose in parts.json is laid down in 3D instead (`src/view/corpse.lobster`): the whole unit put together
as the placement check does (`rig3d.lobster`), the body pitched and rolled about its middle, each leg turned at its
hip, body and legs swapped for their limp models (`"<body>@limp"`, `"<leg>@limp"`), the head dropped at the
neck, what it held (both hands, a banner) laid flat on the ground beside it. Its `frames` (percent of the
way down) bake in 8 facings, each turned on the ground by its `turn` so no facing sees it end on from behind
(D-166: views may differ by side), the last with its own shadow (the posed body pressed onto the ground, so it
lies in it rather than over the standing unit's ellipse). The part bake makes them with the race
(one job per recipe, then the bake cache); the composer gives one last
short hop and swaps to the frames on the way down (`corpse_pose_of` reads the pose). The sheet tool's `corpse` and
`corpse_fall:<k>` columns draw a pose (a unit ref's `concept.corpse` tries another). Not for riders, engines or flyers.

**Legs that bend, and resting poses (C2, the cat).** A leg is normally one sprite swung about its hip.
A body can instead bake its legs posed: `legs.poses: n` bakes each leg as `"<leg>@w<i>_<n>"`, step i of
an n-step walk, and the composer shows the step for where the leg is in its cycle (the anchor phases set the
footfall order); `legs.hind` gives the hind legs their own part (a hock), marked by `true` as a hip
anchor's last element; `legs.gait` overrides the walk's cadence, bob and rock. `idle_poses` (e.g.
`["sit1", "sit2", "sit"]`) are whole-body poses baked as `"<body>@<pose>"` with their own sockets and hips
(and the legs as `"<leg>@<pose>"`): the view steps down through them when the unit has stood still a few
seconds and back up when it moves (a rebuild, like turning). The model reads the pose from `hold`, also
for a cut part (`"leg.cat@w3_8~body.cat^1"`, `"head.cat~body.cat@sit^head"`: a cut head is cut by the body
in its pose). `pose_parts` lists the extra bakes; the part bake makes them with the rest. The
placement check covers both: the walk at its baked steps, and each resting pose as standing
(`legs.stance.poses` may relax the stance in one: a sitting cat's folded hind legs drop less).

**The horse** (round H1, 2026-10-13; Dominic: "horses heads need a real re-work"): `pony_look` (`src/model/units2.lobster`)
picks the pony's look: `classic` (the head before: a round-ended rod of a face on a straight neck),
`h1` (a head built from shapes) or `h2` (in play: the head sculpted in Blender, `tools/blender/horse.py`
-> `assets/models/head_horse.glb`). h1 and h2 share the new neck (deep at the base, arched along
the crest, flat-sided, a mane from the poll into the withers, narrowing to the throat latch and
running into the head without a line), the small upright ears, the forelock and the bridle. The
centaur's horse half has no head, so it is unchanged. Sheet: `tests/sheets/horse_h1.json`
(`data/later/horses.json` stages each look under its own ids).

The cat is the rats' mount (D-124). Its body is `tools/blender/big_cat.py` `lean` (re-run it after a
change: `blender -b --python tools/blender/big_cat.py -- assets/models/body_cat_lean.glb body lean`);
its legs, tail, tack and poses are the cat section of `units3.lobster`. Dominic thought the back end
too big, so the rump, haunch and thighs were made leaner, the hips narrower than the chest, and the top
of the rump only slightly higher than the withers. Sheet: `tests/sheets/cat_mount.json`.

## The creature kit

`src/model/kit_bodies.lobster` (2026-10-13; Dominic: "start the creature kit and concept sheet
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
- the part's data (the kit's completing step): sockets and anchors in 2D, cut legs (and a cut head on
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
  (`part_bake.lobster`, `pixelize`'s `seam` in `baker.lobster`). Any hand-built body can do the same (`seam_head`,
  `seam_r`, a `join` socket): the capybara and the reworked pony do. A creature
  names it as `mount_head`, which the composer and the placement rig use under a rider (falling back to
  `head`). A sitting pose can raise the head on its neck (`sit.poses.<pose>.head`).

Kits live in `data/creature_kit.json` (`kits`; `_params_doc` lists every parameter; a kit can
extend another with `base`, and a `null` removes a volume). A body part with `"kit": "<name>"` is
completed from its kit: in `data/parts.json` when the data loads (`src/gen/datalib.lobster`; the bears, in play since
2026-10-17, which also makes their head and leg parts), and
in a staged data file by `src/view/stage.lobster` (tests and sheets: `data/later/*.json`), which
also adds the file's creatures, skins, words and concept model files. `build_model` builds any kit part, the bears'
helmets (`bears.lobster`, "helm.bear_*") and any part from a staged model file.

What a broad body needed in play (the bears, 2026-10-17; each a kit `sockets` entry or a part field):
- `top` on the skull: a cap or hat must touch the head (a decal hat has no volume, so its socket must be
  within a unit of it); the bears' own helmets are lifted by the same drop (`TOP_DROP` in `bears.lobster`).
- a socket named for a part (`"cape.cloth"`, `"hero.lion_pelt"`): where that piece hangs clear of a broad
  back, ahead of `drape` (a hero's cape or pelt) and `back` (`attach` in the composer, the rig the same);
  `banner` higher and further back, so a tall helmet clears the banner's crossbar.
- `not_worn_by` on stock helmets whose rim covers a bear's eyes (the Attic; the bronze on the black and
  polar bears), and `not_ridden_on` on the cloth cape for the bear mount.
- `"crew": "wide"` on the body: too big for an engine's frame, it works it from beside it (the `_wide`
  sockets), as a centaur does; the generator puts `wide` on its crew (`engine_sockets`).
- `ridden_idle_poses` on a mount body: under a rider the bear only half sits (sitting up, its raised head
  met a lance and a frog's head; `idle_poses_of`).
- a body that rests in poses while holding its weapon its own way bakes both, `"<body>@<hold>@<pose>"`
  (`pose_parts`; `rest_pose` in `units.lobster`): a bear archer at ease keeps its bow drawn.

**The cat through the kit** (`kitcat`, `kitcat_built`): `kitcat` is the cat's modelled body and head
on the kit's skeleton, legs, poses and sockets. Side by side with the game's cat, no difference shows in any facing,
walk step or sitting pose (`archive/images/2026-10-13/392`, `393`), so the skeleton reproduces the
hand-built cat. `kitcat_built` makes the body and head from the kit's primitives too. It reads as a
cat but is blockier than the modelled one, so the game's cat stays as it is. The kit's job is new
creatures (bears first: in play since 2026-10-17, `docs/concepts/bears/`). Kit creatures are in
`src/placement/cases.lobster` (`kit_cases`, labels "kit: ..."; the bears' generated races in `PROMPTS` and
every helmet, armour and held piece on each bear body in `bear_cases`, labels "bear: ...") and pass both
halves of the check.

## The sheet tool

`src/sheet.lobster` (run by `src/sheet.sh`) draws every concept and lineup sheet from a small spec
(`tests/sheets/*.json`) and replaces the per-round scripts. A spec gives:
- rows: a unit from a prompt, slot and age (with recipe overrides, a mount, a rider on the right);
  a bare creature or its mount body; a creature-kit creature with changed parameters; one part alone;
  or every prompt x slot (`each`, for lineups and siege engines)
- columns: 8 facings; walk steps; a cycle; idle poses; holds; strike, fall, loose, corpse
- size references, zooms and labels
- optional `mods` to bring in for the run

It bakes through the part baker and the bake cache, lays out a labelled sheet per spec sheet and zoom, and
runs the placement checks (3D and 2D) on every unit it shows, a composite (an engine, its crew, the
beasts hauling it) as a whole with each member as a unit. It prints PASS/FAIL per row, frames a
failing row in red with the rules it broke, and exits 1 on a failure. A row no rule ran on (in 3D or
2D), or any script error inside the checks, fails: no silent passes (TC1 A passed while its beast,
handler and traces were never checked). A row can `expect` to fail
named rules (an earlier round beside its fix, failing the rule written for it): it passes when it
fails exactly those, and says so. What has no Lobster side yet is said ("not yet: ...") and left out.

```sh
src/sheet.sh tests/sheets/bears_b1.json /tmp/out [sheet,...|all] [zoom,...|all] [nocheck] [cache:<dir>]
```

It writes `<out>/<spec>_<sheet>_<zoom>x.png` (zoom 1 is the game's scale, 3 a close-up).

Specs in `tests/sheets/` include `bears_play`, `bears_b1` to `b3` (a prompt unit or a mount can name `kit` +
`params`), `kit_cat` (the kit against the game's cat), `cat_mount`, `horse_h1`, milestone 13's `trade_carts_tc1`,
`war_beasts_wb1`, `_wb2`, `sapper_sp1`, `great_sling_gs1`, `_gs2`, `_fs1`, the in-play `war_beasts_play`,
`great_sling_play`, `trade_carts_play`, `rat_push_home` (a unit ref may name `push`: the unit pushing that engine,
`push_recipe`), the heroes' `heroes_*` (D-127; the naming contract is in `data/heroes.json`), the walk and
fall studies (`human_walk`, `pony_walk`, `creature_walk`, `frog_fall_*`), and the lineups `siege_lineup`,
`line_lineup` and `norse_lineup`. Concept hand parts carry `only_if: ["concept_only"]` so the generator never
picks them for a staged race. **New art rounds write a spec, not a script.** Pictures of one thing in the game
itself (a building, a map, a fight) are game captures (`play.sh ... shot:`, above); the old one-off scripts for
concept sheets, building sheets, lineups and screenshots are gone, and with them the Godot-era building sheet and
variant sheet (a building's looks can be seen in a game capture).

## Siege shots (2026-10-13)

What engines throw is baked art, not drawn shapes (Dominic: "the rocks they throw look really bad"). An engine's body
part names its look (parts.json `shot`), `data/siege_shots.json` describes it: the sprite (`shot.<look>`, modelled by
`shot_model_spec` in `src/model/siege.lobster` and baked in 8 facings with the engine's other parts), its
spin (facings a second it tumbles through; 0 flies nose first, the facing nearest its
heading, pitched a little along the arc), its ground shadow and its impact (bounce, break, stick; chunks in its
colour). `src/game/fx.lobster` draws them (`shot_style`; a mod's looks come from its `shots.json`); until a look is
baked the flat shape shows.
