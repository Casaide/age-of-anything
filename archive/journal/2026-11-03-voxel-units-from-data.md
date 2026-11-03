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
