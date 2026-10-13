# Bears (concept rounds B1, B2 and B3, 2026-10-13)

Dominic's direction: bears as a race on two legs, armoured, more like the Greeks: dignified and
intelligent, the smarter counterpart to the rats. Some races can ride them on four legs. Some bears
are bigger still on two legs, polar bears or older bears, as a natural giant line.

Everything here is built with the new creature kit (`scenes/art_pixel/creature_kit.gd`) and drawn
by the new sheet tool, from `tests/sheets/bears_b1.json` for round B1 and `bears_b2.json` for B2. Every row passes the placement check, and
the bear units are in `tests/placement/cases.gd` too. **Nothing is in play.** The data waits in
`data/later/bears.json`: kits, parts, creatures, skins and the words bear, bears, grizzly and polar.
No creature in `data/creatures.json` is a bear and no word in the lexicon points to one.

Each B1 sheet puts a Roman worker, a rat worker and a frog worker at the left for size. The rows are:
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

## Round B3 (2026-10-13): the mount's neck runs into its head; helmets by rank

Dominic on B2: "the snouts look perfect", but "mounted bears I think have broken neck still". On the
B2 mount the head was a separate block sitting low and forward, with a step between the shoulder hump
and the back of the skull: no neck mass joined them, so it read as a head bent off at an angle. He
left the rest to Claude (D-126).

B3 is drawn from `tests/sheets/bears_b3.json`. The B2 rows rebuild B2's numbers as kit variants and
are marked to fail the new head-join rule (the sheet says "fails, as expected"); every B3 row passes
the placement check, 3D and 2D.

| Sheet | |
|---|---|
| `archive/images/2026-10-13/440-bears-b3-mount-neck-into-skull-vs-b2-facings-3x.png`, `441-...-game-scale.png` | standing, 8 facings, B2 above each B3; the polar before and after; the generated line soldier and giant |
| `442-bears-b3-vs-b2-walk-3x.png`, `443-...-game-scale.png` | four walk steps in three facings |
| `444-bears-b3-vs-b2-sit-head-raised-3x.png`, `445-...-game-scale.png` | idle: the mount sitting with its head raised, the bipeds at ease |

Re-render with:
`godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/bears_b3.json out_dir`

**The mount's neck.** The neck is now one thick mass, as wide as the head, from the top of the hump
forward and down into the back of the skull (the kit's new `neck.into`: the neck ends at a point in
the head's frame, wherever the head sits). The top line runs hump, neck, crown, muzzle without a
notch, and the throat runs from the chest to the jaw. The head is baked with the body holding it out
and neither is outlined along the other at the join, so in every facing the head grows out of the
neck instead of sitting on it as a block. It still sits low, at or just under the hump. Sitting, the
head rises on the neck (a little less far back than B2's, so the neck mass doesn't bury the head's
joint); the walk is unchanged, and the rider still sits behind the hump. Brown and black.

**The rule.** The placement check now measures head joins on beasts of four or more legs ("A2 head
joins the neck without a notch", `docs/rendering.md`): the side silhouette's top line from the
withers to the head may dip at most 1 unit. B2's mount dips 1.5 standing and 2 walking; a fixture
puts it back and must fail. Run on every quadruped in the check, it also caught the capybara, whose
big head sat a notch above its shoulders (2 units). It now has the same kind of neck mass into the
back of the head, joined without a line (`446-capybara-head-on-a-notch-before-head-join-rule.png`,
`447-capybara-neck-into-the-head-after.png`). It also caught the kit cat built from primitives, a
comparison not in play, which got a thicker neck into its skull. The pony, newt, cat, beetle,
spider, deer, boar and sheep passed as they were.

**The polar bear's neck** is a little shorter and thicker (D-126), so it reads as a bear rather than
a long-necked animal. Its head sits about half a unit lower and closer to the shoulders.

**Helmets by rank (D-126).** The open-faced cap with the ears out is the line soldiers' helmet
(spear, infantry, skirmisher, archer, mounted archer, scout). The ear-cup helmet is for the giants
and elites (large, unique). Each now comes in later-age versions with better armour and the same
model (`helm.bear_open_2`, `_3`, `helm.bear_crest_3`), and the bear tags favour them. Generated,
bear lines keep their own helmets through the ages instead of switching to the stock Greek ones.
The one exception is the hellenic unique unit, which keeps its theme's Corinthian helmet.

**Bonuses.** Since milestone 14 every race needs bonuses, and the staged bears had none, so every
check that staged them logged errors. As placeholders, the bears are folk (research faster: the
clever ones) and have thick fur (+4 hp a unit, priced through points), until bears go in play.

### Questions for Dominic (B3)

1. Does the mounted bear's neck read right now, from the side and from the back?
2. Should the helmets differ by age as well as by rank (the same model for now), or is the step from
   cap to ear cups enough?
3. The bears' bonuses: folk and thick fur as placeholders, or something of their own?

## Round B2 (2026-10-13): short muzzles, the mount's head low

Dominic on B1: "the big armoured bear looks a lot like one, the helmet sits really well. But the
riding ones have a weird neck, and generally the bears have very long snouts." On the mount the neck
rose from the shoulders to a head held high and forward, and every head ended in a long, dog-like
snout.

B2 is drawn from `tests/sheets/bears_b2.json`. Each B1 row there rebuilds the B1 numbers as a kit
variant, so before and after come from the same data. Every row passes the placement check (3D
and 2D).

| Sheet | |
|---|---|
| `archive/images/2026-10-13/395-bears-b2-vs-b1-facings-3x.png`, `396-...-game-scale.png` | standing, 8 facings, B1 above each B2 |
| `397-bears-b2-vs-b1-walk-3x.png`, `398-...-game-scale.png` | four walk steps in three facings |
| `399-bears-b2-vs-b1-idle-3x.png`, `400-...-game-scale.png` | idle: the bipeds at ease, the mount sitting |

Re-render with:
`godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/bears_b2.json out_dir`

**What's kept.** The bodies, the builds, the giant's size and the ear-cup helmet are unchanged. The
brown skull is a touch rounder, but it sits where it did, so the helmet fits the same way.

**Snouts (every bear).** The muzzle is now a short, broad, blunt block under a big round skull.
- Brown: it reaches about 2.5 units past the skull instead of 4.3, and it is wider and deeper. The
  dished face (the stop) is kept. The ears are small and round.
- Black: the same short muzzle with a straight profile. Its ears are a little smaller than in B1
  but still the biggest of the three.
- Polar: a little longer than the brown's, with a softer roman bridge, but nowhere near a dog's.
  Its long neck is kept.

At 1x the heads now read as round bear heads with a pale nose, not as dogs. The change shows most
in the side facings (f3, f4) and on the bare-headed worker.

**The mount's neck.** The mount now carries its own head (`mount_head`). It is the brown bear's
head, made from the same numbers (the kit's new `head_of`), pitched 22 degrees nose-down. It sits
low on a short, thick neck that slopes forward and down from the hump. The shoulder hump is the
highest point, and the head is at or just below it. The rider still sits behind the hump; the seat
and girth sockets are unchanged. When it sits down the mount raises its head on its neck (new
`sit.poses.<pose>.head`), as a bear sitting up does. That also kept the head off the forepaws in
the away facings, which the placement check flagged. The walk is unchanged. From the side it now
reads as a bear walking with a rider, not an animal with a long neck.

**More bear on the small soldier** (row 3, `helm.bear_open`, `scenes/art_pixel/bear_concepts.gd`).
This is an open-faced bronze cap set a little back, with no cheek guards, so the whole face and
brow show. The bear's own round ears come out through holes in the bowl (fur in the wearer's coat,
each in a bronze collar). It keeps the same tall team crest. At 3x the teddy-bear outline shows in
every facing but the back. At 1x the ears show as two dark bumps beside the crest, a smaller
difference than the bare face. It is cheaper than the ear-cup helmet (1 point, less pierce armour).
While it's a concept it is spear-only, so workers don't pick it as a hat.

### Recommendation (Claude, B2)

- Take the B2 heads for every bear. The short muzzle is the biggest single gain in reading as a
  bear.
- Take the low-headed mount.
- For the line soldiers, use the open-faced helmet with the ears out, so the small bears read as
  bears at a glance. Keep the full ear-cup helmet for the giant and the elite lines, where its
  bulk and the "armoured Greek" look are the point. This also gives the ages a visible step up.
- The rest of the B1 recommendation holds: brown as the soldier, black and grizzled as skins, and
  polar as the giant.

### Questions for Dominic (B2)

1. Are the muzzles short enough now, or shorter still (the polar's especially)?
2. Does the mount's head carriage read right: low, at or below the hump, nose down?
3. Open-faced helmet with the ears out for the line soldiers, the ear-cup helmet for giants and
   elites: yes, or one helmet for all?
4. The polar's long neck: keep it as what marks the polar bear out, or shorten it too?

## Round B1

### Size

A standing bear (kit scale 1.15 to 1.25) stands a head taller than a human, and its body is about
twice as wide. A worker is the same size, so buildings, siege crews and gear would need sizing
before bears play. The giants (1.5x on top of that) stand about twice a human's height and read as
the biggest thing on the field. The mount (scale 1.3) is a little longer and lower than the pony.
A Roman rides it at the usual 0.8. A rat on it looks tiny, which is a joke that works.

### The options

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

### What reads at game scale (1x)

- Bear versus human: the bulk, a body twice as wide on short legs, and the head held forward.
- The bronze helmet and cuirass, the team crest and the shield.
- Brown, black and polar are told apart by their colour at once, and by the hump and head shape at a second look.
- The walk shows as a short, heavy rolling step. The "at ease" idle only moves the feet apart and is
  hard to see at 1x. The mount sitting down is obvious.
- What doesn't read at 1x:
  - the black bear's chest crescent (under armour)
  - the dished face under a helmet
  - the ear cups compared with the stock helmet

### Recommendation (Claude, B1)

- Make **A (brown, with the hump) the bear race's soldier**, in the hoplite kit with the ear-cup
  helmet. It is the clearest bear and the most "dignified Greek".
- Make **B (black) and the grizzled coat skins of the same race**, as the rats have grey, brown and
  white.
- Make **C (polar) the giant line**, so the big one is visibly a different, rarer bear.
- Keep **the four-legged brown bear as the mount**, in brown and black coats, for cultures that ask
  for it (northern or forest cultures, or by name: "romans riding bears").

### Questions for Dominic (B1)

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
