# Art pass (parallel)

**Status:** in progress (started 2026-10-11): step 1, the style sampler
**Exit criterion:** 200 units at 60 fps; draw calls verified; Frogs vs Rats fully in the chosen
style.

## Scope
Replace the placeholder vector shapes with the chosen art direction. Recipes, sockets and the
procedural animation stay; `part_shape.gd` is the swap point. Shared palette/team-mask recolouring
(one drawn helmet serves every race and team), terrain, buildings, and later the UI (race-themed,
see the backlog).

## Plan

**Step 1: style sampler (Dominic asked for samples of every direction).** One scene,
`scenes/style_sampler.tscn`, with the same little scene in five panels: grass, swamp, reeds and
bug bushes, a Town Center and a house, frogs and rats milling about with their usual animation.
The five panels are:
1. **Storybook vector:** our shapes with three-tone cel shading, ink outlines, highlights, eye
   glints.
2. **Paper puppets:** rough-cut paper parts with white borders, drop shadows, brass pins at
   joints and paper grain. Rigid-part animation becomes the look.
3. **Painterly:** shapes without ink under a painterly filter. This is a cheap stand-in for
   hand-painting and is labelled as one.
4. **Toy diorama (pre-rendered 3D):** a real 3D render from primitives (lit, shadowed, plastic),
   isometric orthographic camera. In production these renders would be baked into the 2D atlas.
5. **Pixel art:** rendered at 1/3 resolution with nearest scaling, so the rotation shimmer shows.

Keys 1-5 show one style full-window, 0 shows all of them. The archive gets the grid and each style.
Dominic picks a direction (or a mix).

**Step 1b: detail and design, not just rendering (Dominic, 2026-10-11).** Step 1 only varied
the *rendering* of today's placeholder frog. Step 1b designs a hero character (the frog worker,
then the rat spearman) properly in each direction, at production detail, still built from parts
on pivots so the procedural animation works. It's shown at true game size (~40 px) next to a
large portrait, to see what detail survives in play and what's only for the unit card.
Storybook, paper and painterly parts are hand-authored SVG rasterised at runtime, the toy is a
properly built 3D figure, and the pixel version is hand-placed pixels (a game-size sprite plus a
portrait, as classic games did).

**Step 1b, first: a sixth direction, high-fidelity pre-rendered (Dominic, 2026-10-11).** The
classic RTS look sits "somewhere between toy and pixel": detailed 3D models rendered offline and
shrunk to small sprites, with the fidelity in the source models. Buildings are static, so they
can carry the most detail. Built as a real pipeline prototype:
detailed 3D models in Godot (procedural wood, thatch, mud, stone textures with normal maps)
-> a baker renders each model, and each unit *part* with its pivot, at 4x -> sprites with
mipmaps (level of detail for free) -> the 2D isometric scene, with baked parts posed by our
procedural animation. Order: buildings, then the frog worker, then the rat.

**Step 1c: high-fidelity pixel art (Dominic, 2026-10-11).** Dominic's verdict on step 1b:
something from the original and the pixel art was lost. The 3D frog was a different character
(the frog people lost their feel), and the physically-based lighting went "a level too far,
into uncanny valley". In the classic games you never think about the lighting; they're pixel
games. So:
1. **Keep the original characters exactly:** every 2D part in `parts.json` becomes simple lit
   3D automatically (ellipse -> ellipsoid, circle -> sphere, polygon -> extruded, line -> rod),
   drawn in its original 2D order, then baked to a pixel sprite (4x render, downsampled, hard
   alpha, darker 1-px inner outline). `UnitView` draws the baked sprites, so sockets,
   animation and mounts are untouched.
2. **Pixel, not physically-based:** matte materials and one soft light; the scene renders at art
   resolution through one shared palette (light ordered dithering) and scales up 2x with nearest.
3. **Terrain like the classic games:** no grid; one continuous ground drawn by a shader from
   blurred terrain masks, with rounded shorelines, a mud bank, sparkle, and soft swamp and
   reed-bed blends.
Shown in its own scene, `scenes/art_pixel.tscn`, on a larger map with a pond.

**Step 1d: higher-fidelity units with authored textures (Dominic, 2026-10-11).** Dominic: use
the designs as reference, not as-is; units shouldn't feel made from a bunch of shapes (they all
had one leg). Textures must be real texture art, authored by Claude as image assets (no
downloads), not generated from scratch. So each part id gets a hand-built 3D model in
`scenes/art_pixel/unit_models.gd` with proper anatomy (two legs, arms, hands), authored SVG
textures (`assets/art/textures/`) mapped triplanar and tinted by race colours, and authored
decals for features (eyes, mouths, leaves, lily pads). Models are baked three-quarter, and their
sockets are projected into 2D (`PartShape.rigs`), so UnitView composes them as before. Parts
without a model still fall back to the automatic bake.

**Step 2 (after the pick):** shared groundwork: palette/team-mask shader, atlas plus pivots in
`parts.json`, and the draw-call check at 200 units.

**Step 3:** vertical slice: the Frogs vs Rats roster, buildings and terrain in the chosen style.

## Checklist
- [x] Style sampler: five panels, single-style view, captions with honest notes
- [x] Archive: sampler pictures, journal, decisions, timeline
- [x] Step 1b: high-fidelity pre-rendered: baker, buildings, props, terrain
- [x] Step 1b: high-fidelity pre-rendered frog worker (baked parts, 2D animation)
- [x] Step 1c: high-fidelity pixel art: auto-3D parts baked to pixels, palette, continuous terrain
- [x] Step 1d: frog and rat parts modelled with authored textures (body, head, leg, gear)
- [x] Fix: parts layered by child order (z_index drew units over buildings); baked ground shadows
- [x] Step 1d: rat on a spider (spider body, head, legs; cheese hammer, mail), other roster gear (sling, crossbow, saucepan helmet, blowgun)
- [x] Near arms as their own outlined layer, above torso armour (Dominic: arms were hard to see)
- [x] Terrain polish: stones, wildflowers, grass tufts, shoreline reeds; generated culture paths
  (families.json `paths`: Romans paved roads, swamp boardwalks, sewer cobbles, trails)
- [x] Stepped pixel animation (F toggles it in the scene)
- [x] Rat-culture ("junk") buildings: scrap Town Center, tin-can house; families.json `architecture`
- [x] Paths: boards across the walk (arc length), each stretch drawn once, ragged seams where
  cultures meet (Dominic: "rotated wrong way?", "handle merging different types of roads")
- [x] One palette of 256 colours (nearest pairs merged)
- [x] Groundwork: team-key bakes + team shader (colour via self_modulate), one atlas for unit
  parts, unit shadows and scene sprites, one shared material: 20 draw calls at 211 units
  (2,137 without the atlas). `tests/art_bench.gd`; B adds 200 units in the scene.
- [x] Step 1e, landscape (Dominic: "still a bit flat; bushes seem undone, water looks very cheap,
  reeds look bad"): rolling height and richer grass, proper water (depth, shallows, foam,
  wavelets, lilies), reed clumps with ribbon leaves and cattails, leafy bug bushes, thatch
  courses, contact shadows under buildings and props
- [x] Models for the other creatures (humans, centaurs, ponies, beetles) and all gear, with new
  authored textures; centaurs use a neckless fused body (`creatures.json` `fused_body`)
- [x] Architecture per culture: stone (imperial, hellenic, royal) and felt tents (steppe), as
  well as thatch and junk
- [x] Independent review of all the art (every race, texture, building and the landscape) by a
  separate agent; high-severity findings fixed (team colour on every unit, weapon silhouettes,
  gear on beetles and spiders, authored building textures, the Corinthian helmet), the rest in
  `docs/backlog.md` section 9
- [ ] Step 1b (maybe later): hero frog in the other directions at production detail
- [ ] Step 1b: hero rat spearman
- [ ] Dominic picks a direction
- [x] Groundwork: shader, atlas, draw calls
- [x] Vertical slice: the debug match (sim_debug) runs in the pixel art via `src/view/art/`
  (art kit, terrain view, building view); old placeholder views deleted

## Results
- **Step 1 done (2026-10-11):** `scenes/style_sampler.tscn` shows all five, at the same in-game
  scale, with 4x close-ups on keys 1-5. Pictures: `archive/images/2026-10-11/08-13`.
- What it showed (Claude's read, for Dominic to judge):
  - **Storybook** reads best at game scale and keeps everything we have. Ink plus cel shading
    is a cheap, big step up from the placeholders.
  - **Paper** ground is lovely (sheets with torn edges); paper *units* get busy at small sizes,
    because all the white borders blur together. It needs fewer, bigger pieces per unit.
  - **Painterly (faked)** mostly turns into soft blur at game scale. A filter can't stand in for
    real painting, so this one is judged mainly by imagination.
  - **Toy diorama** looks the most "finished" straight away (light, soft shadows, plastic); the
    primitive units are charming. It costs a 3D pipeline, and baked parts would lose live lighting.
  - **Pixel** is readable and nostalgic; the shimmer on rotating parts is visible, as predicted.
- **Step 1b, high-fidelity pre-rendered (2026-10-11):** a working pipeline prototype in
  `scenes/style_sampler/hifi/`: procedural PBR materials (wood, thatch, mud, stone, grass, swamp,
  frog skin, basket weave) -> detailed models (frog Town Center with stone footing, timber frame,
  stepped thatch, chimney, barrels, crate, woodpile; a stilt hut with deck and ladder; reeds,
  bug bushes, grass and swamp tiles; a frog worker in six parts) -> `baker.gd` renders at 4x
  with a key/fill/rim rig and SSAO, crops, alpha-bleeds, mipmaps -> sprites in the 2D isometric
  scene. Live parts on buildings: a waving banner (shader), chimney smoke (particles),
  flickering windows and lantern (additive glow), a spinning weathervane. Frog parts are baked
  with their pivots and posed by 2D animation. Pictures: `archive/images/2026-10-11/14-15`.
  - Claude's read: at game size this is the one that reads most like a classic RTS, and the detail
    survives the shrink (thatch, timber, glow, banner, frog silhouettes). Baking a part per
    pivot works; the cost is a 3D modelling pipeline for every part.

- **Step 1c, high-fidelity pixel art (2026-10-11):** `scenes/art_pixel.tscn`.
  - Every unit part is baked from auto-3D, so the original frogs and rats keep their design
    (toad-brown frogs in leaf hats, bark armour and lily-pad shields; white rats; the rat on
    a spider). They're drawn by the normal UnitView through `PartShape`'s "baked" style.
  - Units sit at 70% of the canvas scale (about a third of a building's height) and are baked
    at that size, so they stay crisp.
  - Buildings and props are the step 1b models made matte, baked at 4x and pixelized with
    ground shadows, keeping their live parts.
  - The terrain is one shader: no grid, a rounded pond with a mud bank, foam and sparkle, and
    soft swamp and reed-bed blends.
  - The whole frame goes through one palette (351 colours for now) with a light ordered
    dither, at 2x nearest. Pictures: `archive/images/2026-10-11/16-18`.
  - Claude's read: this keeps what the original and the pixel panel had, and reads as a
    classic RTS. Unit *detail* is still capped by today's simple part shapes; richer units
    mean richer parts (more shapes per part in `parts.json`, or hand-made 3D parts per id).

- **Step 1d (2026-10-11):** frogs and rats re-made from the reference with real anatomy (two
  long folded frog legs with webbed feet and toe pads; rats with snouts, whiskers, ears and
  tails) and authored textures: frog skin with spots, belly, amber frog eyes, rat fur, bead
  eyes, bark plates, leather, wicker, acorn scales, reed stalk, bone, bronze, iron, wood grain,
  leaf, lily pad. Pictures: `archive/images/2026-10-11/19-22`.
  - Fixed on the way: units drew over buildings in front of them (part `z_index` is global;
    now parts are ordered by child order), and building ground shadows were missing (the
    shadow range stopped at the bake camera; the faint shadow-catcher is now a shadow-only
    second pass). The sun now comes from the screen's upper left, with shadows falling lower right.
  - The frogs still read a little toad-like in colour: the race rolled `toad_brown` skin.

- **Step 1e, landscape (2026-10-11):** see the checklist. New authored textures: `reed_leaf`,
  `ladybird`, `water_lily`, `foliage`, `thatch`. Props live in `scenes/art_pixel/prop_models.gd`.
  Pictures: `archive/images/2026-10-11/32-34`.
- **All races and cultures (2026-10-11):** every one of the 63 parts has a hand-built model. New
  textures: `cloth`, `skin`, `hide`, `mane`, `chitin`, `human_eye`, `plume`, `wing_feather`,
  `wing_bat`. Stone and tent buildings in `scenes/style_sampler/hifi/models.gd`. Pictures:
  `archive/images/2026-10-11/35-41`.

## Changes from the original plan
- The original plan assumed the painterly direction. Direction is open again (2026-10-11):
  Dominic found the placeholder style "surprisingly cute" and asked for samples of every option.
