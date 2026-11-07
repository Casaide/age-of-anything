---
name: voxel-art
description: Make Age of Anything's voxel units, gear, engines, buildings or props (data/voxel/) as high-quality voxel art, from scratch. Use for any new voxel body or gear, any fix to how one looks, and before showing Dominic a voxel picture.
---

# Voxel art

Goal: a 30 to 60 px figure that reads instantly and looks real, the way the rat does. Dominic judges by **realism and
proportion**. Chunky or big-headed reads as wrong.

## The only two inputs
**What it is** (the subject, in real life) and **how big** (its height on screen, in body units; a human is about 40,
a rat about 20). Everything else comes from the subject itself, never from what's in the game now.

## Make it from scratch
- **Never start from, tweak or compare against an existing body.** Old bodies anchor you to their faults: tweaks on
  the same proportions read as "looks the same". Don't open the body you're replacing, and never show an old body
  next to the new one.
- Start from the real subject: write its `_doc` first (silhouette, proportions in its own measures, two or three
  signature features, stance), then build the shapes from that.
- Start a new body by copying `blank_body.json` (next to this file: a biped skeleton about 40 units tall, no shapes)
  to `data/voxel/bodies/<new id>.json`. Scale its points to the size asked. Use a new id until Dominic signs off.
- `bodies/rat.json` is the one reference for *method*: few shapes, strong tapers, a natural pose. Use it for how to
  build, not for what to build.

## Real subjects: trace them, don't guess
A real thing (a Sherman, a Panzer IV) is one specific variant, carved from real drawings. Modelled by eye it comes out a
mixture of things, however careful (Dominic, 2026-11-06, D-235). The Sherman, `mods/ww2/trace/m4a3_75w.json`, is the worked example.
1. **Name the variant** and find square-on drawings of it. US War Department manuals are public domain and good: FM 30-40 has top,
   side and front plates of many WW2 vehicles (M4A3 at PDF p55, Pz IV at p132). Check the plate shows your variant. Wikimedia's API
   rate-limits; ibiblio's hyperwar and archive.org hold the manuals.
2. **Never commit the references.** `tools/trace/refs.sh` fetches them into gitignored `reference/` and cuts out each view. Record
   URLs and licences in the issue and the PR.
3. **Find real dimensions** in a manual or spec sheet, and cite them. The spec says which pixels are the ends of each view and what
   they measure, so each view scales to the published length, width and height.
4. **Carve:** `lobster carve.lobster -- <spec> build` keeps a voxel only inside the side, top and front outlines, then writes the body. Don't edit
   the body; change the spec. It's the same shapes everywhere, so a thin thing (a lock, an exhaust, a machine gun) extrudes across the
   whole width unless the spec `erase`s it from the outline and adds it back as a detail at its traced position. Above the hull,
   `turret_top` traces the turret's inner line, since the top silhouette can't see it.
5. **Details at traced positions:** points are pixels on the drawings (`["o", x inches, side h, side v]`, `["t", top v, top h, side v]`), sizes are inches.
   Running gear goes in `tracks` and `wheels`, sloped plates in `plates` (flat boxes, or they terrace). Hard shapes reach half a voxel past their size.
   A line drawing crossed by dimension lines can't be filled: trace each view's `outline` as polygons over it (the P-51, `p51d.json`). Three outlines can't tell a wing from a tailplane at the same width: `exclude` a stretch of the front outline along the plane, or each grows a ghost of the other. A flier says `flies`: real-size wings reach the ground line on screen, so `voxel_proto -- - bodies` sets how high it must be.
6. **Check against the drawing:** `lobster carve.lobster -- <spec> check <dir>` writes side, top and front overlays (grey agree, red voxels only, blue drawing only), a
   line per view of what's over a voxel out, and a table at the spec's `stations`. Aim for under a voxel; say honestly what isn't. The table goes in the PR.
7. **Play it in a real match before showing it.** Renders aren't the game: an engine's `skin` is its crew's colour, so paint it with a material of its own.
   Then `voxel_proto -- - bodies` and `parts`, and look at it at game size.

## Read only this
This file, `blank_body.json`, `rat.json`, and the gear entries you touch. Don't read `view/voxel.lobster` or
`docs/rendering.md`: the cheat sheet below is enough.

## Format cheat sheet
- Body units: z up, y forward, x right, ground z 0. 2 voxels a unit. `size` scales the figure.
- Points: `["point", x, y, z]` offsets. Legs: `hip`, `foot`, `bones` [thigh, shin] (their sum ≈ hip z − foot z, or
  the knees bend more than 15°), `r` [thigh, knee, shin, ankle], `shapes` on `ankle`/`knee`.
- Arms are capsules drawn by the engine: set `shoulder`, `bone`, `thick`, `sleeve`, `hand`.
- Shapes: `cap` (to, r [a,b]), `ball`/`bead` (bead is hard), `disc` (n, r [radius, thick]), `box` (n = face normal,
  `half` [across, depth along n, height], `round`), `chain`, `ring`. Plus `mirror`, `if`/`unless` (`helm`,
  `helm:galea`, `look:N`, `armour`).
- An oval section (a torso): two capsules side by side at x ±1.2.
- Gear frame: `["hand", along, out, side]`. Fits are per body id; a new id gets only the `*` fit, so give it its own
  fit for helmets and armour.

## Design rules
- **Humans:** about 7 heads, small head, legs half the height, shoulders 2 heads wide over narrower hips, thighs
  tapering hard to knee and ankle. No eye pixels. Team colour on the tunic.
- **Gear contrasts with what it covers** (a grey helmet reads as grey hair: use bronze, a rim, a crest) and follows
  the real object (a scutum is curved: panels round an arc).
- Exaggerate the defining feature and drop anything under a voxel. One light from the upper left. Colour ramps, never
  white or grey by accident. Team colour on one clear region.

## Build, check, look
- `lobster voxel_proto.lobster -- out.ppm solo <body> [gear,...]` (from `src/`): that one body alone at 3x, in four
  facings standing and four walk steps, cropped tight. This is the only picture you need. Look at it yourself before anyone else sees it.
- Checks must pass first: `lobster voxel_check.lobster` and `lobster voxel_proto.lobster -- - check`.
- Cloud threads: the device can't run lobster (aarch64). Stage the Linux lobster binary and its modules,
  `src/{gen/*, view/voxel, voxel_check, voxel_proto}.lobster` and `data/`, then
  `apt-get install libopengl0 libgl1 libegl1`.

## Showing Dominic
Show the new thing on its own, at 3x, with a short line on what's still off. Fix one named fault at a time. Don't call
it done until he says so.
