# 2026-11-10: Feet that keep to the ground

## What happened

Dominic: "also concerned not all units their velocity matches their walking animation maybe". He was right. The walk frame
already stepped by the ground a unit covers, so the cycle rate followed its real speed, but the cycle's length came from a
hand-set `reach` per body that had drifted from the legs' `stride`, and it ignored the drawn size from the 2026-11-06
rescale (and a mount's was divided by its rider's size). A spider's planted feet covered 43% of the ground it walked and
skated forward; a newt's 212%, paddling backwards. Only the pony and the sheep were right, by luck.

Claude wrote `src/walk_check.lobster` first (red on main for every body but those two), then took the cycle from the legs
(`vx_walk_cycle` in `view/voxel.lobster`: four strides at the drawn size, the mount's for a rider). Feet without a gait
also moved on a sine, so even at the right cycle a planted foot sped up and slowed down against the ground (41% of a step
between baked steps); now every planted foot goes back at a steady speed, as the human's gait already did. `reach` stays
only for legless bodies (wings, wheels).

## Pictures

- `images/2026-11-10/90-walk-cycles-feet-vs-ground.png`: each body's feet against the ground before and after, and one
  spider foot through its stance.

## Ideas parked

- Wings and wheels still beat by `reach`; a cart's wheels could roll by their radius the way belts go by their links.
