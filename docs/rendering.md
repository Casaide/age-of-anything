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
3. **Pixelize** (`scenes/art_pixel/pixelize.gd`): down to art pixels, value posterised into
   painted bands (`ArtKit.UNIT_BANDS`: the paint-over look) and a dark outline.
4. **Team colour**: parts bake in a magenta team key; `src/team_mask.gdshader` swaps it for the
   unit's team colour (in `self_modulate`) when drawn.
5. **Compose** (`src/unit_view.gd`): a unit is its parts as sprites placed on the body's
   sockets for its current facing, layered by depth (a cape draws over the body walking away, a
   far shield under it), animated in 2D (walk cycles, hops, work blows, attacks). A unit picks
   the facing that best fits its movement on screen, with hysteresis, and rebuilds when it
   changes.

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
- **Early.** The lobby's `ArtKit` bakes the armies, then warms up the props and both cultures'
  buildings in the background (`ArtKit.warm`), and hands itself to the match.
- **The match loader** (`scenes/match_loader.gd`) shows `ArtKit.progress()`, the share of the
  asked-for jobs done, weighted by their renders.

`tests/art_bake_time.gd -- cold|warm|off` times a match start (two races, all their buildings).

## Checking art

Look at every change before showing it (Dominic catches floating parts, wrong layering and odd
shapes at once). Close up and at game size:

```sh
godot --path . --script res://tests/facing_sheet.gd -- out.png "prompt" [zoom]          # a roster in all 8 facings ("animals" too)
godot --path . --script res://tests/concept_sheet.gd -- out.png 14 1 "prompt" [az=215] "gear=..." ...   # one unit, close, options side by side
godot --path . --script res://tests/building_sheet.gd -- out.png 2 type:arch prop.quarry.1300.0 ...
godot --path . --script res://tests/building_sheet.gd -- out.png 2 stilt_house tree.1.pine.0 tree.1.swamp.1.3 bridge.1.3.0.1   # trees (seed.species.style[.stage]), bridges (seed.length.style[.broken])
godot --path . --script res://tests/building_variants.gd -- out.png 1.5   # every variant of every culture
godot --path . --script res://tests/sim_screenshot.gd -- out.png flat_test ai-look:x:y:zoom   # the map as played
```

**Check facings in the facing sheet, not the concept sheet.** The concept sheet's `az=` turns the
bake but keeps the classic view's layering, so from behind it draws the near arm across the back
(a false alarm Dominic caught). `facing_sheet.gd -- out.png "prompt" 8 <unit index>` shows one
unit's real 8 facings close up. Bodies whose clothes hang over the hips set `legs_under`.
