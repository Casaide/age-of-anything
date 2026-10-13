# Bears (concept round B1, 2026-10-13)

Dominic's direction: bears as a race on two legs, armoured, more like the Greeks: dignified and
intelligent, the smarter counterpart to the rats. Some races can ride them on four legs. Some bears
are bigger still on two legs, polar bears or older bears, as a natural giant line.

Everything here is built with the new creature kit (`scenes/art_pixel/creature_kit.gd`) and drawn
by the new sheet tool from `tests/sheets/bears_b1.json`. Every row passes the placement check, and
the bear units are in `tests/placement/cases.gd` too. **Nothing is in play.** The data waits in
`data/later/bears.json`: kits, parts, creatures, skins and the words bear, bears, grizzly and polar.
No creature in `data/creatures.json` is a bear and no word in the lexicon points to one.

Each sheet puts a Roman worker, a rat worker and a frog worker at the left for size. The rows are:
- three builds of the bear hoplite
- the bare-headed worker
- the four-legged mount, ridden by a Roman (a rat in the right-hand columns)
- the two giants, at the large line's 1.5x

| Sheet | |
|---|---|
| `bears_b1_facings_3x.png`, `bears_b1_facings_1x.png` | standing in 8 facings, close up and at game scale |
| `bears_b1_walk_3x.png`, `bears_b1_walk_1x.png` | four of the eight baked walk steps, in three facings |
| `bears_b1_idle_3x.png`, `bears_b1_idle_1x.png` | idle: the bipeds stand at ease, the mount sits down |
| `kit_cat_facings_3x.png` | the kit's proof: the game's cat beside the same cat rebuilt through the kit |

Re-render with:
`godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/bears_b1.json out_dir`

## Size

A standing bear (kit scale 1.15 to 1.25) stands a head taller than a human, and its body is about
twice as wide. A worker is the same size, so buildings, siege crews and gear would need sizing
before bears play. The giants (1.5x on top of that) stand about twice a human's height and read as
the biggest thing on the field. The mount (scale 1.3) is a little longer and lower than the pony.
A Roman rides it at the usual 0.8. A rat on it looks tiny, which is a joke that works.

## The options

**A. Brown bear (grizzly build).** A shoulder hump, a dished face (a step between the forehead and
the muzzle), a pale brown muzzle and round ears. In the hoplite kit it carries a dory, a hoplon, a
bronze cuirass and the bear helmet (below). This build reads most clearly as a bear: the hump and
the heavy shoulders hold their shape at game scale in every facing.

**B. Black "moon" bear.** Slimmer, with no hump. It has bigger round ears, a straight tan muzzle and
a cream crescent on the chest. Near black, it is the strongest silhouette on the green ground. The
crescent is lost under the cuirass and only shows on unarmoured units (workers). The tan muzzle
under the bronze helmet is what reads at 1x.

**C. Polar bear.** A long neck carried forward, and a long, narrow head with a roman nose and small
ears. Cream fur, on legs that lean further forward. It is the most distinct at a glance: white
against the green with the long head. It reads as a different animal from A and B, which helps if
the polar bear is the giant.

**Helmet.** The stock Greek helmets fit (row 2: `helm.bronze`), but on a bear they hide the ears,
so the head becomes a bronze dome with a snout. The concept helmet `helm.bear_crest`
(`scenes/art_pixel/bear_concepts.gd`) is a deep bronze bowl with two round ear cups standing up
where the ears are, cheek guards behind the eyes, a neck guard and a tall team crest. At 3x the ear
cups keep the bear's round-eared outline. At 1x it is a bright bronze head with a crest, and you
can't tell it apart from the stock helmet. Either way the bronze is the brightest thing on the
unit, so the bears read as "the armoured Greek ones", which is the brief.

**Worker.** A bare-headed brown bear with a team kerchief and the culture's tool. It shows the head
best: round ears, the muzzle and the dished face.

**Mount.** The brown bear on four legs. It has plantigrade feet (soles flat, claws), a shoulder
hump, a stub tail, a saddle cloth in team colour with a girth and harness, and a bridle-free head.
It walks in the cat's four beats, with heavier, slower steps. Idle, it sits back on its haunches in
three steps, like the cat. From every side it is plainly a bear carrying someone. The black bear
mount (row 7) is the same body in the black coat.

**Giants.** The large line is a giant of the bear race (`giant_ok`, the generator's x1.5):
- **Polar** (row 8): the polar build in the hoplite kit.
- **Old grizzled bear** (row 9): build A in a silver-tipped coat, with a xiphos and no shield.

The polar giant is the stronger read, because it is a different animal as well as a bigger one.
The old bear is the better story (a veteran), but it looks like a big brown bear.

## What reads at game scale (1x)

- Bear versus human: the bulk, a body twice as wide on short legs, and the head held forward.
- The bronze helmet and cuirass, the team crest and the shield.
- Brown, black and polar are told apart by their colour at once, and by the hump and head shape at a second look.
- The walk shows as a short, heavy rolling step. The "at ease" idle only moves the feet apart and is
  hard to see at 1x. The mount sitting down is obvious.
- What doesn't read at 1x:
  - the black bear's chest crescent (under armour)
  - the dished face under a helmet
  - the ear cups compared with the stock helmet

## Recommendation (Claude)

- Make **A (brown, with the hump) the bear race's soldier**, in the hoplite kit with the ear-cup
  helmet. It is the clearest bear and the most "dignified Greek".
- Make **B (black) and the grizzled coat skins of the same race**, as the rats have grey, brown and
  white.
- Make **C (polar) the giant line**, so the big one is visibly a different, rarer bear.
- Keep **the four-legged brown bear as the mount**, in brown and black coats, for cultures that ask
  for it (northern or forest cultures, or by name: "romans riding bears").

## Questions for Dominic

1. Which build is the bear soldier: A brown, B black or C polar? Or skins of one build?
2. Is the polar bear the giant, or the old grizzled bear (or both, by culture)?
3. Is the bespoke ear-cup helmet worth having, or should the stock Greek helmets be used?
4. Size: is "a head taller and twice as wide" right for a bear soldier? If so, buildings and siege
   crews need a bear size.
5. Who rides bears? Only by name, or does a culture get the bear as its family mount (northern,
   forest)?
6. Do bears get their own culture (dignified, Greek-like, building their own impressive halls,
   D-081), or do they borrow the hellenic one?
7. The idle on two legs moves only the feet (worn armour has to stay fitted). Should a bear drop
   to all fours or sit back when idle? That needs worn armour baked per pose first.
