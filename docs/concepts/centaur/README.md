# The centaur, drawn first (concept round C1, 2026-10-31)

After three modelled rounds (BA1 to BA3, `archive/journal/2026-10-31-beast-anatomy.md`), Dominic: "feel like we should
start creating 2D concept art first, and iterating, before making the model". From here the centaur is drawn, picked
and iterated on paper; the model follows the picked drawing.

`tools/art/centaur_concept.py` draws the sheet (`python3 tools/art/centaur_concept.py docs/concepts/centaur/`): each
option side on, a bay coat and a legionary, then the same picture shrunk to about the size it plays at and blown
up with hard pixels (`c1_<x>_play.png`). The options share one drawing; each only moves and scales the horse half
and the man, so the sheet compares proportions. In all three the horse's chest rises straight into the man's waist
(no hump behind him), the back is level, and the rump rounds into the tail.

- **A, classic:** a riding horse, the man where its neck would be.
- **B, compact hero:** a shorter, deeper horse on shorter legs, the man a size up. The man reads at a glance.
- **C, long and low:** a longer, lower horse, the man as he is. More animal, less hero.

Next, once one is picked: the same option in 3/4 view (the game's camera) and a coat or two, then the model.

Sheet: `c1_sheet.png` (also `archive/images/2026-10-31/11-centaur-concept-c1.png`).

## Picked: B (Dominic, 2026-10-31: "B looks good")

Modelled as look h (`tools/blender/centaur.py`, staged as `pony_c1_h` in `data/later/beast_anatomy.json`, sheet
`tests/sheets/centaur_c1_b.json`). It is BA3's f with the body behind the shoulder 0.88 as long, the belly 2.5 lower,
a boxier section, and legs 0.85 as long (`centaur_legk`, the hips 2.4 lower). Measured against the man, drawing B's legs
are shorter still (the belly 0.46 of his height off the ground); taken that far (0.75 legs, the belly 4 lower) the
model read as a sheep in the game's 3/4 view, so it stops short of it. Pictures
`archive/images/2026-10-31/14-centaur-b-drawn-and-modelled.png` (drawing, bay worker, legionary) and `15-centaur-h-close.png`.
