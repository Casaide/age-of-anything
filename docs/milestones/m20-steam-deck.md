# Milestone 20: Steam Deck and controllers

**Status:** planned (proposed 2026-10-13)
**Exit criterion:** a full match against the AI, from the menu to the end screen, played on a
Steam Deck with its controls only (no mouse or keyboard), at a steady 60 fps (or a locked 40-45
with the Deck's frame limiter, if 60 can't hold), readable at 1280 x 800 on the 7" screen, the
first launch's bake under a minute and later launches near instant; the mouse and keyboard
game on a Mac unchanged; Dominic plays it on the Deck and says it feels right.

Dominic (2026-10-13): "Running the app on Steam Deck, and adapting UI for controllers if used."

## What the Deck means for us

- **Linux build.** The Deck runs Linux (SteamOS); Godot exports a native Linux x86_64 build.
  Proton (running a Windows build) is a fallback, not the plan. Exporting needs Godot's export
  templates (about 1 GB, a download that needs Dominic's yes: it's already in the backlog, §0).
- **Hardware.** A 4-core / 8-thread AMD APU with integrated graphics (Vulkan), 16 GB shared
  memory, 1280 x 800 at 7", battery. Much slower than the M4 Max we test on: the sim's tick, the
  draw calls, the bake and the shaders all need measuring there.
- **Renderer.** Our project uses Forward+ (Metal on the Mac). On the Deck, Forward+ on Vulkan
  works, but the Mobile or Compatibility renderer may run cooler and faster for a 2D game whose
  3D is only the bake; decide by measurement (the bake must look identical).
- **Controls.** The Deck has two sticks, two trackpads, a d-pad, ABXY, four bumpers/triggers, four
  back buttons and a touchscreen. Steam Input can map anything to mouse and keyboard, which gives
  a playable game for free (trackpad as mouse); the milestone is about making it *good* with a
  controller, and also working with a plain gamepad on any machine.
- **Determinism.** Lockstep multiplayer will need the Mac and the Deck (Linux, x86) to compute
  identical hashes: the backlog's "determinism across macOS and Linux" check happens here for
  free (run `tests/test_sim.gd` on the Deck and compare hashes with the Mac).

## Controller design (the RTS-on-a-pad problem)

Principles: one hand points, the other commands; the screen tells you what each button does;
the game never needs precise clicking; mouse and pad can be mixed, and the UI follows the last
one used.

- **Pointing:** a virtual cursor on the right stick (accelerating, with a slow precision zone)
  and the right trackpad as a true mouse. Snapping: the cursor sticks gently to units, buildings
  and resources under it (a magnet radius scaled by zoom), so selecting a single frog is easy.
- **Camera:** left stick pans (speed by zoom), clicking it centres on the selection; triggers or
  a held bumper + stick zoom.
- **Selecting:**
  - A: select what's under the cursor; hold A and move: a selection box.
  - Double-tap A: all of that kind on screen.
  - Quick select by type on the d-pad: idle worker (d-pad down, as the idle button), all
    soldiers, the Town Center, cycle buildings.
  - Control groups: hold a back button + d-pad direction to assign, tap to recall (8 groups).
- **Ordering:**
  - B (or the right trigger): the smart order under the cursor (move, gather, attack, build,
    reseed...), exactly as right-click does; holding it shows the order before it's given.
  - Y: attack-move; X: stop.
  - Shift-queue: hold the left trigger while ordering (as shift).
- **The command panel:** a radial menu (hold the right bumper): the selection's buttons around a
  wheel, chosen with the right stick, groups as rings (Train, Research, Build civilian/military).
  The panel at the bottom still shows everything, with the pad's glyph on each button.
- **Placing buildings:** the ghost follows the cursor and snaps to the grid; A places, B
  cancels, a bumper rotates gates; walls drag from A-hold to release.
- **Menus and lobby:** full focus navigation (d-pad/stick moves focus, A presses, B backs out),
  the dice on a button (X: roll), the prompt box opens the on-screen keyboard (Steam's, via
  `DisplayServer.virtual_keyboard_show`) with the dice as the no-typing path.
- **Prompts:** button glyphs drawn by us (our own art, no platform logos), shown on buttons,
  tooltips and the opening tips, swapped when the last input changes (pad vs mouse).
- **Feel:** short rumble on order acknowledged, under attack, age reached (optional, a setting).

## UI on a 7" screen

- The UI size setting (40-100%, `src/view/ui_scale.gd`) gets a Deck default: the Deck reports
  density 1, so today it would draw at the smallest size; detect the Deck (or a small, close
  screen) and default larger (about 1.4-1.6x of the design size), then check every screen at
  1280 x 800: lobby, HUD, command panel, tooltips, tech tree, loader, end screen.
- Hit targets at least ~9 mm on the touchscreen if touch is supported (stretch goal: tap to
  select, drag the minimap).
- Text: nothing below a readable size at arm's length; the theme's type scale gets a "handheld"
  step.

## Performance on the Deck

- Measure: the sim tick (`tests/test_sim.gd`, `tests/sim_profile.gd`, the 2v2 map with four bots),
  frame time and draw calls (`tests/art_bench.gd`, `tests/town_bench.gd`), the first bake
  (`tests/art_bake_time.gd`), memory.
- Likely work: the bake's per-pixel GDScript (ground shadows, pixelize) moved to a shader or
  native code (the loader agent's note); a lower simulation budget per tick check for slower CPUs
  (the tick budget decision from milestone 16 feeds in); the fog and minimap redraw rates;
  culling off-screen units and props.
- Battery: cap the frame rate in menus, pause rendering when the game is paused, a 40 fps mode.
- Suspend/resume: the Deck sleeps mid-match; on wake the match pauses (against the AI) and audio
  recovers.

## Plan

1. **Approvals and a first build.** Dominic's yes to the export templates download; a Linux
  export preset (an `export_presets.cfg` already exists in the working tree, untracked: check
  whose it is); run the build on the Deck as a non-Steam game (Desktop mode copy, or Steam's
  "add a non-Steam game"); first impressions and measurements with Steam Input's default
  desktop layout (trackpad as mouse).
2. **Determinism and performance check.** `test_sim` hashes on the Deck vs the Mac; the benches
  above; decide the renderer and the frame-rate target.
3. **Input layer.** One input map (Godot InputMap actions) for mouse/keyboard and pad, the
  virtual cursor with snapping, camera on the left stick, last-input detection that switches
  prompts.
4. **Selecting and ordering on the pad.** A/B/X/Y, selection box, quick selects, control groups,
  shift-queue on a trigger, placing buildings and walls.
5. **The radial command menu** and glyphs on the panel.
6. **Menus and lobby** with focus navigation, the dice on X, the on-screen keyboard.
7. **Handheld UI size** and a 1280 x 800 pass over every screen.
8. **Performance work** from step 2's numbers; battery and suspend.
9. **Steam Input config:** a default controller layout we ship (so Steam doesn't override our
  pad scheme with mouse emulation), with the trackpad still a mouse.
10. **Exit check:** Dominic's full match on the Deck, pad only.

## Open questions for Dominic

1. The export templates download (about 1 GB): yes?
2. Is there a Deck to test on, and can it reach this Mac (SSH or a shared folder) so agents can
   copy builds and read logs? Or does Dominic copy builds over and report?
3. Touchscreen support: in this milestone or later?
4. A Steam release isn't in scope here (Steamworks, store page, achievements): later.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Approvals and a first build on the Deck
- [ ] 2. Determinism and performance check
- [ ] 3. Input layer
- [ ] 4. Selecting and ordering on the pad
- [ ] 5. Radial command menu, glyphs
- [ ] 6. Menus and lobby on the pad
- [ ] 7. Handheld UI size, 1280 x 800 pass
- [ ] 8. Performance, battery, suspend
- [ ] 9. Steam Input default layout
- [ ] 10. Exit check
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `../backlog.md` §0 (export build, Linux determinism check), `m19-ui.md` (theme, UI size),
  `m16-sieges.md` (the tick budget decision)
