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

## Controller design: true controller support (Dominic, 2026-10-13)

Dominic: "touch screen no; I would go for controller buttons support like the console RTS games:
you hold a button and it shows a big circle for selecting units. Stuff like that. So true
controller support. We then need to keep the UI readable, and not getting in the way." Designed
for the pad first (not a mouse emulated on sticks); the mouse and keyboard game is unchanged.

Principles: a reticle at the screen's centre-ish that the camera and selection work around; one
button per common job; selection by area, not by precise pointing; menus that come up when held
and vanish when released; the screen stays the battlefield.

- **The reticle and camera:** the left stick moves the camera (and the reticle with it, as one);
  the right stick nudges the reticle off centre for fine aim; clicking the left stick centres on
  the selection; the triggers zoom. The reticle snaps to what's under it (unit, building,
  resource) so a single target is easy.
- **Selecting by area (the big circle):**
  - Tap A: select what's under the reticle (double-tap: all of that kind on screen).
  - Hold A: a selection circle grows from the reticle while held (and follows it as you move),
    taking every unit of yours it touches; release to keep them. A short hold selects a squad,
    a long hold a crowd.
  - Right bumper: all your soldiers on screen; double-tap: all your soldiers anywhere.
  - Left bumper: cycle the selection's kinds (only the spears, then only the archers...).
  - D-pad: idle worker (down), next Town Center / building (up), control groups (hold a back
    button + d-pad to assign, tap to recall).
- **Ordering:**
  - X (or right trigger): the smart order at the reticle (move, gather, attack, build, reseed,
    pen), as right-click does; Y: attack-move; B: back / deselect.
  - Hold the left trigger while ordering: queue (shift).
  - Stances, stop and specials on the radial (below).
- **Radial menus (hold, pick, release):**
  - Hold the right bumper with a selection: its commands on a wheel (train, research, age up,
    stances, stop), picked with the right stick, released to choose; groups as tabs on the
    wheel's rim, switched with the left/right bumpers while held.
  - With workers selected: the build wheel (civilian / military pages), then the ghost to place.
  - With nothing selected: a global wheel (find idle workers, select all army, go to Town Center,
    tech tree, pause).
- **Placing buildings:** the ghost sits on the reticle and snaps; A places, B cancels, the left
  bumper turns gates; walls: hold A at one end, move, release.
- **Menus and lobby:** focus navigation (d-pad/stick moves, A presses, B backs out); X rolls the
  dice; the prompt box opens the system's on-screen keyboard, with the dice as the no-typing path.
- **A HUD out of the way:** in pad mode the bottom command panel shrinks to a compact strip (the
  selection's portrait, health and queue only) because commands live on the radials; it can be
  hidden entirely with a toggle. Button glyphs (our own art) on everything that has a shortcut,
  swapped when the last input changes (pad vs mouse). The minimap stays, smaller.
- **Feel:** a short rumble on order acknowledged, under attack, age reached (a setting).

Touchscreen support is out (Dominic).

## UI on a 7" screen

- The UI size setting (40-100%, `src/view/ui_scale.gd`) gets a Deck default: the Deck reports
  density 1, so today it would draw at the smallest size; detect the Deck (or a small, close
  screen) and default larger (about 1.4-1.6x of the design size), then check every screen at
  1280 x 800: lobby, HUD, command panel, tooltips, tech tree, loader, end screen.
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

1. **A first build.** Export templates installed; a Linux preset in Dominic's
  `export_presets.cfg` with SSH remote deploy; the Deck on SSH with this Mac's key; the build
  added to Steam as a non-Steam game; first impressions and measurements with Steam Input's
  default desktop layout.
2. **Determinism and performance check.** `test_sim` hashes on the Deck vs the Mac; the benches
  above; decide the renderer and the frame-rate target.
3. **Input layer.** One input map (Godot InputMap actions) for mouse/keyboard and pad,
  last-input detection that switches between the mouse HUD and the pad HUD.
4. **Selecting and ordering on the pad.** The reticle, the growing selection circle, quick
  selects, control groups, the smart order, queueing on a trigger, placing buildings and walls.
5. **Radial menus** (commands, build, global) and the compact pad HUD; our own button glyphs.
6. **Menus and lobby** with focus navigation, the dice on X, the on-screen keyboard.
7. **Handheld UI size** and a 1280 x 800 pass over every screen.
8. **Performance work** from step 2's numbers; battery and suspend.
9. **Steam Input config:** a default controller layout we ship (so Steam doesn't override our
  pad scheme with mouse emulation), with the trackpad still a mouse.
10. **Exit check:** Dominic's full match on the Deck, pad only.

## Building for the Deck (answers, 2026-10-13)

- **Export templates:** Dominic installs them from the Godot editor (Editor > Manage Export
  Templates > Download and Install, for 4.7.2); the export preset he started
  (`export_presets.cfg`, macOS) gets a Linux/X11 preset next to it.
- **Getting builds onto the Deck (the usual way):** Desktop Mode on the Deck, set a password
  (`passwd`) and turn on SSH (`sudo systemctl enable --now sshd`); then from the Mac, builds go
  over with `scp`/`rsync` and run over `ssh`, logs come back the same way. Godot's Linux export
  preset has a one-click remote deploy over SSH (Remote Deploy: host, user, key), which runs the
  game on the Deck straight from the editor. Add the build to Steam once as a non-Steam game so
  it runs in Game Mode with Steam Input. (Valve's SteamOS devkit client is the heavier
  alternative; SSH is enough for us.) An SSH key from this Mac on the Deck lets agents copy builds
  and read logs without a password.
- **Touchscreen:** no. **Steam release:** later.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Approvals and a first build on the Deck
- [ ] 2. Determinism and performance check
- [ ] 3. Input layer
- [ ] 4. Reticle, selection circle, ordering on the pad
- [ ] 5. Radial menus, compact pad HUD, glyphs
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
