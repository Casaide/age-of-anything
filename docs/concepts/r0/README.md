# R0: 3D-baked vs pixel-drawn (first run, 2026-10-11)

Dominic: "3D versus pixel we need to test." One Roman spearman, an age-1 leather cap (Montefortino
shape) and an age-3 galea, in three facings, close up and at game scale. Sheets: `sheet_<facing>_
<close|game>.png` (s = towards the camera, se = three-quarter, n = walking away).

| Column | Pipeline | Claude's time |
|---|---|---|
| current_cap, current_galea | **A**: today's 3D figure (control) | 0 |
| body_chunky ... | **A+**: tuned 3D to the proposed spec (`scenes/art_pixel/concepts.gd`): 4.5 heads, neck, broad shoulders, egg face with chin and nose, dark eyes, helmet replaces the cranium, untextured skin | ~1 h |
| b_cap_*, b_galea_* | **B**: hand-authored pixel art, written as text grids on one palette (`tests/pixel_sprite.py`), body + face + head gear + arm/spear stamps per facing | ~1 h for 3 facings x 3 heads |

## First read (Claude's; Dominic judges)
- **A** is the blob Dominic described: round head, lid helmet, no neck.
- **A+** fixes the head gear (the galea now *is* the head) and the proportions, but smooth
  untextured primitives read as a wooden mannequin; the face still doesn't read at game scale.
- **B** reads clearest at game scale: a face, a helmet shape, a tunic, crisp edges, every pixel
  placed. It looks like a classic hand-drawn sprite, which sits differently next to the painterly
  baked buildings. Every new part costs a drawing per facing (8 facings = 5 drawn + 3 mirrored,
  or 8 drawn), and gear has to be drawn per head shape (human, rat, frog...).
- **Fairness fixes (second run):** B is now taller, stands on the same ground shadow, and uses the
  race's dark skin (`b_*_dark.png`); the light-skin versions are kept for close-ups.
- Facing the camera, A+ holds up better than at three-quarter: the helmets read. B stays crisp
  in all three views.

## Not built yet
- **C, the hybrid** (A+ bodies with pixel-drawn heads and head gear per facing).
- **The building half of the test** (the design agent is proposing what it should be).
- **The mixed lineup** with a rat and a frog at the same height.
