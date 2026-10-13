# The rats' mount (concept round RM1, 2026-10-13)

Dominic, on CP1's capybara: "push the capybara further, bigger head, need to avoid it looking like
a bear. OR, we need a new mount for rats? cat? tiger?"

Four options, each built in the real pipeline: a Blender-scripted body and head, the game's own
legs on anchors, a seat, sockets and a harness, baked in 8 facings with the team mask on the saddle
cloth. Every option is ridden by the rats' crossbow rider, with the cheese-hammer rider in the two
right-hand columns, next to a human on a pony for size.

| Sheet | |
|---|---|
| `facings_3x.png` | 8 facings, 3x close-up |
| `facings_game_scale.png` | the same at the game's scale (1x) |
| `walk_3x.png`, `walk_game_scale.png` | the cheese-hammer rider walking in two facings, four steps each |
| `capybara_long_in_play_3x.png` | option A in the game's capybara palette, as it now plays |

Re-render with `tests/rat_mount_sheet.gd` (the options) and `tests/capybara_sheet.gd -- out.png 4.5 long`.
The models are `tools/blender/capybara.py` (variants `long`, `long_tan`) and `tools/blender/big_cat.py`
(`cat`, `tiger`). The cat and the tiger live in `scenes/art_pixel/rat_mount_concepts.gd` and are not in
`data/`.

## The options

**Before: CP1's capybara (full).** A head about a quarter of the animal, rounded, tilted down. From
the back and the three-quarter views it is a round brown animal with a round head, and that is why it
read as a bear.

**A. Capybara, long head (now in play).** The head is a soft brick about a third of the animal: 12
long and 7 deep before scaling, flat on top from the crown to the nose. The muzzle is as deep as the
skull and narrower than it is tall. The whole blunt front is a dark bare nose, and the eyes and small
dark ears sit high on the top edge. The neck is short and holds the head level with the shoulders.
The rump stands well above the shoulders, and the feet are broad, dark and webbed. In the side views
it is a capybara at 1x: a long box of a head on a sloping barrel. Nothing about it is round enough to
read as a bear.

**B. Capybara, longer, tan face.** Option A's head made 2 units longer, carried level, with a tan
mask on the muzzle and under the jaw. The mask shows the head's length from the front and the back.
It reads as well as A, but in a few facings the pale muzzle starts to look like a dog. It is a
colouring to keep in mind, not the pick.

**C. Alley cat.** A scruffy grey mackerel tabby at pony size (the rats are human-sized, D-116):
- lean, with a deep chest and a tucked waist
- a long tail held up in a hook
- big upright ears, the near one notched
- a short muzzle with a leather muzzle strap and bridle (tamed), white socks, a pale chest
- the team colour on a saddle cloth with a pale border, and a girth harness

The tail and ears make it a cat at 1x in every facing, and the joke works: rats riding the cat.
Its weak points are that grey on the green ground is quieter than the other options, and a
long-legged cat with a rider can look a little like a donkey from the side.

**D. Tiger.** Longer and heavier than the cat:
- a broad head with a ruff of cheek fur and white cheeks and muzzle
- small rounded ears
- bold dark stripes on orange, a white belly
- a long tail curving low

This is the strongest read of the four at 1x, and it can never be a bear. But it is a tiger, not a
sewer animal: it carries no rat or sewer joke, and it would take the tiger away from a culture it
suits better.

## Recommendation

1. **The rats keep the capybara, pushed: option A.** It is now the look in play
   (`capybara_look = "long"` in `scenes/art_pixel/unit_models.gd`; `full` and the other CP1 looks
   are still in the switch). It is clearly better than CP1's full: the head is the capybara's own
   brick shape, and the bear look (round head, round ears, round mass) is gone. The capybara stays
   the rats' "big cousin" (RB1, Dominic's pick), and nothing in `data/` changed.
   - A follow-up for Dominic: the sheets show A in a redder brown (`#a65f36`), a capybara's real
     colour. In play it uses the palette's duller `#9a6a40` (`data/palettes.json` `capybara`).
     Changing that palette entry would give A the warmer coat.
2. **The cat is the best alternative if Dominic wants a joke over a cousin.** It is distinct at 1x,
   clearly not a bear, and very funny. It could also come later as a second rat mount: for example,
   lexicon words for "cat" on a sewer race, or an age-3 upgrade.
3. **The tiger should go to another culture, not the rats.** It suits the Han kit or a steppe
   culture's large unit (D-122 style), or a "tiger" lexicon word for any race that asks. Put it on
   the backlog with the bear.

None of the four reads as a bear. A, B and C avoid every bear cue: no rounded snout, no big round
ears, no shoulder hump, no round mass. D has small round ears, but the stripes and the long low tail
settle it.

## C2: the alley cat again (2026-10-13)

Dominic on C: "I'm leaning towards it, tail is good, just legs and body a bit unclear. I think
you've almost tried to force it to horse skeleton. Needs to be more naturally a cat, including
sitting when idle."

| Sheet | |
|---|---|
| `cat_c2_facings_3x.png`, `cat_c2_facings_game_scale.png` | standing, 8 facings: the pony, C (before), C2 ginger tabby, C2 black and white |
| `cat_c2_walk_3x.png` | the cheese-hammer rider walking in three facings, four steps each |
| `cat_c2_walk_cycle_3x.png` | all eight baked walk steps, side on |
| `cat_c2_sit_3x.png`, `cat_c2_sit_game_scale.png` | the idle sit in 8 facings |

More in `archive/images/2026-10-13/340-348` (the sitting-down step, the walk at 1x, a coat debug).
Re-render with `tests/cat_mount_sheet.gd -- out_dir [zoom] [facings,walk,sit,sit1,cycle] [cat_ginger,cat_tuxedo,cat_grey]`.

**The body.** A new Blender body (`tools/blender/big_cat.py` `lean`): longer and lower than C, the
loin a little arched, a deep chest, a tucked waist. It sits on short legs (about half its height
shows under the chest). A short neck carries the head low and forward, below the line of the back.
The head is rounder, with a shorter muzzle and bigger ears; the near ear is still notched, and there
are whiskers. The rider sits behind the shoulders on a smaller saddle cloth, and the hooked tail is kept.

**The legs.** These are a cat's legs, not a horse's:
- the hind leg has three bones: a big thigh, the shin going back, and a long metatarsus, with the
  hock (the "backward knee") high above a small round paw
- the foreleg runs straight from elbow to wrist, then a short pastern
- the shoulder blade is part of the foreleg, so it rides up over the back while that leg takes the weight

One sprite can't bend, so each leg is baked posed: eight walk steps per leg, worked out by two-bone
IK from a paw path. Each paw is down for 62% of the cycle. The footfalls go near hind, near fore, far
hind, far fore: a four-beat walk, with the body low and level and the head steady. This is data on
the body (`legs.poses`, `legs.hind`, `legs.gait`), not a special case in the code: see
`docs/rendering.md`.

**Sitting when idle.** After 3-6 seconds standing still with nothing to do, the cat sits down in two
steps (`idle_poses: ["sit1", "sit"]`). The haunches go down, the hind legs fold flat, the forelegs
stand straight, the chest comes up and the head stays level. The tail curls forward round the near
side towards the forepaws, and the rider sits upright, lower and further back. The cat stands up at
once when it has to walk, fight or work. Each pose is the body baked whole, and only the view
changes: the sim is untouched.

**The coats.** Each coat is a palette entry (skin = fur, skin2 = stripes, skin3 = chest, belly,
muzzle and paws, skin4 = stockings):
- **Ginger tabby:** reads clearly on the green, much better than the grey.
- **Black and white:** white bib, chest, forelegs, hind stockings and chin, so it reads as a
  tuxedo cat and not a black blob.
- **Grey tabby:** C's grey, kept as a third option.

**In play?** No. The rats keep the capybara. The cat is built in the real pipeline:
- models: the cat section of `scenes/art_pixel/unit_models.gd`
- poses: UnitView, with the extra bakes added in `art_kit`
- data: `data/later/cat_mount.json`, which holds the parts, the creature and the coats

Switching is a data change: move those entries into `data/` and set the rats' `mounts` to `["cat"]`.
Its stats are the capybara's until it is priced.

**What could still improve:**
- The sit is a pop between two poses, about a fifth of a second each, not an animation.
- In some facings the folded hind leg pokes out behind the rump.
- From the front and back the sitting cat is mostly hidden behind the rider.
- The near shoulder blade shows as a soft bump, but at 1x it is only a pixel.
