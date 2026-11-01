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

## Round 3: the whole tunic, and the head rebuilt
Dominic picked the whole tunic in team colour. On the head ("Head is weird and some angles", his close-up of facing
3): the hair was a capsule pushed back and up, so it peaked like a crest, and the face had nothing on it. Now the head
is a little taller than wide with the jaw forward, the hair a cap round the top and back, a small nose, a pixel for
each eye, and a shorter neck (pictures 04, 05).

## Round 4: more units and other races
Dominic: "let's try more units before we commit, and other races". The prototype now makes a race from a handful of
numbers (hip height, leg lengths, waist and chest, lean, arm length, size, colours, a head: human, rat, frog or bear;
a tail) and a unit from a race and a kit (axe, spear, sword, bow, shield, helmet, armour; on foot, on a horse or as a
centaur). Twelve units, three of them walking, in 10.6 s (picture 06 at 3x, 07 at game size).

Caught on the way: the bear's helmet and armour melted into one white bullet over a head sunk in its chest (the neck
now grows with the chest, the armour stops under the shoulders), and the rat's pink ears read as a pink blob on its
head (fur ears now).

## Round 5: faster, crouched frogs, rat snouts, hair
- "12s seems quite slow": the grid is now tested in blocks of 4 voxels first (air skipped, solid filled whole) and
  each ray walks voxel by voxel instead of creeping in quarter steps: twelve units in 1.7 s, the picture the same.
- "Frogs' spears also parts missing": a shaft thinner than a voxel filled in pieces; gear is now at least a voxel thick.
- "Should we just support smaller voxels?" Claude's answer: no; one voxel per art pixel is what makes it read as pixel
  art, and anything thinner than a pixel can't show at game size anyway. Thin gear is thickened instead.
- "Rats and frogs missing some signature ... nose too small for rat. Frog we've now gone bipedal which isn't as good":
  rats have a long snout and a big pink nose; frogs crouch on folded legs (knees up and out, long webbed feet), lean
  forward, and lost the belt that read as a shell.
- "Humans look like they're balding": the hair is a crown down to just above the eyes and down the back (picture 08).

## In a real match: the `voxels` option
Dominic: "get some pictures of a real game and battle so we can decide on voxels or not". The voxel builder moved to
`src/view/voxel.lobster` (names `vx_`), and `src/game/voxel_units.lobster` reads each unit type's race and kit from its
recipe (body: rat, frog, bear, else human; the right hand's spear, sword, bow or anything else as an axe; a shield, a
helmet, armour; a mount as a horse, a centaur body), bakes an atlas per type at the match start (8 facings standing,
walking, attacking, and chopping for workers), and draws them as whole-unit frames, the team key in magenta for the
sprite shader. `./play.sh none lobby "races:sewer rats|romans" watch voxels` plays one.

First try drew them at one voxel per baked pixel: half the composed units' size. Drawn 2.2x with nearest filtering
(chunky pixels) they match. The same match, same moment, composed and voxel: pictures 10 (battle, close), 11 and 12
(the battle), 13 and 14 (the town at 1:30).

Gaps in the trial: every mount is a horse (the rats' cat too), the Romans' look comes from the generic kit (red tunic,
helmet), no wild animals or dead bodies yet, and baking 36 types took 38 s.

## Double resolution, and a cat
Dominic on the first in-game pictures: "that's looking pretty bad so far. The rat on a cat is 100% unclear when
facing down. I think we need smaller voxels to get some more detail? The rats were looking really really great before
this." So: two voxels a body unit (a voxel a baked pixel, drawn at the composed units' size without chunky pixels),
and a cat to ride (black, white chest and paws, yellow eyes, a tail curled up) instead of every mount being a horse.
The rats read better up close (ears, snout, eye; picture 17), but in the match (15, 16) the composed rats still have
far more character than the voxel ones, the cat came out with odd blue and green pixels, and the bake took 287 s for
36 types (38 s at one voxel a pixel).
