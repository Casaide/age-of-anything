# Horses (concept round H1, 2026-10-13)

Dominic: "horses heads need a real re-work." The pony's head was a round-ended rod of a face on a
straight, featureless neck. At game scale it read as a sausage, and up close as a dog or a llama.

Drawn from `tests/sheets/horse_h1.json`, with riders on (a Roman, a rat in the right-hand columns),
the bare horse, and two more coats. Every row passes the placement check, 3D and 2D, including the
new head-join rule (`docs/rendering.md`). `data/later/horses.json` stages each look under its own ids
(`pony_classic`, `pony_h1`, `pony_h2`), so all three can be drawn side by side.

| Sheet | |
|---|---|
| `archive/images/2026-10-13/448-horse-heads-h1-classic-built-sculpted-facings-3x.png`, `449-...-game-scale.png` | standing, 8 facings |
| `450-horse-heads-h1-walk-3x.png`, `451-horse-heads-h1-walk-game-scale.png` | four walk steps in three facings |

Re-render with:
`godot --path . --audio-driver Dummy --always-on-top --script res://tests/sheet.gd -- tests/sheets/horse_h1.json out_dir`

## What the two options share

- **The neck.** It is deep at the base, from the withers to the point of the chest. It arches along
  the crest and is flat-sided (deeper than it is wide). It narrows to the throat latch, where the
  head sets on. A dark mane runs along the crest from the poll into the withers.
- **The join.** The neck runs into the back of the head and the bakes join them without a line, as
  on the bear mount (B3).
- **Ears, forelock and tack.** Small pointed ears stand upright and a little apart. There is a
  forelock, and a bridle: a noseband, cheek straps and the team browband.

## The options

**H1, built.** The head is made from shapes: a broad forehead, a big round flat jowl at the back,
and a long wedge of a face. The top of the face runs straight from the forehead down the nose and
narrows to a soft, darker muzzle, with nostrils, a chin and the jaw's edge. The eye sits high on
the side under a brow.

**H2, sculpted.** The same proportions, but the head is one surface sculpted in Blender
(`tools/blender/horse.py` -> `assets/models/head_horse.glb`). The face's sides draw in towards the
jaw, so it's a rounded wedge in section rather than a tube. It has the jowl, the brow over the eye,
the flare of the nostrils and the chin.

## Pick (Claude)

**H2 is built in** (`UnitModels.pony_look = "h2"`). Both reworked heads are clearly better than the
old one: at game scale they read as horses, with a long tapering head on an arched neck, the mane
and pricked ears. H2's wedge is cleaner and its muzzle reads better in the side facings. Front-on
(f1, f2) the head is foreshortened in all three looks; the new ones at least show a long face.
`pony_look = "classic"` puts the old head back, and `"h1"` the built one.

What's unchanged: the pony's body, legs, tail, harness and sockets (the rider sits where it did),
and the centaur, whose horse half has no head. The deer keeps its own antlered head: it is an
animal, not a mount, and a deer isn't a horse.

## Questions for Dominic (H1)

1. H2 in play: right call, or H1, or something else?
2. The head carriage (about 50 degrees nose-down) and the neck's length: right, or higher and prouder?
3. Should the war horses of later ages get more tack (a breastplate, a crupper, a caparison in team
   colour)?
