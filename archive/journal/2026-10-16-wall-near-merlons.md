# 2026-10-16: A wall's near merlons on the wrong edge

**Milestone:** 20 (Steam Deck), a bug from Dominic's Deck photo (walls are milestone 16's)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic, from the Deck: "walls seem to have one side with protection and one without. And our guys overlap
it", and then "the person's shadow is sticking through also". A stone wall running along sim y had merlons on
its far edge only; the men up on it stood on a bare near edge, their shadows hanging over it.

The bakes were right: a walkway piece's near merlons are baked as a layer of their own (milestone 16, so men
stand between them), and both were there. The game drew that layer with a plain `Sprite2D`, which Godot
centres, while every other building sprite is placed from its corner. So the near merlons sat half a sprite up
and left of where they belong. Along x that slid them along the wall and nobody saw; along y it put them
on the far edge. The walls' join check didn't catch it because it lays the baked looks out itself. It now
also checks the game's own sprites for a tile in each direction (and fails on the old code).

A man's shadow up on a wall is now under half its ground size (`UnitView.set_perched`), so it stays on the
walk. (The first try did nothing: a unit view that rebuilt made a new shadow and kept the old "perched" flag.)

## Pictures
- `20-wall-y-run-near-merlons-missing-before.png`: the far edge doubled, the near edge bare, an archer on it.
- `21-wall-y-run-near-merlons-after.png`: merlons on both edges, the archer between them.

## Funny moments
- The near merlons were there all along, standing on the far side of the wall.
