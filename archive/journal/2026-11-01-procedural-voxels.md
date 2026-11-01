# 2026-11-01: procedural voxels, a first try

## What happened
Dominic, after the AI-art research: "I'm not interested in big tools. I'd rather do simple." His first ever experiment
for this game was a hand-made voxel person, so: voxels. Then: "We could even lose the models and just procedurally
generate the voxels?" and "Voxels can give us the pixel look for free."

Claude wrote `src/voxel_proto.lobster`: a body as capsules on a posed skeleton, melted together (a smooth minimum, so no
ball seams), filled into a voxel grid at one voxel per art pixel, and drawn in the 3/4 view by a ray per pixel. The
shading uses the shape's smooth normal (the grid's stairs speckled it), in four bands, with a dark outline. A heroic
human woodcutter and a centaur (a horse's barrel and four legs, a man's torso where the neck would be), standing in 8
facings and walking: 32 sprites in 1.7 s, no outside tools.

The centaur has its four legs in every facing (the sphere-built one shows none behind). Hands can't come off: an arm
is one melted shape, and the axe is a hard part at the hand.

## Pictures
- `archive/images/2026-11-01/01-procedural-voxel-human-and-centaur.png` (4x), `02-procedural-voxels-game-size.png`.

## Next
Concepts for Dominic: the shading's contrast and light, outline or not, faces and detail at this size; then a check in
voxel space (pieces, feet on the ground, legs counted) and how voxel units would plug into the composer.

## Round 2: a slimmer chest, team colour as trim, sash or tunic
Dominic: "Those are great! The chest is maybe a bit too thick." On team colour: the game already recolours one region
(the fidelity round said to shrink it over natural colours), and the genre mostly colours part of the clothes. So the
tunic is undyed now and three looks are drawn: trim (shoulders and belt), a sash, and the whole tunic (picture 03).
