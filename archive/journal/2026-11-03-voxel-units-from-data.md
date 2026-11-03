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
