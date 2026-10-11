# Art and UI track (runs alongside the milestones)

**Status:** A1 in progress (2026-10-11)
**Why this file:** the art pass (`art-pass.md`) chose the direction and shipped the vertical
slice, but what art and UI each milestone needs wasn't laid out (Dominic, 2026-10-11). This track
says what's expected and when. Each stage runs in parallel with its milestone, often by a
separate agent, and must be done before that milestone closes.

Rules for every stage:
- The look is set: stylised, outlined units and realistic static props and buildings, baked
  from 3D with authored textures (see `art-pass.md` and decisions D-042 to D-053). Match how
  things are *built*, not just their colours.
- Everything shows in the real game view (`scenes/sim_debug`, through `src/view/art/`), not
  only in a demo scene.
- Pictures go in the archive as you go.

## A1 = milestone 5 (art rework)
- [x] Realistic static props: bug bushes, rocks; no outline on props
- [ ] Variety: more baked variants of each static prop (bushes, rocks, reeds, doodads), picked per
  tile, so neighbours differ
- [ ] Reeds in the realistic prop style
- [ ] Fix: winged units' far wing points forward over the head (Dominic's screenshot)
- [ ] UI pass 1:
  - a bigger build/train queue;
  - unit icons and portraits generated from the baked units (each race's real sprites), used in
    the train buttons, the queue and the selection panel;
  - cursors per action (move, gather/forage, chop, build, attack, rally), from authored art.
- [ ] Animation pass 1: work animations per job (forage, chop, build), walk cycles that suit
  each creature (two legs, four legs, six or eight legs, flying), idle variety
- Combat visuals are built with milestone 4 itself, not in this track: attack lunge, projectiles,
  hit flash, death poses, unit card.

## A2, with milestone 7 (progression)
- Barracks, Stable and Watchtower for every architecture (thatch, junk, stone, tent).
- Age-up shown on buildings: an upgraded look for age 2.
- Research and age-up buttons with generated icons; a building panel with icons.

## A3, with milestone 8 (AI and match flow)
- Race select screen and main menu. The UI picks up the race's culture (colours, frames, small
  ornaments), as noted in the backlog.
- Race cards with portraits; win and lose screens.

## A4, with milestone 9 (fog and juice)
- The fog of war look; minimap art.
- Juice: dust when walking, impact sparks, falling arrows, polished hit flash and death poses.
- Trees and forests if wood moves beyond reeds; placeholder sound effects.

## A5, with milestone 10 (playtest)
- The full art review with Dominic (noted in `m4-combat.md`), then fixes.
- Spooky and forest architecture.
- The rest of `backlog.md` §9 (art review leftovers).
- Performance check: 200 units at 60 fps in the real view.
