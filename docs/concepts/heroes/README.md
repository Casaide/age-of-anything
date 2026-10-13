# Heroes, concept round HR1 (2026-10-13, Claude)

Milestone 14 phase 9. Each race gets one hero: a named, generated champion, the face of the race.
This round only asks **what a hero looks like**, built from parts we already have, so Dominic can
pick a direction before anything new is made (D-080). Nothing here is in play.

Sheet: `tests/sheets/heroes_h1.json` (run with `tests/sheet.gd`); `heroes_h1_facings_3x.png` (close)
and `heroes_h1_facings_1x.png` (game scale). Every row passes the placement checks.

| Look | What | Reads at game scale? |
|---|---|---|
| **A champion** | the race's age-3 swordsman, 1.25x, with a cape (cloth, or leaf for bugs and frogs) | bigger and caped: reads as "someone", but close to a giant line |
| **B standard bearer** | the same, 1.15x, the team banner on its back | the banner reads best of the three in a crowd; says "rally here" (an aura) |
| **C mounted** | the race's age-3 large line, 1.1x, with a cape where it fits | strongest where the race rides (imperial humans); rats with cheese hammers and Aztecs have no mount here, frogs go giant |

Things the round shows:
- A cape on a horse cuts through the horse's back (the placement check catches it: A3), so a mounted
  hero needs a cape cut for riders, or a banner on a pole instead.
- Forest beetles' age-3 large line rides a white horse: odd for a bug race; a hero should ride the
  creature's own mount (the beetle) or none.
- Size alone (A) reads as "a big unit", not "the hero". Something only heroes carry (a banner, a
  crest, a glow ring under them) would read better.

Claude's suggestion: **B's banner on A's size** (1.2x, the race's best kit, a banner pole on the back
in team colour, a cape only on foot), mounted only for races whose large line rides their own mount.
The aura shows as the banner. Revive: a fallen hero's banner stays where it fell until revived at
the Castle (a cost and a wait).

Waiting on Dominic: pick a look (A, B, C or a mix) before any hero is built. Name, aura and revive
rules are in `docs/milestones/m14-race-identity.md` ("Heroes").
