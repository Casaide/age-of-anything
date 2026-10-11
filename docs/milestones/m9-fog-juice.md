# Milestone 9: Fog + juice

**Status:** done (2026-10-11)
**Exit criterion:** A full match runs 9-12 minutes.

## Scope
Per-player visibility grid (unexplored/explored/visible, ~5 Hz, shader overlay), minimap,
placeholder SFX, hit flash, death poses, tuning.

## Plan (2026-10-11, Claude)
1. **Fog in the sim** (`src/sim/fog.gd`): per player a byte per cell (unseen / explored /
   visible), allies share sight, stamped from sight radii in `rules.fog` (tiles: units 6,
   workers 4, buildings 4, towers 8) every 4 ticks. Derived state, not hashed. The AI reads it:
   it counter-picks only against enemies it sees and attacks buildings it has explored (or the
   enemy's start).
2. **Fog in the view** (`src/view/fog_view.gd`): the grid as a one-pixel-per-tile texture laid on
   the iso map by its transform, softened by linear filtering. Enemy units show only where you
   see now, enemy buildings once explored. V reveals everything (debug).
3. **Minimap** (`src/view/minimap.gd`): a diamond with terrain colours from data, dimmed by fog,
   buildings and unit dots in team colours, the camera frame; click or drag to move the camera.
4. **Placeholder sounds** (`src/view/sfx.gd`): synthesised at start-up (no files): melee thwack,
   shot whoosh, death, age-up and victory/defeat jingles; played for on-screen events, rate-limited.
5. **Hit flash and death poses:** done in milestone 4's view work.
6. **Tuning to 9-12 minute matches:** wave timings in `data/ai.json`; the bot pushes reinforcements
   forward during an attack and goes for the Town Center when it isn't defended.

## Checklist
- [x] Plan
- [x] Fog grid in the sim; the AI plays by it
- [x] Fog overlay and hidden enemies in the view
- [x] Minimap
- [x] Placeholder sounds
- [x] Hit flash, death poses (milestone 4)
- [x] Tuning: matches run 9-12 minutes (`tests/test_ai.gd` checks the median of three pairings)
- [x] Archive

## Results
- **Match length** (bot vs bot, `tests/test_ai.gd`): frogs vs rats 10:22, centaurs vs frogs 14:02,
  rats vs centaurs 10:50; **median 10:50**, inside 9-12. Bot vs a passive player: 9:33-12:20.
- Two AI bugs found by the length check: armies chewed through every house before the Town
  Center (1,200-hp buildings, 1 damage a hit from archers), and units told to hit the Town Center
  stood still while new defenders cut them down. Now the bot fights defenders first, then goes for
  the Town Center, and feeds reinforcements forward in groups.
- Centaurs field no soldiers until about 8:00 (their pony workers are expensive): a balance item
  for milestone 10.
- Fog edge and minimap: `archive/images/2026-10-11/102-*.png`, `103-*.png`.
