# Milestone 6: Foundations

**Status:** planned (2026-10-11): next, after milestone 4 closes, alongside milestone 5 (art)
**Exit criterion:** All from data, with no special cases in code: stone is a third resource
mined from rock outcrops, winged units fly over water, frogs farm the swamp, and two teams of two
fight. Tests prove each one.

## Why
Dominic asked what on the cut list gets harder to add the longer we wait (2026-10-11). These are
architecture choices that more and more code would otherwise assume away. Doing them now keeps
later content (markets, more resources, asymmetric race mechanics, farms, teams, more ages)
mostly data. See decision D-056.

## Scope
1. **Any number of resources, from data.**
   - A `data/resources.json`; per-player stores, carrying, costs, `cost_mix`, pricing, the panel
     and the bot all work over that list.
   - Food and wood stay the defaults. **Stone** is added, mined from the rock outcrops (rock tiles
     become a resource with an amount; when used up they become rubble and then ground).
   - Gold waits for content.
2. **Movement classes: ground, amphibious, flying.**
   - Walkability per class (flying ignores water and rock; amphibious walks shallow water and
     swamp, faster in swamp).
   - Flow fields keyed by class; units get their class from tags (wings mean flying, `amphibious`
     means amphibious).
   - Fixes today's gap: winged units hover in the view but path like walkers.
3. **Placement rules per race and building.**
   - Which terrains a building may stand on (data on the building, widened by race tags).
   - Amphibians may build on swamp and shallow water.
4. **Teams.**
   - A team per player and an `is_enemy(a, b)` helper used everywhere instead of owner
     comparisons.
   - Two teams of two in a test.
5. **Ages and tech as data.**
   - A generic system with any number of ages and researches.
   - Research effects swap parts in recipes (D-055: upgrades change how units look) or adjust
     numbers.
   - Milestone 7 then fills in the content (the age-up, Sharp Sticks).
6. **Farms per race.**
   - A farm building that makes a food tile: a plain field for most, a swamp paddy for amphibians
     (placement from item 3).
   - Bug bushes stay the starting food.
   - Art comes with the art track.

Not in this milestone:
- the content of ages and research (milestone 7);
- markets and trade, gold, walls and gates, garrisoning;
- extra facings (4 or 8 directions): that's art-track work.

## Plan
(write before starting, and get Dominic's OK)

## Checklist
- [ ] Plan approved
- [ ] Archive: pictures along the way, journal, decisions, timeline
