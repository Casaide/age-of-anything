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

## Round 2: slimmer, with signatures (a fresh start on the builder)
Dominic on round 1: "Focusing on fidelity and keeping the key parts of each creature easy to see. Feel like we're going
too big with the voxels. Rat just becomes a big bulky block with massive muscles." The composed rats were the bar.

What made the bulk: every part melted into its neighbours over 2.2 body units (fat joints, "muscles"), a whole tunic in
team colour over everything (a red block), and one generic biped bent into every creature. `src/view/voxel.lobster` is
rewritten (Claude): each creature has its own builder with its signature parts made big, and the melt is 0.8.
- Rats: small and hunched, pear-shaped (narrow shoulders, round belly, big haunches), thin shins on pink feet, a long
  pointed snout with a pink nose, big round ears pink inside, a beady eye, a long bare tail trailing in an S. No tunic:
  the team is a scarf (and the shield face); a short vest in team colour is drawn as the other option (picture 22).
- Frogs: squat and wide, knees folded up past the body, long webbed toes, a wide flat head with a mouth seam, big gold
  eyes bulging off the top.
- The cat: 1.45x bigger than the rat-sized rider, its head held low and well out in front, so the face shows facing down.
- Fur flecked by a hash of each voxel (it turns with the unit, like a texture); a softer line where a limb crosses the body.
- Arms by two-bone reach to where the kit puts the hands, so a spear, shield, bow or axe sits in the hand in any pose.

Speed: round 1 drew each facing by walking a ray per pixel (0.34 s of the 0.42 s a pose). Now each part is listed in
the 4-voxel blocks it touches (a voxel measures only its neighbours), normals come from the stored distances, the
surface is listed once, and each facing splats the surface voxels with a depth test: 21 poses, 56 cells in 0.5 s. In
the match, cells are cropped to what's drawn and packed into shared atlases, and types that look alike (most age
upgrades) bake once: 36 types (24 looks) in 8 s, against 287 s at this resolution in round 1. Still too slow for a
match start; next.

Bugs: round 1's stray blue and green pixels on the cat were colours shaded past 1.0, which wrap round when the game
makes its texture (a bright pink came out cyan); the sheet tool clamped, so they only showed in game. Clamped now. The
facings were a step off the composed ones (the composed f1 faces the camera); the game now maps them by (d + 3) % 8.

Shadows (Dominic: "those rats are looking quite good, if we have some shadows on the model, and on the ground... we
might be close"). Claude's answer: bake them, they cost nothing at run time. On the body, each surface voxel looks a
few steps towards the light through the grid (an arm or the rider shades what's behind it), plus occlusion from 14
neighbour taps (creases darker). On the ground, the silhouette projected along the world's sun (upper left, as the
props' and buildings'), baked as its own frame and drawn in the ground layer under every unit, so it matches the town
and never darkens another unit (picture 20 off and on, 23 in the match). The bake went to 11.7 s with them.

Pictures: 18 (composed against voxel, game size), 19 (close), 20 (shadows off and on), 21 (walk, thrust, chop),
22 (the team as a vest), 23 (in the match, with shadows).

## Round 2b: a proper Roman, darker shade, straighter cat legs
Dominic on round 2: "humans are the worst part. But generally really good! The cat's front legs look weird, bent in the
middle. And rats' eyes are too big." Then: "shadows look good, just can we get some shadows on their bodies? They look
like bright light on them", and on the human: "part of the problem: you're comparing with a Roman. Our guy has tiny tiny
sword, tiny shield, really long limbs. Start by trying to make a perfect Roman."
- The Roman (Claude): a soldier's build (sturdier limbs, hip at 19.4 of about 41), a tunic in team colour showing as
  sleeves and a hem under eleven leather strips, a galea (a bowl that leaves the face open, a brow, cheek and neck guards,
  a crest in team colour), lorica bands over dark leather at age 3 or a bronze cuirass at age 2, a big curved scutum
  (three panels: a box shape was added to the builder), a gladius bigger than life with a bronze guard and pommel. The
  game reads galea, lorica/bronze/leather, scutum, gladius and pilum from the recipe's parts (picture 26).
- The body's light moved up and to the sun's side, the bands spread wider: the far side and undersides go dark, and the
  self-shadows (a rider on a cat, an arm on a chest) show.
- The cat's front legs bend at the elbow backwards and nearly straight, as a cat's do (the horse's too); rats' eyes smaller.
- The concept sheet's columns are wider so the ground shadows aren't cut off.
Pictures 24 (all, close), 25 (game size), 26 (the Roman against the composed one), 27 (a battle in the match: the cat,
a rat, Roman spearmen). The bake is 17.6 s for 36 types now (26 looks; the Roman kit has more parts): too slow, next.
Dominic: "much better direction".
- Dominic: "humans still very bulky". Slimmed (Claude): limbs about a fifth thinner (thighs 1.75, shins 1.4 to 0.95,
  upper arms 1.3), waist 2.2 and chest 2.75, shoulders 3.0 out, the hips closer, the skirt, belt, strips, armour,
  neck and helmet pulled in to match. Now about the composed legionary's width (picture 28).

## The bake at the match start
Measured per look (a Roman, 17 poses): the fill 0.89 s, the 8 facings drawn 0.18 s, the ground shadows 0.06 s; the
occlusion pass and function calls cost next to nothing. The fill measured every part listed in a block's loose
bounding-box bin at every voxel; now each block's centre test also keeps only the parts close enough to matter in
it: 0.47 s, the picture identical (about 55,000 voxel measurements a pose at 7 parts each). The match start went from
17.6 s to 13 s for 26 looks.
The rest is just how many poses there are, so the looks are now cached as the composed parts are: each look baked into
an atlas of its own, kept in bake_cache/ as a PNG and a manifest, keyed by the look and a hash of view/voxel.lobster
(any change to the builder bakes again; no version number to remember). The first start with a race bakes (17.5 s,
writing the PNGs included); every start after loads in 5 ms. A composed match takes about 15 s to start either way.

## The same match moments, composed and voxel (round 2)
The battle at 13:00 (`at:780 speed:8 follow`) and the town at 1:30 (`at:90 speed:4`), "sewer rats|romans": pictures 29
and 30 (the battle, whole and close), 31 and 32 (the town, whole and close). The cat with its rider, the rats with their
ground shadows, Roman spearmen and clubbers.
- Bug caught in the paired crops: the voxel rats faced another way than the composed ones at the same moment. The
  composed units in the match face the way they move on screen (or their work point), which `dir_of` bins; the voxel
  facing 2 faces screen right, so the game wants (d + 2) % 8, as round 1 had. The (d + 3) of round 2 matched the
  concept sheet's columns (the composed rigs' facings), not the game. Back to + 2; the sheet keeps its own order.
- Still missing in the voxel trial: the dead (a composed unit falls and lies; a voxel one just goes), wild animals, and
  the early Romans' look is mostly team red (a whole tunic) where the composed ones show bare skin and a dark kilt.
