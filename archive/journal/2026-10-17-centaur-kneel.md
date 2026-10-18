# 2026-10-17: The centaur's kneel, seen from behind

## What happened
Dominic played a network match (Mac against the Steam Deck) and saw a unit drawn wrong: a man in a blue tunic with
red sleeves on top of a bay four-legged body, from behind, the legs thin and splayed, nothing reading as a horse. He
asked: "i thought our tooling and tests protected against this needing visual checks".

Every standing rider and mount was fine. It was a centaur worker (centaur romans, bay skin) foraging. The kneel to
forage (`UnitView._kneel`, round C1, D-105) is a 2D pose put on the baked sprites: the front legs shorten to the knee,
a copy of each folds back along the ground as its shin, the whole sprite turns about the hind hooves and the human
half leans back. It was drawn side-on in facing 0, a day after the 8 facings came in, and written that way: the
"front" legs were the two furthest right on screen, the shins swung back as if the body faced right, the turn pivoted
on the two legs furthest left. In facing 0 that's right. From behind (facing 5) it folded one flank's pair sideways and
tipped the body over; facing left it folded the hind legs and sank them below the ground. On top of that, the forage
lean every worker does was a turn of the whole sprite in screen space too, so from behind it leaned sideways.

Why the placement check passed: it drew every unit standing and walking only. The 3D check covers the work holds
(the swings are baked bodies), but a pose UnitView makes in 2D on top of the bakes was never drawn in any facing.

Claude fixed the kneel and closed the gap:
- `_kneel` takes fore and hind from the body's model (data anchors, x is forward), and the facing's forward on screen
  from the bake camera (`UnitView.ahead_on_screen`, `side_on`): the shins fold back along the ground in every facing
  (behind the knee and the chest when back is away from the camera), each shin's top pixel on its knee (a leg cut by
  its body shows from below the hip, so the old drop left the shin hanging loose), the turn scaled by how side-on the
  facing is, the chest dropping instead when it's end-on. Facing 0 is the same pose as before (side_on is 1 there).
- A kneeling centaur doesn't also lean and crouch like a standing worker (that moved its hind hooves), and every other
  worker's forage lean is forward in its own facing.
- The 2D check now draws every worker foraging in all 8 facings (`tests/placement/work_2d.gd`): the layering rules hold
  there, and K1-K5 measure a fused mount's kneel against the model and the bake camera (fore legs fold, shins lie back,
  shins on their knees, hind hooves planted, nothing below the ground). A fixture puts the old kneel back
  (`fixtures_2d.gd _old_kneel`): it fails K1, K2 and K4; the kneel as it is now passes them.
- `tests/placement_shot.gd` takes `job:forage` to draw a case at work.

## Decisions
- D-153: workers are checked at work, and a 2D pose on the bakes takes its directions from the facing.

## Pictures
- 12: the bug, the centaur worker foraging in all 8 facings (`placement_shot.gd ... job:forage`); facing 5 is what
  Dominic saw.
- 13: the same after the fix.

## Funny moments
- From behind, the horse half knelt with its left legs and stood on its right, like a dog scratching an ear.

## Ideas parked
- The chores (sweep, sit, chat, graze) and the other jobs (chop, mine, build, till) also lean the whole sprite in screen
  space; only forage is drawn by the check. Chop and the rest use the same lean (now facing-aware); the chores' small
  tilts aren't yet.
