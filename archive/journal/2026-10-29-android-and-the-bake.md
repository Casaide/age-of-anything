# 2026-10-29: an APK, and the bake rethought

## What happened
Dominic asked for an Android build ("Make an apk"). Lobster ships an Android template (SDL, OpenGL ES 3) that builds
the game compiled to C++, and the Android SDK, NDK and Gradle were already on the Mac. Getting it to run meant a string
of small Android-only fixes, all kept in `src/android/` so the game's code stays the desktop's: SDL's Java files
matched to the SDL Lobster builds (a download Dominic allowed), the entry point named `SDL_main`, the `../data`
paths made APK paths in a staged copy, a table of the APK's folders (Lobster can't list them), and a patched copy of
Lobster's engine (reading a texture back on GLES, a tap's position from its own event, a tap seen in the frame it
lands). The lobby kept the phone's keyboard up the whole time; now only while a box is being typed in.

The first start then baked art for minutes. Dominic: "How much baking is really needed? Surely we should bake the
parts and only need to put them together?" and, on 480 MB of building art for one match start, "Saving masses of
pngs to disk at game start seems nuts". Measured: the buildings were 455 MB of 480 (762 files, 69 looks for two
cultures), written as uncompressed PNGs (the game's own writer stores raw pixels; deflated they're 7x smaller); the
units were 17 MB. Buildings and props don't depend on the prompt at all, so they're now baked once on the build
machine and shipped (D-185). The unit bake was profiled: 29 s of 67 in a byte-by-byte Lobster shrink, 26 s
re-projecting every vertex and rebuilding meshes every facing, 15 s rendering. Now the shrink runs on the GPU, the
meshes are made once a part in model space, and the boxes come from a part's distinct corners: 9 s, same pixels.

## Decisions
- D-185: buildings and props ship baked; a unit part bakes on the GPU (Dominic's direction, Claude's design).

## Bugs worth remembering
- The GPU shrink came out with every edge pixel's alpha squared: blending was still on in the shrink pass
  (161/255 squared is 102/255, exactly what the GPU gave).
- On touch, Lobster reports buttons a frame late, so a tap pressed and lifted in one slow frame never pressed.
- Bears and the cat mount draw without bodies on Android (open: the bodies bake right on the device).

## Pictures
- `archive/images/2026-10-29/01-android-title-emulator.png`: the first title on Android, after minutes of baking.
- `02-android-title-after-bake-rework.png`: the title ~25 s after launch, two new races baked on the device.
- `03-android-battle-setup.png`, `04-android-match-statusbar-overlap.png` (the status bar over the top bar, fixed
  since), `05-android-bears-without-bodies.png` (the open bug, behind Android's full-screen note).

## Ideas parked
- In `docs/backlog.md`, "Android and the bake rework": touch controls, the bodies bug, GPU path for the building bakes,
  texture memory.

## Later the same day: on a real phone
Dominic installed it on his Fairphone 6 ("game looks really great on the phone though") and sent a list: a black
screen and SDL's logo before the menu, the full-page baking screen popping up while typing (and taking the keyboard),
the match loader stalling at 90% with "making units" in a corner, bears and walking sheep without bodies or legs, no
way to move units, no hold-to-grow selection, no pinch zoom, and "the menu from steam deck for building is better
for small screens".

The missing bodies weren't Android's: a walk step or pose is a part of its own (`leg.bear@w3_8`), and nothing baked
them but the placement checks and sheet tool, which share the Mac's `bake_cache/`. A fresh install (the Deck's too)
drew nothing for them. Now a part drawn before it's baked is wanted and baked between frames, its plain form standing
in, and the match start bakes the walk too, counted on the loader ("Making the units: 50 of 200"). The lobby no
longer stops for its armies: a thin bar at its foot while they fill in. A loader from the first frame, the sun crest
as the app's icon and splash. Touch plays through the pad's controls (Dominic's call): tap selects or opens the wheel
or orders, hold grows the circle, drag pans, pinch zooms, back backs out.

## Bugs worth remembering
- Bears without bodies on the phone but fine on the Mac: the Mac's cache had been filled by the test tools.

## Afternoon: what the port lost (Dominic on the phone and the Mac)
Dominic found pieces of the Godot match missing: WASD panning, the lines showing where units are going, a HUD smaller
and harder to read than Godot's, music too loud with no way to turn it down, Start Battle freezing for a second or two
before the loader appears. Claude had a sub-agent compare the Godot client (`sim_debug.gd` and `src/view/` at
`22be3d3^`) with the Lobster one. Back now:
- **WASD panning**, with the keys Godot used to keep it clear: X stops, Ctrl + right-click attack-moves, and a
  building's research keys skip W A S D (Q E R T Y F G H J).
- **Order lines** (`game/order_marks.lobster`, from `order_marks.gd`): dashed routes for the current and queued
  orders, rings and little team flags at waypoints, outlines on builds, gathers and drop-offs, attack targets ringed
  red, a thin line from each fighter to its foe, and the selected building's rally flag. Picture 08.
- **Music and Sound volumes** on the title page and in the pause menu, saved in `settings.txt`; music starts at 50%.
  Picture 09.
- **The HUD's size**: Ctrl/Cmd + and - again (saved), and a little bigger by default (115%).
- **Start Battle** draws the loader the moment it's pressed.
- **A placeholder in an empty race box** even while it has the cursor.
A sub-agent found the leaks Lobster reports at exit: every unit view's node tree is a cycle (parent and kids), so views
dropped without `free_tree` leaked, ~20,000 objects after a match. Freed now where they're replaced and at exit: 0.
Still missing from Godot (listed for Dominic): shift and double-click selection, inspecting enemies and resources,
shift-train five, alerts ("Under attack!", the alarm, Space to jump), first-match tips, context cursors, some sound
cues, middle-drag pan and zoom towards the cursor, building hotkeys.

## Evening: the phone's slow start, hills in the fog, touch placing

- **One Android PR to Lobster** (Dominic: one PR, not several, to spare the maintainers): the GLES texture read-back, the lost
  taps, `SDL_main` on Android, and the template brought up to SDL 3 and today's Gradle, on the fork's
  `android-gles-touch-sdl3`. Tested by building Lobster's own template untouched with a drag sample, on the emulator:
  its first run said `dlopen failed: library "libSDL3.so" not found` (SDL is built into libmain), fixed in the branch.
- **D-186:** the start bakes only the starting age's units (4.8 s from 28.8 s on the Mac); later ages bake a facing a
  frame in play. One loader: the bake moves the loader's bar. Picture 12.
- **Hills poked out of the fog** (Dominic's screenshot): the fog lay only on the ground's tops, so the cliff faces had
  none, and each hill's near-edge tops, drawn again after the units so a hill hides what's behind it, came after the
  fog. Now the faces that show have fog down them and each of those edges carries its own. Pictures 10 (before) and
  11 (after).
- **Touch placing**: a tap puts the building down (it waits mid-screen), a drag pans; a wall or gate is dragged end
  to end. Walls dragged in lines were lost in the port on the desktop too: back (press at one end, release at the
  other). The Build button's touch no longer starts a selection box that never ends, and a double tap with your
  building selected sets its rally point.
- **The setup page sizes its armies by the screen** (Dominic: "smaller the screen, less units"): a unit for each 0.6
  inch of stage (Lobster's `gl.dpi`), two to six, drawn bigger when fewer fit. The title and setup pages' own
  "Making the armies" bar is gone (one loader), and a unit there shows only once all its parts are baked.
- **Lobster docs PR** (Dominic's patch): https://github.com/aardappel/lobster/pull/461.
