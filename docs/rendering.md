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
     ours, so skin palettes and team colours still work. Today: the human head and torso.
   - A model returns its node plus, for bodies, `sockets` (3D points where the head, hands,
     torso armour, back and seat go), leg `anchors`, and fitting data: `torso_scale` (2D,
     legacy), `torso_fit` (3D scale for worn armour), `torso_tilt`, `gear_scale` (on heads).
   - Concept options live in `scenes/art_pixel/concepts.gd` (`concept.*` ids), shown with
     `tests/concept_sheet.gd`; nothing there is in play until picked.
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
  frame, roof, base: `KIT`). Baked once per culture, plus four construction stages. Data
  shapes them further (`data/buildings.json`): `scale` per culture and type, `variants` (houses
  bake turned and resized four ways, each building picks one), and `age_looks` (a building's
  model from an age on, e.g. the rats' oil-drum town hall at age 3).
  Live parts (banner, vane, smoke, lights) are drawn over the bake.
- **Props** (`scenes/art_pixel/prop_models.gd`): bushes, reeds, boulders, quarry stone and
  gold, carcasses, crops, the rally flag; resources bake in used-up stages.
- **Terrain** (`scenes/art_pixel/terrain.gdshader`): one shader paints the ground from blurred
  terrain masks (water depth and sky, swamp, rock, paths); not baked.
- **UI art**: SVG icons and cursors in `assets/art/icons/` and `assets/art/cursors/`,
  rasterised at load.

## Blender

Installed with Homebrew (`/opt/homebrew/bin/blender`, Dominic's yes, 2026-10-11). Scripts build
models from code so they're reviewable and repeatable:

```sh
blender -b --python tools/blender/human_head.py -- assets/models/head_human.glb
blender -b --python tools/blender/human_torso.py -- assets/models/torso_human.glb
```

Model in the game's part units, facing +X, up +Z (glTF export turns it into Godot's +X forward,
+Y up). Name every material for what the game should put there. Keep the primitive version as
a fallback when a `.glb` is missing.

## Checking art

Look at every change before showing it (Dominic catches floating parts, wrong layering and odd
shapes at once). Close up and at game size:

```sh
godot --path . --script res://tests/facing_sheet.gd -- out.png "prompt" [zoom]          # a roster in all 8 facings ("animals" too)
godot --path . --script res://tests/concept_sheet.gd -- out.png 14 1 "prompt" [az=215] "gear=..." ...   # one unit, close, options side by side
godot --path . --script res://tests/building_sheet.gd -- out.png 2 type:arch prop.quarry.1300.0 ...
godot --path . --script res://tests/sim_screenshot.gd -- out.png flat_test ai-look:x:y:zoom   # the map as played
```

**Check facings in the facing sheet, not the concept sheet.** The concept sheet's `az=` turns the
bake but keeps the classic view's layering, so from behind it draws the near arm across the back
(a false alarm Dominic caught). `facing_sheet.gd -- out.png "prompt" 8 <unit index>` shows one
unit's real 8 facings close up. Bodies whose clothes hang over the hips set `legs_under`.
