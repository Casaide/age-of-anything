# 2026-10-18: towers you can click, feet inside the hoarding, shadows on the ground

## What happened
Dominic, playing: "i cant manually garisson people in towers?", then "feet sticking out btw" and a
"shadow bug" picture (a tree's shadow across a tower roof). Three view bugs, one session:

- **Garrisoning towers.** The sim and the right-click order were there all along; the right-click looked
  only at the ground tile under the cursor. A tower is one tile drawn tall, so clicking its body hit the
  tile behind it and the units walked there. Selecting already reached the footprint below a roof;
  `building_under` in sim_debug.gd now answers for selecting, right-click orders and the cursor alike.
- **Feet out of wall towers.** A frog on a tower floor had a foot over the stone below the hoarding: the
  only part drawn over perched units was the hoarding. The near corbel band, a skin over the two near
  faces, the arrow loops and the team rag are now parapet too (the tower's front layer). The first skin
  stopped partway down the face and its edge showed as a one-pixel line (not lighting, not soft alpha:
  measured, row 667, 0.13 darker); whole faces end on the tower's own edges and the line is gone. The
  wall join check passes all 23 fixtures. (Its stand-ins didn't catch the foot: they aren't the units.)
- **Tree shadows over roofs.** Trees bake their long ground shadow into their sprite, which sorts with
  the buildings: a tree in front of a tall tower laid its shadow over the roof. Tree bakes are now split
  (ArtKit `_split_shadow`): the art stays y-sorted, the shadow lies on the flat ground layer.

## Decisions
- No D-number: bug fixes. Units standing in a tree's shade now draw over the shade (as in the genre).

## Pictures
- `03-wall-tower-foot-out-bug.png`, `04-wall-tower-foot-hidden.png` (walljoins scene, 2x).

## Parked
- Dominic: merge standing on walls with garrisoning? Asked, not decided.
- The wall join check could use real unit sprites, not stand-ins, so feet like these fail it.
