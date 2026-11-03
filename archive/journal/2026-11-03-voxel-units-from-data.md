# 2026-11-03: voxel units become the game's units, round 1: data, not code

## What happened
Dominic: "replace all units with voxels", and on how: "focus efficiency. need a clean simple pipeline, ideally
configurable so other people can make tweaks to them". The plan, in rounds: the data format and builder first, then
every creature, then baking and speed, then voxels as the default (the composed path kept behind an option).

Round 1 (Claude): everything about how a voxel unit looks moved out of `src/view/voxel.lobster` into `data/voxel/`:
- `materials.json`: colours and which are flecked like fur;
- `bodies/<creature>.json`: human, rat, frog, cat, pony. Named points that bob in the walk, pairs of two-bone legs
  (stride, lift, phase, where the knee bends), arms, where a helmet and armour sit, a seat, looks, and shapes;
- `gear.json`: holds (rest, wind-up, hit), held gear in a hold's own frame, worn gear fitted per body, and the rules
  mapping a recipe's parts to gear by id, tag or slot (they replace the name guesses in code).
The builder reads them: points, legs, arms, shapes with `if`/`unless` flags (a galea hides the ears, look 2 has a
beard, a seated rider has no tail). A mod's `data/voxel/` adds or replaces by id. The bake cache's key now includes
the data, so a change to a JSON file bakes again. Format in `docs/rendering.md` ("Voxel units") and
`docs/modding.md` (5b).

The sheet from data matches the hand-coded one (picture 01), but for the rider on a pony, who now sits on its back at
hip height (the old code lifted the rider by the pre-rebuild human's 20.5). A bug on the way: gear shapes melted into
the body like flesh (the old code made all gear hard), so a frog's spear shaft set the ground under it and the frog
floated; gear is hard by default now, and the feet check caught it.

## Pictures
- `archive/images/2026-11-03/01-voxel-units-from-data-sheet.png`, `02-voxel-units-from-data-battle.png`.

## Next
Every creature the generator fields (spider, beetle, capybara, newt, hummingbird, bears, centaur), wild animals,
heroes, siege crews, deaths; baking by age; voxels as the default; checks in voxel space.

## Round 2: every creature the generator fields
Voxel bodies are keyed by the recipe's body id now (a creature's race body and its mount body differ: a beetle rears
up as a soldier and stays flat when ridden, a bear stands as a race and goes on all fours as a mount), falling back to
its creature, then a human. New in data (Claude): bear (and the black and polar bears, as `also`), bear_mount,
capybara, newt (spotted, a long tail, sprawled legs), spider (eight legs, its abdomen with the team on top),
beetle_rear and beetle (six legs, a horn), hummingbird (it flies: `flies`, wings that `flap` as it moves), and the
centaur (the pony with its head and neck left off, `fused`, the rider's body growing out of it).
Builder features for them: a `harness` for creatures with no hands (spider, beetle: the weapon at their side, lowered
into a thrust in a blow), `flap` on points, a `fused` mount, a mount in its own palette (its skin, pale and mark drawn
as coat, mane and coat_mark), the palette's third colour as `mark` (a bear's muzzle, a newt's spots, a cat's white).
The feet check covers every creature (1512 frames; fliers skipped): bug leg tips needed small feet.
Pictures 03 (every creature, and every mount ridden), 04 (a spider worker in its town).
The first bake of a new race pair is too slow now (69 looks, 63 s for bears against centaurs): next round.

## Round 3: voxels by default (D-201)

Dominic asked (relayed) to carry on without stopping to voxels as the game's default: deaths, wild animals and
heroes, portraits, baking by age, the switch.

- **Baking by look and age.** A look is a line step's look (most steps share one). The start bakes its players'
  start-age looks standing and walking (and working) in their first look; the rest queue for play. Sewer rats against
  Romans, cold: 2.1 s (it was 42 s for all 52 looks); warm: 13-18 ms. The fill was split so it can run a slice a
  frame (6 ms). The first try hitched 80-180 ms whenever a job finished: Lobster's own PNG writer took 0.25 ms a row.
  The engine's `gl.save_texture` (stb) is a quarter of that, and jobs are now a mode each with the save in a frame of
  its own.
- **A bug:** the manifest counted its pose lines as cells, so frames pointed past the end ("index 5238 out of range").
- **Deaths:** the standing pose turned onto its right side about its middle, toppling slow then fast, lying in step 6;
  then the puff of dust and the fade the composed ones had. Picture 18.
- **Animals:** deer (antlers, white rump), boar (low, a ridge, tusks), sheep (fleece, dark face), from the pony's
  layout; in the feet check (1728 frames, none floating). Picture 19.
- **Heroes** are ordinary recipes, so they're voxel bodies already; hero gear without its own voxel gear falls to the
  tag rules (a pelt hood draws as a cap).
- **Portraits:** the panel's and the tech tree's are voxel frames (a texel 2 px), asked for first when not baked yet.
- **Still composed:** engines with a crew (siege, war beasts, the trade cart; picture 16 has both side by side), the
  stables' mounts, the lobby's pages.
- **Perf:** voxel units draw cheaper than composed (1.9 ms median against 2.4); a `perf:` run bakes everything first.
- The `follow` camera found no fight at 11:40 or 13:00, composed or voxel, so the pictures are the armies at the start
  (`army:6`, picture 16) and the town at 1:30 (picture 17).

Next: voxel siege engines and war beasts; workers' tools by job and their loads; the remaining gear (lance, sling,
hoplon, horned and other helms, bark, satchels, capes, banners); the lobby's pages in voxels; the voxel-space checks
(pieces connected, legs counted, nothing past the helmet).

## Round 3b: "Dwarf legs really weird" (Dominic)

There are no dwarves in the game ("dwarves" is an unknown word; the beetles volunteer), so the dwarves were the voxel
humans: 4.5 heads, often bearded, and short in the leg. Close up (picture 20, top) the hip was at 16 of 38 body
units and the kilt hid most of the thigh, so a leg showed as about a quarter of the figure. And every leg was
exactly as long as hip to foot: standing dead straight, with no room to reach a full stride, so the walk was a stiff
shuffle, the foot falling short of where it should land.

- **The builder** (all bodies): a body whose foot is out of its leg's reach is lowered until every foot is in reach,
  with a little bend left (the hips dip at full stride). A reach check over every body found six that stretched: human,
  bear, cat (front), pony (front), the rearing beetle (front), newt (front).
- **The human** (data): the hip up to 19 (legs about 2 heads), bones 8.4, thinner shins, the rider's seat to match.
  Picture 20 (bottom), and in a match, picture 21.
- **The other short legs** (picture 22): rat, frog, bear, cat and pony walk as they should; their short legs are
  their build (the rat's sit under its crouch, the frog's are folded).

## Round 3c: the deer's legs (Dominic: "Dear* not dwarf")

Dominic's "dwarf legs" was the deer. Round 3b's human legs stay (they were short too), but this was the real one. The
deer, boar and sheep came from the pony's layout, and so did its mistake: the front legs' middle joint pointed back
and the hind legs' forward, so the knees met under the belly, and the legs were far longer than hip to hoof (the
deer's 18 against 16), so they folded hard into an X. The deer's shins were near-black sticks too (picture 23, top).

- Legs about as long as hip to hoof (3% more, a little bend; round 3b's dip at full stride does the rest).
- The front's middle joint bends forward, the hock back, as a deer's, a horse's and a sheep's do. The pony had the
  same reversal (picture 25).
- The deer's legs in its coat down to a dark hoof, thick at the haunch, thin below.
- Pictures 23 (the deer walking), 24 (deer, boar and sheep standing, before and after), 25 (the pony).

## Experiment: voxel buildings (Dominic: "test a few buildings, see how close we can make them using voxels")

A test of how close voxels get, not a switch: the game's buildings stay baked. The Roman house and Town Center, the
rats' shack (their Town Center) and silo, a cypress, a broadleaf and a rock, as voxel bodies in
`data/voxel/buildings/` (written by `tools/voxel/buildings.py`: roof tiles and corrugated sheet are long rows of
shapes; the game doesn't load the folder), drawn by `src/voxel_buildings.lobster` with the units' builder. The
renderer took a cell size (`vx_cell_in`, `vx_ground_shadow_in`); nothing else changed.

- **Bake time** at the units' resolution (a voxel a baked pixel): house 0.29 s to fill and 24 ms a facing, Town Center
  0.94 s and 58 ms, shack 0.36 s, silo 0.22 s, the props 15-50 ms; all seven 2.0 s. Twice as fine: 11 s (Town Center 6 s).
- **Data:** 6-94 shapes each (1,100-1,900 lines of indented JSON for a building, 90-160 for a prop); the generator is
  200 lines of Python.
- **What reads:** the shapes, the roofs' tile and sheet rows, doors, windows, shutters, the chimney and stove pipe, the
  columns and steps, the team's band, the cypress; the light, shadows and outline match the voxel units.
- **What's lost:** the baked ones' surfaces: stone blocks on the plinth, worn and stained plaster, the roof tiles'
  rounded overlap, rust streaks on the sheet, lit windows' glow, the rocks' faceted faces (melted balls read as lumps),
  the clutter at the door (crates, barrels, firewood). Destruction stages and ruins weren't tried. Finer voxels
  (res 4) smooth the edges but add no texture: the detail would have to be modelled shape by shape.
- **Bugs on the way:** the Town Center's roof slabs with their sizes swapped stood up as two panels; a capsule core
  domed the silo's lid; a gap at the top of each gable.
- Not placed in a match: buildings draw through their own path (looks, stages, ruins), not a quick swap.
- Pictures 26 (Roman, baked / voxel / voxel twice as fine), 27 (rats), 28 (props), 29 (all in 8 facings).

### Round 2 of the building test: textures and lights (Dominic: "textures and lights real issue... what's lost i dont see a good reason for")

Dominic didn't accept the "what's lost" list as inherent, and he was right: each gap closed.

- **Texture in the colour**, as data: a material can have a `pattern` (materials.json), laid per voxel by its place on
  the shape, so the same in every facing and every bake (`vx_patterned`): `blocks` (stone courses, mortar, a bevel, a
  tone each), `planks` (boards, seams, grain), `ripples` (corrugated sheet with panel seams, rust in patches and
  streaks running down), `tiles` (rounded tiles in courses, each overlapping the one below, a little moss), `wear`
  (stained plaster, dirt splashed up from the ground), `mottle` (stone, bark, leaves). On a slope the tiles and ripples
  run downhill, whichever way it faces; on a round wall (the silo) they go round it.
- **Lights:** a `glow` material is drawn unshaded with a soft halo round it, on the wall and in the air (`vx_halo`).
- **Roofs** are flat sloped planes, the tiles and ripples in the pattern, not rows of tubes (Dominic: "why can roof be at
  an angle?": it can).
- **Clutter** at the doors: steps, a barrel, a crate, firewood, rocks, a sack, a stool, a brazier with its fire, amphorae.
- **Rocks** of flat cut faces (boxes at angles), not melted balls.
- **The silo:** a flat corrugated lid with a stone, two steel hoops, the dark door with a sheet panel leant beside it.
- **The facing:** each drawn as the baked one is (its front to the lower left; windows moved to the gable ends).
- Bake: all seven 2.2 s at the units' resolution (house 0.29 s fill + 43 ms a facing, Town Center 0.98 s + 115 ms),
  12.3 s twice as fine. Fewer shapes than round 1 (13-39 a building; 260-760 lines of JSON, 320 for the materials).
- Still apart: the baked roof tiles are deeper (each tile a shape, shadowed by the one above); the voxel rust is
  heavier; the baked Town Center's blue band and medallion read bolder. Pictures 30 (Rome), 31 (rats), 32 (props).

## Checks for the voxel art (Dominic: "voxels should make it easier... need more tooling and tests?")

Dominic, after a day of "bears too trunky", "the human looks unwell in every way: colour, legs bent, shape of the head",
"beetles look too much like spiders", then: "our art was really good, but with problems, now it looks cheaper, AND
with problems. Rat for some reason continues to be the best". He's right: the rat was the only body iterated round
after round with him; the rest were ported for coverage and fixed by eye, one complaint at a time (my first fix for
the white skin made it grey). He wants a skill and tools so an agent can do this well. Voxels stay the default
meanwhile (his call).

`src/voxel_check.lobster` (in the quick batch) puts numbers on what he caught, for every body a race can be:
- **knees:** standing, a leg bends no more than its body allows (12-15 degrees for a biped; a frog's folded legs are
  its build, so a body's own limits live in its file's `check`). It found the "legs bent": every standing frame had
  one foot lifted mid-step (idle shared the walk's phase 0). Now standing (idle, blows, work, falls) plants every
  foot, and a standing leg may be straight (the dip at full stride is for walking).
- **skin:** every palette of the creature in every look, as drawn: the lit band never clips white, the colour
  (saturation) kept. The white came from a light palette times the human's 1.3 lift; now only a dark palette is
  lifted, and a colour too bright is scaled whole (hue and saturation kept).
- **kit:** worn kit doesn't swell the silhouette, and enough of the creature still shows through it.
- **apart:** no two bodies' silhouettes alike, side on and three quarters on.
- **whole:** one piece (it found the rat's tail tip breaking into specks on the ground: thicker at the tip).

### Round 3 of the building test: the Roman roof's relief (Dominic: "gone from Roman style tiles to flat style tiles?")

Round 2's flat plane with painted tiles lost the Roman roof's relief: raised round rows running from ridge to eave
with deep channels between them, and a bumpy eave where they end. The rows are shapes again, lying on round 2's true
slope, over a dark plane (the channels catch the shadow); the painted pattern only varies each tile's tone and marks
its course. The Town Center gained its pediment's triangle (the gable's fill out to the roof's edge, with a raking
cornice and white finials), a round crest (a stone rim round the team's disc), and the team's band along the wall
below the eave's shadow line (from the camera's height the overhang hides the wall's top 6 units). A bug: the
gable's fill ran out to the eaves and hung under them like a soffit, hiding the wall's top. Picture 39.

## The composed units removed (D-202)

The engines and war beasts first: the ram, catapult, bolt thrower, siege tower, great sling and trade cart, each in
the five culture styles (as colours: frame, iron, cloth), with the race's own creature as crew on its spots; the
elephant, a war boar and a tarantula (the boar and the spider bigger, built on them with `base`, their hides renamed
with `remap` so they're not their crew's skin), the heron and the mantis, with howdahs and seats (pictures 36-38).
Bugs on the way: the engines' shapes first used the crew's colours (`pale`, `mark`); the cart's puller walked out of
the cell's bottom (more room below the ground point); the elephant's trunk tip floated a voxel over the ground (the
check read it as a foot); engines baked only after hundreds of other jobs (a frame drawn before its look is baked
now asks for it first); a style lookup read past the end of a beast's id.

Then the removal, in steps, a match and the lobby checked after each: the game's views, ghosts, packs and flipbooks;
combat's effects kept on their own (sparks, misses, heals, splashes, fallen buildings) and placed by the sim's
positions; town life without views; then the files, with a read-only survey first of what the buildings and props
still share (the depth and occlusion shaders, `pixelize`, the model kit, the bake settings, now
`view/bake_cache.lobster`). A small pass then took out every definition left that nothing used. Golden stayed the
same in every section (the buildings' digest too), less its models section.

## Milestone 24 begun: buildings and props as voxels (D-203)

The pediment first: its gable was two thick slabs tilted to the roof ("some weird angles", Dominic); now a vertical
triangle of level courses at the roof's slope, a level base cornice and raking cornices under the roof's edges
(picture 40). Then, as Dominic picked (C: the models voxelized for coverage, voxel data culture by culture after):

- `view/voxel_mesh.lobster` rasterizes a model's triangles into a shell of voxels (1.5 art px a voxel), each the
  colour its material gives there (its texture sampled, triplanar where it is; a lit material glows), drawn with the
  voxel units' light, shadow, occlusion and outline, in the old baker's frame exactly. So every look, construction and
  broken-up stage, near layer, wall arm, gate tower and prop bakes as voxels through the art kits unchanged.
- Speed: the light worked out only for the voxels that show, and the fill sampling at 0.7 a voxel with the last
  voxel remembered: a Town Center (720,000 voxels) 7 s -> 1.9 s, a house 0.33 s. The prebake (every architecture:
  1,868 frames) 23 min on the build machine, shipped as 104 MB; a warm start 5-6 s in all, the buildings 6 ms.
- `vbcheck` (a game option): every look of every architecture as voxels: no specks (none), and the model's team
  colour in sight. 16 looks keep theirs out of sight by the model's own doing (the same camera as the old bake): a
  house variant's shutters behind its cypress, the mills', the diagonal gates' bands facing away. Listed for the art
  review. (On the way: the first threshold took shaded magenta for no team at all; then walls, farms and palisades,
  which carry none by design.)
- Pictures 41-42 (Romans, frogs in a match), 43 (stone, junk and thatch buildings voxelized).

### Walls, gates, towers, and softer edges

A `place:fort` capture (and `place:palisade_fort`) lays a small fort by the Town Center: a straight run with a gate in
it, a turn, a diagonal run, towers at the corners. Joins, corners and gates hold (pictures 47-48); the stone diagonal
reads as a row of piers (left for the review). Dominic on the palisade: "a lot of hard vertexes/edges, a bit like
borderlands. I think we should soften". Three causes, three fixes: each voxel took its triangle's flat normal (every
facet of a low-poly stake a hard edge: now the model's smooth normals, blended with their neighbours'), the light was
five hard bands (now a smooth ramp), and an outline at 30% went round every gap between stakes (now 55%, half seen).
Pictures 45-46, before and after.

A diagonal wall run read as a row of square piers with deep notches between them (Dominic: "the genre's walls have
the same bug, some directions don't give you the smooth wall"): diagonal tiles only touch at their corners, and each
square post stood square to the grid, its corners out of the run's face. A tile joined only corner to corner now
draws its post turned 45 degrees (`:diag`, baked with the wall's look): the face is one plane (picture 49).

Then Dominic, close up: "all the wall models are clearly overlapping and sticking into each other. They MUST end
before next model". A wall tile was a post and an arm a neighbour, each its own sprite; on a diagonal run every tile
is at one depth on the screen, so the pieces overlapped in no fixed order, each with its own ends, plinth lip and
texture phase. Now a tile is baked whole: its post and the arms it has, one model, one picture ending at the tile's
edge (`akb_wall_tile`, made the first time those joins are drawn, one a frame, kept in the bake cache; the pieces draw
until then). A corner (a straight join and a diagonal one) has its post turned and shrunk inside its arms; a diagonal
run's end its post turned, full size. Pictures 62-64.

The open gate had been baked all along but never drawn since the port (a gate always stood shut, its team walking
through the doors). Now a finished gate shows its open look while one of its team's units is within a tile and a
half of it. `place:fort` with `army:` marches the army through the gate (pictures 65-66: the cart through it, the
army behind the walls, the near merlons over the catapult crew).

Then the gate in use (Dominic: "the units were floating all over the gate. On top parts, behind parts, totally
bugged... the unit is sitting behind the left side of the gate, why?"). Two bugs: the open gate drew as one picture at
one depth (a unit in its archway wholly in front or wholly behind), and its near towers' frames, which the art kit
bakes to stand in front of the archway, had the rest of the gate baked into them (the voxel bake ignored the old
baker's shadow-only meshes): the whole shut gate drawn over the units. Now the open gate sorts behind the archway, its
near towers and its arch in front, and a tower's frame is only its tower. `place:fort in_gate army:1` stands soldiers
through the arch (picture 67). A cold bake of two cultures: 2.6 minutes (it was 17).

Not yet (Dominic: "still this": a ram beside the gate's tower drawn behind it). One sort point for a whole tower was
right for a unit in the archway and wrong for one beside it. Now each tower is a frame of its own sorted at its own
footprint, and the gate's middle (its doors, or the passage and its arch) another, shut or open. On the way a
segfault: a diagonal gate's middle with its towers hidden had nothing left to draw, and the voxel fill made a grid of
negative size; an empty model now fills as an empty grid. Picture 68: the ram before the tower, soldiers beside
both towers and through the arch.

The palisade gate had the same overlap (Dominic: "same overlap"): its posts weren't parts of their own, so the stone
gate's fix never reached it. Each post with its prop and foot is now a part sorted at its footprint, the beam and banner
one at the gate's middle, and the beam stops at each post (golden: the six palisade gates, nothing else). Picture 70.
