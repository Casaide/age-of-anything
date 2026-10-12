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
