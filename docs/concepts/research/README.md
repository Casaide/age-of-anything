# Art research (2026-10-11): the deep dive

Dominic: "Art still hasn't had the deep dive and research. I'm waiting to see concepts before we
go all in ... where's the examples?" And on buildings: "huts for frogs are nice but follow the
same general lazy design: looks all good, then slaps a lilypad on the roof, it has no meaning.
Buildings need to be more deeply showing a culture, like the Roman ones and the Mongolians do.
Same with the bugs: the idea is there, but just shapes, very lazy."

This folder is the research a design-lead agent did in answer, building on
`../direction.md` (the human figure, facings, pipeline) and `../README.md` (round 1 head gear).
Nothing here is built yet. It's the material for the next concept sheets.

| File | What's in it |
|---|---|
| [buildings.md](buildings.md) | Why our buildings read as lazy; what "deep culture" means visually; the **building scale ladder** (why rat buildings look bigger than Roman ones, and a fixed rule for every architecture); briefs for Roman, Greek, Norse, Egyptian, Han and Aztec |
| [creature-cultures.md](creature-cultures.md) | Real vernacular architecture and natural structures behind frogs, beetles, spiders, rats, bears and beavers; a culture brief per creature; 5 town-centre directions each for frogs, beetles and spiders, and 4 for rats |
| [units.md](units.md) | Per-culture small-scale reads (shields, head gear by age, cloth) with linked real references, and how frog, rat, beetle and spider units read and wear gear that's theirs |
| [pipeline.md](pipeline.md) | 3D-baked vs pixel-drawn vs hybrid, especially for organic buildings; the building half of the bake-off |
| [concept-plan.md](concept-plan.md) | The concept sheets to produce next, in order, each with 3-5 options |

## How the references work

- **Real-world references** (architecture, animals, museum objects) are linked directly to
  Wikipedia and Wikimedia Commons. Commons category pages are picture galleries: open them for
  images.
- **Game references** are written as codes like **[G7]** with a description ("a classic RTS's
  architecture sets"). House rules keep commercial game names out of the repo, so the code list
  with names and links was given to Dominic in chat on 2026-10-11. If it's lost, each description
  says enough to find the example again.
- Books and films (illustrated animal stories, animated films) are art references, not games, and
  are named where useful.
- Every reference says **what to take from it**. A reference with no "take" is decoration, which is
  the very problem we're fixing.

## The findings in one screen

1. **The buildings are lazy because they're reskins.** In `src/view/art/bake/models.gd` the
   barracks, stable and watchtower are one layout for every culture with materials swapped from
   the `KIT` table. Frogs add a lily pad on top and bugs swap the roof for a dome. The Roman and
   steppe buildings work because their forms come from a real way of building (tile roofs on
   walls and columns; a felt lattice tent with roof ropes and a crown ring). The frog and bug ones
   are generic shapes with a sign stuck on.
2. **Deep culture is structure, not stickers.** Each culture needs a material system, a way of
   building that *produces* its shapes, 3-5 recurring forms, a relation to the ground, and motifs
   that mean something to the people who live there. Then the ornament is the structure: the
   bundled-reed arches of an Iraqi marsh guest house, the raised ribs on a Cameroonian earth shell,
   the fluted chimneys of a termite mound.
3. **Rat buildings look bigger than Roman ones because they are.** The sim footprints are the
   same, but the rat town centre is a full 2.1-tile cube under a 2.7-tile roof (about 1.6x the Roman
   hall's volume), and the tin-can house has about twice the Roman house's volume. Every
   architecture needs one **scale ladder**: a fixed envelope per building type, set by the
   footprint and never by the creature. The genre keeps a building type the same size across all
   cultures. See `buildings.md`.
4. **Pixel drawing isn't the cure for "set shapes"; code primitives are the limit.** 3D can do
   organic forms if we build them the way they're really made (sweeps along curves, instanced
   pellets and shingles, cables under tension). But buildings need only one view, while units need
   8 facings, so hand-pixel work costs far less for buildings than for units. The recommended test
   is in `pipeline.md`.
5. **Next:** a scale-ladder lineup (cheap, fixes a visible bug), then town-centre direction sheets
   for frogs, beetles and spiders (5 options each), alongside the unit rounds R0-R1. See
   `concept-plan.md`.
