# Milestone 5: Art rework

**Status:** built (2026-10-11), waiting on Dominic's sign-off. Started by a separate agent in its
own worktree (merged when it hit the usage limit); Claude finished it.
**Exit criterion:** Dominic signs off the look in the game view (sim_debug) and the Race Lab.

## Scope
The art and UI track's stage A1. The checklist lives in `art-ui-track.md` (A1), kept current by
the agent:
- realistic static props, terrain, roads and houses;
- prop variety;
- resource used-up stages and building construction stages;
- gear for creatures with no hands;
- rider and mount combinations;
- the building sort fix;
- a UI pass: queue, portraits generated from the baked units, action cursors;
- an animation pass;
- the old art gone from every game scene, including the Race Lab;
- the style sampler retired.

## Why it's a milestone
Dominic (2026-10-11): the art and UI work wasn't clearly laid out against the milestones. This
round is big enough to be a milestone of its own, running alongside milestone 6. The later art
stages (A2-A5) stay in `art-ui-track.md` and run with milestones 7-10.

## Results
Everything on the A1 list is built (see `art-ui-track.md`). Highlights, with pictures in
`archive/images/2026-10-11/`:
- Static props and buildings in the genre's realistic look: bug bushes, reeds, stone, roads
  and trails, terrain (68, 81, 83, 84); construction and used-up stages (68, 70).
- Six architectures: thatch, junk, stone, tent, and per creature reed (frogs) and mound (bugs)
  (94-96).
- Units: arms posed for their weapon, harnesses for armless bodies, riders that cling (74-79);
  real textures mapped in world space (88-91); bolder wings, folded on mounts (92-93).
- UI pass 1: portraits from the baked units, a big queue, authored cursors (71-73).
- The old art is gone from the game scenes and the Race Lab (63); the style sampler is history.
- Bake time: about 10 s for all six architectures' buildings with their stages
  (`tests/art_buildings.gd`).

**Waiting on Dominic:** the look sign-off in `sim_debug` and the Race Lab (the exit criterion).
