# Concept plan: the next sheets, in order (proposal, 2026-10-11)

Dominic wants to see real variations before anything is committed. This is the order of concept
sheets for buildings (BC) and creature units (CU), slotted in with the human unit rounds R0-R6
already proposed in `../direction.md`. Every sheet shows **3-5 distinct options**, close up and
at game scale, next to infantry units for scale, and ends with one or two questions for Dominic.
Nothing gets built for the game until he picks.

## How every sheet is made
- **Massing models, not finished art.** Each option is built quickly in 3D with the same kit
  (a building version of `tests/concept_sheet.gd` drawing from a concepts file, never used in
  play), lit and baked like the game. Enough to judge silhouette, structure and scale, not
  texture.
- **A caption per option:** one line on how it's built and one on what it's inspired by, with
  the reference link (from `creature-cultures.md` and `buildings.md`), so the "where are the
  examples" question is answered on the sheet itself.
- **Always on the scale ladder** (`buildings.md` section 3), with a door-height unit beside it.
- **Optional reference board:** a page per culture with the linked real photos (Commons
  galleries) laid out beside the options, if Dominic wants pictures without clicking through.

## Phase 0: settle the pipeline and the sizes (now, in parallel)

| Sheet | What it shows | Options | Question for Dominic |
|---|---|---|---|
| **R0** units bake-off | (running separately; see `../direction.md`) | A, A+, B, C | Which pipeline? |
| **P0** building bake-off | The frog age-2 house in four pipelines (`pipeline.md` section 4); stretch: the spider funnel lodge | A today, A+ 3D generators, B pixel-drawn, C hybrid | Which pipeline for buildings? Same as units or not? |
| **BC0** scale ladder | All six current architectures' town centre, barracks, stable, house, watchtower and farm in one lineup on one ground strip, an infantry unit at each door | (1) as now; (2) strict envelopes from the ladder table; (3) strict envelopes, with a creature lean of up to ±10% (rats squatter, spiders taller and thinner, frogs wider) | Strict, or strict with a lean? (Fixes "rat buildings are bigger than Roman ones") |

BC0 is cheap (re-scaling existing models) and fixes a visible bug, so it comes first.

## Phase 1: one big idea per creature culture (the town centre)

The town centre carries the culture's grammar; the rest of the set follows from the pick.

| Sheet | Options (from `creature-cultures.md`) | Question |
|---|---|---|
| **BC1** frog town centre | F1 Reed Hall, F2 Spawning Court, F3 Great Pad, F4 Root House, F5 Toad Mound | Which is the frog grammar? (Claude's pick: F1 with F2's pool at its heart) |
| **BC2** beetle town centre | B1 Cathedral Mound, B2 Ribbed Shells, B3 Sun Ball, B4 Elytra Pavilion, B5 Fungus Hall | Which is the beetle grammar? (B1 or B2) |
| **BC3** spider town centre | S1 Funnel Lodge, S2 Trapdoor Court, S3 Egg-Sac Tree, S4 Wheel Gate, S5 Stitched Case Hall | Do spiders split from beetles? Which grammar? (S1 + S3 or S4) |
| **BC4** rat town centre | R1 Grate Hall, R2 The Stack, R3 Kettle Keep, R4 Cheese Vault | Which? (R1 + R2) |

In parallel, the creature units' first sheet:

| Sheet | Options | Question |
|---|---|---|
| **CU1** creature heads and identity features | Frog: (a) bare, (b) plaited reed brow band between the eyes, (c) shell cap behind the eyes, (d) reed hood with eye holes. Rat: (a) bare, (b) thimble cap between the ears, (c) helmet with ear slots, (d) hood with ears out. Beetle: (a) bare horn, (b) painted horn, (c) seed-husk horn cap, (d) horn sheath with crest. Spider: (a) eye pair only, (b) silk headband, (c) shell cap, (d) dew-pearl crown. All in three facings, at 1x and 3x | Which treatments keep the creature readable? (Rule: gear never covers eyes, ears, horn or leg fan) |
| **R1** human figure | (as in `../direction.md`) shown beside the CU1 picks | |

## Phase 2: each creature culture's whole set and its ages

| Sheet | What it shows | Options |
|---|---|---|
| **BC5** frog set | House, barracks (call hall), stable (dock), watchtower, farm (lure lanterns) in the picked grammar | 3 set variants (e.g. pure reed; reed with pad shingles and clay; reed on mangrove roots) |
| **BC6** frog ages | The town centre and house at ages 1, 2, 3 | 3 growth stories (more arches; reed to shell to lacquer; hut to hall to twin halls) |
| **CU2** frog units by age | Worker, spear, skirmisher, archer, large, in age 1, 2, 3 materials (reed, shell, lacquered shell with cattail crest) | 3 material ladders; 4 shield shapes (ribbed pad, turtle shell, woven round, shell-studded) |
| **BC7 / CU3** beetle set, ages and units | As BC5, BC6, CU2 | 3 each |
| **BC8 / CU4** spider set, ages and units | As BC5, BC6, CU2 | 3 each |
| **BC9 / CU5** rat set, ages and units | As BC5, BC6, CU2 | 3 each |

## Phase 3: the human cultures

| Sheet | What it shows | Options |
|---|---|---|
| **BC10** Roman vs Greek | Town centre and barracks for each, side by side, so the shared `stone` set splits | 3 each (Roman: forum arcade, camp gate, basilica; Greek: stoa, gymnasium, round temple) |
| **BC11** Norse, Egyptian, Han, Aztec town centres | One sheet per culture | 3 each (from the briefs in `buildings.md`) |
| **R2-R5** | Human heads, head gear per age, shields, cloth (`../direction.md`) | as planned |

## Phase 4: in context

| Sheet | What it shows |
|---|---|
| **R6 / BC12** town sheets | A whole age-2 town per culture in the game view, two cultures facing each other across a river, with their armies in 8 facings: the final check that buildings and units are one world |

## Suggested order and rough time (Claude)

1. BC0 scale ladder (~0.5 day) and P0 building bake-off (~2 days), alongside R0.
2. BC1 frog and BC2 beetle town centres (~1 day each, massing quality), CU1 (~1 day).
3. BC3 spider, BC4 rat (~1 day each).
4. Dominic picks; then phase 2 per culture (~2-3 days each), starting with whichever creature
   culture he plays most.
5. Phase 3 and 4 as the unit rounds reach them.

## Data notes for later (no art decision needed)
- Spiders and beetles need separate architectures: today both creatures name `mound` in
  `data/creatures.json` (the creature override from D-073).
- Greek and Roman need separate architectures (today both are `stone`).
- Barracks, stable and watchtower need per-architecture models instead of the shared `_barracks`,
  `_stable` and `_tower` with a material table.
