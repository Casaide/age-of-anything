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

**Step 2 (after the pick):** shared groundwork: palette/team-mask shader, atlas plus pivots in
`parts.json`, and the draw-call check at 200 units.

**Step 3:** vertical slice: the Frogs vs Rats roster, buildings and terrain in the chosen style.

## Checklist
- [x] Style sampler: five panels, single-style view, captions with honest notes
- [x] Archive: sampler pictures, journal, decisions, timeline
- [ ] Dominic picks a direction
- [ ] Groundwork: shader, atlas, draw calls
- [ ] Vertical slice

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

## Changes from the original plan
- The original plan assumed the painterly direction. Direction is open again (2026-10-11):
  Dominic found the placeholder style "surprisingly cute" and asked for samples of every option.
