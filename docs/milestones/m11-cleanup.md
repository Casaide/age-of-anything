# Milestone 11: Cleanup

**Status:** in progress (started 2026-10-11)
**Exit criterion:** Deep review of UI, UX and art by Fable

## Dominic's list (2026-10-11)

- Missing flag showing on the ground when we set waypoint (only visible while the building selected)
- SFX - i see hitting and killing makes sound. But without units chopping wood, moving, being built, farm expired - it's all very very quiet
- Finish UI
- Click resources to see how much they have left
- Immediatly clear when a resource has started being used - i.e. not 100%. Then further points where it degrades until gone
- Larger unit build queue
- Rocks style is very low res compared to bushes - so are farm. We seem to still be missing bringing all art quality in line. Water still very low quality and a bit cartoony - shore line is great
- Blocking rocks and stones you mine look identical
- Descriptions on buildable things. Show what you can get, for units what upgrades they can get and from what building. Make it clear upgrade to next age requires X
- Missing icons - like age upgrade
- Upgrades in wrong place - sharp sticks should be in "armoury" we dont have it yet, but better to add it than have things in wrong place. Also missing icons. Equally we're mixing barracks, ranged and cavalary into one. Was fine for early testing, but now it means lack progression
- Hovering over enemies i cant see and havent discovered still shows "Attack cursor"
- Time for a real test scene - Where we see menu, choose our side, see preview of it, and start a battle. Fully designed production grade lobby - with AI battle
- Shift click should build 5 of same unit
- Flesh out buildings - resource drop off buildings with resource gathering upgrades, walls, towers, market, lets expand the mvp here a bit more
- WASD for map movement is a bit too slow

- (2026-10-11, later) The flags on the frog huts look like golf (a lily pad green with a flag and a
  ball on every roof). We agreed sides don't need all this extra stuff; team colour should be subtle
- Cursors still look cheap; the "cut wood" cursor looks like a hammer
- Animals: ones to hunt, and ones to herd and gather (like sheep)
- Bug: clicking an enemy unit switches my fog of war to show what they see
- (AI playtest: the AI beat Dominic)
- We need gold too: the mineable rock easy to tell apart for stone and gold, but mostly a shared base

## Picked up from the art direction work (Claude, 2026-10-11, after Dominic: "other races we forgot")
Decided or picked earlier (see `../concepts/direction.md`, D-080 to D-086) but not yet built:
- **8 baked facings for every unit** (Dominic: yes). Units still have one three-quarter view,
  mirrored, so walking straight up or down reads as crab-walking. Needs sockets and draw order per
  facing, up/down gaits, facing choice with hysteresis.
- **Rats:** the capybara as the large unit (picked, RB1); their buildings by age (RB3: house cut
  down, barracks and the rest in junk, the age-3 pride step with oil-drum columns copying Rome).
- **Beetles:** the rearing posture (picked, BG1) built into play; then roles, gear by age, a large
  unit, and their own `pellet` architecture (split from `mound`).
- **Spiders:** the same posture round (a rearing jumping spider), then a `silk` architecture.
- **Humans:** Blender is installed; model human parts with `bpy` scripts towards Dominic's
  reference (pre-rendered classic cavalry), baked by Godot as now. Then the human rounds R1-R6 and
  each culture's gear by age (the table in direction.md).
- **Cultures:** Egypt, Han China and Aztec as data (Dominic: all three), horned helmets only on a
  silly ask.
- **Centaurs and ponies:** their own passes.
- **Buildings change with each age** (`arch:type:age`), each culture's story from its psychology.
- **Bears and beavers** (future races): ignore humans, build their own impressive halls.
- **Team colour:** one consistent region per unit (placement options still to show).
- Frogs: the bullfrog kept for another unit or an upgrade.
- Check: winged mounts' wings at about double size (Dominic's earlier note).

## Plan (2026-10-11, Claude)

Nine phases, smallest and most-felt first. Each phase ends with pictures in the archive and the
tests green. Anything cut moves to `../backlog.md`.

1. **Controls and feedback.** Fix: selecting an enemy unit must not switch your fog to theirs.
   Team markers made subtle (no flag-and-green "golf" toppers on roofs). Cursors redrawn to look
   finished (the chop cursor must read as an axe). The rally flag on the ground while its building is selected; the
   attack cursor only over enemies you can see; shift-click trains 5; a bigger training queue;
   faster WASD scrolling; click a resource to see what's left; resources show they've been
   started (no longer whole) as soon as they're first used, then shrink in steps until gone.
2. **Sound.** Synthesised like the rest of `src/view/sfx.gd`: chopping, foraging, mining,
   building (hammering), unit acknowledgements on orders, unit trained, building finished, farm
   used up, age reached. Positional and throttled so a crowd isn't a wall of noise.
3. **UI.** Every button gets a tooltip: cost, what it is, what it trains or researches, which
   upgrades a unit can get and in which building, and what's missing ("needs a Barracks", "needs
   age 2"). Icons for age-ups and every research. A layout and polish pass on the panel, bar and
   unit card.
4. **Buildings and gold.** Gold is in (a resource, deposits by each start, a shared rock base with
   stone); what costs it comes here: the age-3 step, elite units, the market. Data first (`data/buildings.json`, `data/tech.json`): the Barracks splits into
   Barracks (spear, skirmisher), Archery Range (archer) and Stable (large); an Armoury holds the
   weapon and armour research (sharp sticks move there); drop-off camps (wood, food, stone) with
   gathering research; a Market (buy and sell resources); Walls with a gate. The bot learns them
   through `data/ai.json`. Art per architecture.
5. **Art consistency.** Rocks and farms baked up to the bushes' quality; water redone to match
   the shoreline; blocking rocks and mineable stone made clearly different.
6. **Lobby.** A designed match setup: menu, pick your side (presets or a prompt), a live preview
   of the race, the AI's side, map, start. Production quality, not a debug form.
7. **Races.** The list above, race by race through the concept loop (options, Dominic picks,
   build): 8 facings first (it changes every unit), then rats, beetles, humans in Blender,
   spiders, centaurs and ponies, the three new cultures, buildings by age.
8. **Animals.** Huntable animals (fight back or flee, give a lot of food) and herdable ones (a
   sheep-like kind you take ownership of by finding it and lead home to gather), as data in
   `data/` with their own art.
9. **Exit check.** A deep review of UI, UX and art by Fable (a Fable agent works through the game
   in screenshots and the code), findings fixed, then Dominic's look.

## Checklist
- [x] 1. Controls and feedback (2026-10-11): fog leak fixed (against the AI you can't take its side;
      enemy units show their card); quiet team marks (no pennants, D-085); cursors redrawn (a real
      axe); the rally flag a baked prop; no attack cursor over unfound buildings; shift-click trains
      5; queue of 15 (current big, the rest small); WASD 1500 px/s; click a bush, reeds or stone to
      see what's left; resources look started from the first bite, then step down; mineable stone
      is its own prop (pale squared blocks) apart from grey blocking boulders
- [x] 2. Sound (2026-10-11, placeholder synths, Dominic to listen): chop, clink (mining), hammer
      knock, picking rustle, timed to the blow landing in each worker's animation and quieter away
      from the middle of the screen; order acknowledged, select click, unit trained, building
      finished, farm used up. `tests/sfx_export.gd` writes them all to WAV
- [x] 3. UI: tooltips, icons, polish (2026-10-11): tooltip cards on every button (cost, what it is,
      trains/research, upgrades and where, later-age names, needs in red, unlocks in green;
      descriptions are data); icons for age-ups, research, resources and population; a top bar
      with your stock; against the AI the debug lines are hidden (F1) and the AI's stock isn't shown
- [ ] 4. Buildings: barracks split, armoury, camps, market, walls
- [ ] 5. Art consistency: rocks, farms, water, stone vs blocking rocks
- [ ] 6. Lobby
- [ ] 7. Races: 8 facings, capybara, rat buildings by age, rearing beetles, humans in Blender, spiders, centaurs, ponies, Egypt/Han/Aztec, buildings by age
- [ ] 8. Animals: hunt and herd
- [ ] 9. Fable review, fixes
- [ ] Archive: pictures, journal, decisions, timeline

