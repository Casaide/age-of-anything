# 2026-10-30 to 10-31: the war elephant and the centaur sculpted (rounds BA1 to BA3)

Dominic, on centaur romans' war elephant in play: "quality here is bad, they are clearly a bunch of spheres put
together ... we need to improve".

## What happened

- **BA1** (2026-10-30): the elephant and the centaur's horse half rebuilt as Blender scripts that output
  .glb files, in place of the joined spheres. `tools/blender/sculpt.py` holds the shared helpers: a loft (a sphere
  stretched between top, bottom and width curves, then pushed out with bumps for the muscles) and a limb (a smooth
  tube with rounded ends). `elephant.py` has two looks, A (eastern) and B (bush), each with a barrel body, a head with
  a trunk, tusks and ears, and legs in pieces the game turns about their joints. Dominic: "the elephant looks better
  mostly, weird ears. But the centaurs looks mad".
- **BA2**: the ears were rebuilt as curved flaps hanging from behind the temple. They are placed by ray-casting the
  built skull and neck, so they sit on the head instead of floating. The centaur was redone as looks C, D and E,
  with horse proportions and the man standing up out of the breast. Dominic: centaur "terrible"; elephant "a little
  better but just lots of overlapping bits, looks buggy".
- **BA3** (2026-10-31):
  - **Centaur.** Dominic: "the whole body shape is the issue, look more like a banana with the human part perched
    on top". The BA2 top line rose at both ends over a sagging back, and the man sat on a hump in the middle.
    `centaur.py` (BA2 kept as `centaur_ba2.py`) now gives looks F (pony size) and G (1.15x). Their back is level,
    the body is short, the thighs reach down, and a deep upright chest rises into the man's waist. Then "weird
    pointy bit at the back": the rump's end narrowed to a point under the tail, now rounded.
  - **Elephant.** The overlapping bits were mostly outlines. Each leg and the head is baked as its own sprite, and
    each got a dark edge where it met the body. A body can now ask for its legs to join without a line
    (`seam_legs` in `src/view/part_bake.lobster`, as `seam_head` already did for heads). The sculpted elephants use
    it for their legs and head, and the centaurs F and G for their legs. The toenails were bright dots; they are a
    dull grey now.

## Funny bug

- **The stale elephant.** Mid-round the elephant came out dark grey, which looked like the new baker or my seams.
  It was neither: the bake cache's key is the bake version, the part's id and its colours, not the model file. So an
  old bake of `body_elephant_a` was served after the .glb had changed. Concept rounds now bake into a fresh cache
  (`sheet.sh ... cache:<dir>`), and adopting a look raises `BAKE_VERSION`. Picture 07.

## Decisions

- None yet. Dominic picks centaur F or G and elephant A or B. All of it is staged in `data/later/beast_anatomy.json`;
  nothing in play has changed.

## Pictures

- `archive/images/2026-10-30/07-elephant-and-centaur-before.png`: before
- `archive/images/2026-10-30/08` to `10`: round BA1 (options, close-up, walk)
- `archive/images/2026-10-30/12` to `14`: round BA2 (close-up, walk, options)
- `archive/images/2026-10-31/07-elephant-dark-from-a-stale-bake.png`: the stale bake
- `archive/images/2026-10-31/08-beast-anatomy-ba3-close.png`, `09-beast-anatomy-ba3-walk.png`: round BA3
- `archive/images/2026-10-31/10-centaur-f-rump-rounded.png`: the rump after the fix

## Ideas parked

- The hind gaskin could slope back to the hock, as a real horse's does (today's `hoof_joints` hang it straight).
- The bake cache could hash the .glb files a part loads, so a rebuilt model never bakes stale.
