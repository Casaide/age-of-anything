# H1: humans, the base figure (2026-10-11): waiting on Dominic's pick

Dominic: "humans next, they were the worst." One Roman spearman, dark skin, age-1 cap
(`humans_cap_*`) and age-3 galea (`humans_galea_*`), at game scale and close up.

| Column | What it is |
|---|---|
| A | today's human (control) |
| B | chunky, about 4.5 heads: neck, broad shoulders, egg face with chin and nose, head gear replaces the top of the head; real cloth, skin and leather materials instead of the flat "mannequin" finish |
| C | slim, closer to realistic: narrower shoulders, longer legs, a smaller head |
| D | the hybrid: B's 3D body with a hand-drawn pixel head and helmet (from `tests/pixel_sprite.py`, stamped on at the neck) |

First read (Claude's; Dominic picks):
- **At game scale** A is still the blob; B and C read as soldiers, and their head gear reads (the
  cap's knob, the galea's crest and neck guard); D shows the clearest face (a brow and an eye
  under the brim).
- **Close up** D's pixel head shows its seams against the smooth 3D body; at game scale it sits
  well enough.
- All three new figures still lean dark and brown: bare legs and arms in dark skin plus a single
  team-blue tunic. The cloth needs a culture colour and the legs need wraps or sandal straps
  that read.

Tool: `tests/concept_sheet.gd` now takes `headpng=` (a drawn head stamp with its neck point).
