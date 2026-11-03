---
name: voxel-art
description: Make or change Age of Anything's voxel units, mounts, gear, engines, buildings or props (data/voxel/, view/voxel.lobster) so they read as well as the baked art. Use for any new voxel body or gear, any fix to how one looks, and before showing Dominic a voxel picture. It starts from what makes the subject recognisable, not from the format.
---

# Voxel art

The voxel builder makes every unit from data (`data/voxel/`: bodies, gear, holds, materials; format in
`docs/rendering.md`, "Voxel units"). The format is easy. What's hard is making a body read at game size, 30 to 60
pixels tall, as well as the baked art did. **The bar is the composed bakes and the voxel rat.** The rat is the only
body that went round after round with Dominic, and it still looks best. "It looks cheaper, AND with problems" is
the failure to avoid (Dominic, 2026-11-03).

## 1. Know the subject before you model it

Before you write a shape, write down in the body's `_doc` what makes this thing *this* thing:
- **Silhouette:** the shape you'd know from its shadow alone.
- **Proportions:** in its own measures (heads tall, legs to body, neck to back).
- **Signature features:** the two or three details people draw first.
- **How it stands and moves:** which way each joint bends, where its weight sits.

Then decide **how to show each feature at 30 px**:
- Exaggerate the defining one.
- Simplify the rest.
- Give each feature its own value (light against dark), so it survives shading and the outline.

A feature smaller than about a voxel (half a body unit) vanishes or breaks into specks. Make it bigger, or don't
make it.

Worked examples (each was a real failure):
- **Bear.** It reads by the hump of its shoulders, heavy forelimbs, a long muzzle, small round ears, big
  flat-footed paws and a forward lean. Armour must be **plates that follow that shape**: a collar over the hump, a
  plate down the back, plates on the forelimbs. The muzzle and paws stay bare, so the bear shows through. One capsule
  over the trunk made it "trunky". "With helmet and armour they lose their shape": aim for a big-shouldered bear in
  fitted plates, not a barrel with a head.
- **Beetle against spider.** A beetle is one hard, glossy domed shell, with a seam down the middle (the wing cases),
  a small head with mandibles or a horn, and six short legs tucked under the shell. A spider is two soft parts and
  eight long jointed legs that rise above its body and splay out. If both are "a body and some thin legs" they read
  as the same thing ("beetles look too much like spiders").
- **Human.** 4.5 heads, legs about 2 heads to the hip, eyes a single dark pixel, a helmet head-sized. Its skin is its
  palette as is: lifting a light palette made it white, and capping it badly made it grey ("looks unwell").
- **Deer, horse, sheep.** Thin legs, about as long as hip to hoof. The front leg's middle joint bends forward and the
  hock bends back. Copying the pony's reversed joints folded the deer's legs into an X.
- **Buildings.** Roof tiles: the courses run along the eaves, and each tile's rounded ridge runs down the slope.
  Check the direction against the baked roof (round 2 turned it 90 degrees). Patterns must average out to the
  material's own colour, not darker. Rocks read by a few big flat planes and sharp breaks, not a heap of turned
  cubes.

## 2. Work from the reference

- **Put the baked one first.** Before changing a body, put its composed bake beside it at game size and at 3x, in
  the same facing and palette. That is the target. Today: `play.sh ... composed shot:` crops, or the creature sheet
  in `voxel_proto.lobster`. (Missing tool: one command that puts the composed bake beside the voxel one for every
  creature.)
- **One creature at a time, to sign-off.** Don't port ten bodies in one round. Coverage without quality is what made
  it look cheaper.

## 3. Build it in data

- **Bodies:** `data/voxel/bodies/<id>.json`.
- **Gear:** `data/voxel/gear.json`. Give a body its own fit for armour (`fits` by body id) when the generic fit would
  hide its shape.
- **Engines and buildings:** written by Lobster programs (`voxel_engines_gen.lobster`, `voxel_buildings_gen.lobster`,
  helpers in `gen/vx_write.lobster`). Never Python.
- **Resolution:** 2 voxels a body unit, a voxel a baked pixel.
  - Detail below that needs a finer bake. Not built yet; the idea is to bake at 4 and downsample, so edges and
    patterns stay fine.
  - Patterns (`materials.json`, `pattern`) are texture in the colour; they're limited by the same resolution.
- **A body's intended oddities** (a frog's folded legs) go in its file's `check` block, with the reason in a `_doc`.
  Never loosen a check globally.

## 4. Check before anyone sees it

Run all three, and look at every picture you made before you send it:
- `lobster voxel_check.lobster` (in the quick batch):
  - standing knees;
  - skin as drawn, in every palette and every look (no white, no grey);
  - kit that keeps the creature's shape;
  - no two bodies alike;
  - no specks.
- `lobster voxel_proto.lobster -- - check`: feet on their shadow, standing and walking.
- **Sheets:** `voxel_proto.lobster -- out.ppm <mode>`.
  - Modes: `creatures`, `legs <body> [gear,...]`, `skins`, `deaths`, `animals`.
  - Look at 3x (point filter) and at game size.
  - Before and after, side by side.

When Dominic names a fault, first add a check that catches it, then fix it. The check stays.

## 5. Showing Dominic

Show three things together:
- the baked reference, the old voxel version and the new one, in the same facing;
- a 3x close-up;
- a match capture at game size.

Say plainly what's still off. Don't call a body done until he's said so.
