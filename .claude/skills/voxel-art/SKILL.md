---
name: voxel-art
description: Make or change Age of Anything's voxel units, mounts, gear, engines, buildings or props (data/voxel/, view/voxel.lobster) as high-quality voxel art. Use for any new voxel body or gear, any fix to how one looks, and before showing Dominic a voxel picture. It starts from what makes the subject recognisable and how to show that cleanly at game size, then builds, checks and reviews.
---

# Voxel art

The voxel builder makes every unit, mount, engine, building and prop from data (`data/voxel/`: bodies, gear, holds,
materials; the format is in `docs/rendering.md`, "Voxel units"). The format is easy. The craft is making a 30 to 60
pixel figure that is instantly readable, clean and appealing.

The goal is high-quality voxel art in its own right. It's not a match for some other art style. The voxel rat is the
best so far, because it was worked round after round. "It looks cheaper, AND with problems" is the failure to avoid
(Dominic, 2026-11-03).

## 1. Know the subject before you model it

Before you write a shape, write down in the body's `_doc` what makes this thing *this* thing:
- **Silhouette:** the shape you'd know from its shadow alone.
- **Proportions:** in its own measures (heads tall, legs to body, neck to back).
- **Signature features:** the two or three details people draw first.
- **Stance and movement:** how it stands, which way each joint bends, where its weight sits, how it moves.

Then decide how to show each feature at game size:
- **Exaggerate the defining feature, simplify the rest.** A figure 40 px tall has room for about three ideas.
- **Separate features by value and hue, not just shape.** A dark muzzle on a light face; a pale belly; a bright weapon
  against the body.
- **Stay above a voxel.** Anything under about a voxel (half a body unit) vanishes or breaks into specks. Make it
  bigger, or drop it.
- **Make the silhouette alone say what it is.** Check it as a black shape in two facings.

Worked examples (each was a real failure):
- **Bear.** It reads by the hump of its shoulders, heavy forelimbs, a long muzzle, small round ears, big flat-footed
  paws and a forward lean. Armour must be **plates that follow that shape**: a collar over the hump, a plate down the
  back, plates on the forelimbs, with the muzzle and paws bare. One capsule over the trunk made it "trunky": "with
  helmet and armour they lose their shape". The aim is a big-shouldered bear in fitted plates, not a barrel with a
  head.
- **Beetle against spider.** A beetle is one hard, glossy domed shell, with a seam down the middle (the wing cases),
  a small head with mandibles or a horn, and six short legs tucked under the shell. A spider is two soft parts and
  eight long jointed legs that rise above its body and splay out. If both are "a body and some thin legs" they read
  the same.
- **Human.** 4.5 heads, legs about 2 heads to the hip, the head round and skull-shaped (not flat-topped), eyes a single
  dark pixel, a helmet head-sized. Its skin is its palette's colour: lifted to white, or capped to grey, it "looks
  unwell".
- **Deer, horse, sheep.** Thin legs, about as long as hip to hoof. The front leg's middle joint bends forward and the
  hock bends back. Reversed joints folded the deer's legs into an X.
- **Buildings.** Big flat planes need texture and wear, or they look low-poly.
  - Roof tiles: the courses run along the eaves; each tile's rounded ridge runs down the slope.
  - Patterns average out to the material's own colour, not darker.
  - Rocks read by a few big planes and sharp breaks, not a heap of turned cubes.

## 2. Colour, light and finish

- **Ramps, not darkening.** Each material needs a ramp from light to shadow, and the shadow steps may shift hue
  (cooler or warmer), not only darken. Keep each material's ramp short (3 to 4 bands) and its bands distinct from
  its neighbours'.
- **No white or grey by accident.** Nothing clips white in the lit band, and nothing loses its saturation. A light
  palette is not brightened. A pale or white creature still has a visible ramp.
- **Clean pixels.** No lone pixels or noise:
  - Fur flecks and patterns stay subtle at game size.
  - Thin parts (whiskers, tails, shafts) stay at least a voxel thick, or they break into specks.
  - Outlines are continuous.
- **One light.** The key light comes from the upper left, the ground shadow is cast by the same sun, and occlusion
  darkens the creases. Shading must not fight the silhouette.
- **Team colour** goes on one clear region (a scarf, a hem, a crest, a shield), never scattered.

## 3. Build it in data

- **Bodies:** `data/voxel/bodies/<id>.json`. A body can build on another (`base`, `add_shapes`, `remap`).
- **Gear:** `data/voxel/gear.json`. Give a body its own armour fit (`fits` by body id) when the generic fit would hide
  its shape.
- **Engines and buildings:** written by Lobster programs (`voxel_engines_gen.lobster`, `voxel_buildings_gen.lobster`,
  helpers in `gen/vx_write.lobster`). Never Python.
- **Resolution:** 2 voxels a body unit, a voxel a baked pixel.
  - Finer detail needs a finer bake. Not built yet; the idea is to bake at 4 and downsample (half-size voxels), for
    finer edges, details and textures, at about 6x the bake time.
  - Patterns (`materials.json`, `pattern`) are texture in the colour, limited by the same resolution.
- **A body's intended oddities** (a frog's folded legs) go in its file's `check` block, with the reason in a `_doc`.
  Never loosen a check globally.

## 4. Check, then review

Checks (they must pass before anyone sees a picture):
- `lobster voxel_check.lobster` (in the quick batch):
  - standing knees;
  - skin as drawn, in every palette and every look (no white, no grey);
  - kit that keeps the creature's shape;
  - no two bodies alike;
  - no specks.
- `lobster voxel_proto.lobster -- - check`: feet on their shadow, standing and walking.
- When Dominic names a fault, first add a check that catches it, then fix it. The check stays.

Review: draw the body and look at it yourself, closely, before showing it.
- **Sheets:** `voxel_proto.lobster -- out.ppm <mode>`.
  - Modes: `creatures`, `legs <body> [gear,...]` (standing, walking and attacking in 8 facings), `skins`, `deaths`,
    `animals`.
  - Look at 3x (point filter), and at game size in a match capture.
- **Questions to ask:**
  - Does the silhouette alone say what it is?
  - Are its signature features visible in every facing?
  - Is any pixel noisy, any part speckled, any joint wrong?
  - Is the colour alive in every palette?
- **Work one creature at a time** to Dominic's sign-off. Coverage without quality is what made it look cheaper.

## 5. Showing Dominic

Show three things together:
- before and after, in the same facing and palette;
- a 3x close-up;
- a match capture at game size.

Say plainly what's still off. Don't call a body done until he's said so.
