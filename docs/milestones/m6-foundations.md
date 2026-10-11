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
5. **Ages and tech as data** (uses item 6's lines for the age-up's look).
   - A generic system with any number of ages and researches.
   - Research effects swap parts in recipes (D-055: upgrades change how units look) or adjust
     numbers.
   - Milestone 7 then fills in the content (the age-up, Sharp Sticks).
6. **Gear tiers by age; the generator writes each unit line through the ages** (Dominic,
   2026-10-11). Today every unit starts in its culture's best kit, so there's no visual room
   for progression (centaur Romans in lorica from the first minute).
   - Parts get a tier: age 1 light kit (cloth, leather, wood, reed, acorn); age 2 bronze and
     mail; age 3 iron and plate.
   - Each roster slot becomes a line: an age-1 recipe plus a recipe per later age, chosen within
     the culture. A frog visibly toughens over the eras.
   - The race key covers the whole line.
   - Unit-line upgrades (spearman -> pikeman) are the other big visual step.
   - Blacksmith upgrades change numbers, with at most a small, consistent visual tell (a metal rim,
     studs, a brighter blade), to keep silhouettes readable and bake counts down.
7. **Farms per race.**
   - A farm building that makes a food tile: a plain field for most, a swamp paddy for amphibians
     (placement from item 3).
   - Bug bushes stay the starting food.
   - Art comes with the art track.

Not in this milestone:
- the content of ages and research (milestone 7);
- markets and trade, gold, walls and gates, garrisoning;
- extra facings (4 or 8 directions): that's art-track work.

## Plan
(Order updated: 1 resources (done), 2 teams, 3 movement classes, 4 placement, 6 gear tiers and
unit lines, 5 ages and tech, 7 farms.)
Dominic asked to go straight on from milestone 4 into this one (2026-10-11). Order: 1, 4, 2,
3, 6, 5. Each step ends with green tests and a commit.

1. **Resources:**
   - `data/resources.json` (ordered: food, wood, stone; name, short label, colour);
     `DataLib.resources`.
   - World: `stock[r][player]` and `gathered[r][player]` instead of food/wood arrays.
   - Types carry a cost vector; `can_afford`, `pay` and `refund` helpers.
   - `carry_kind` is resource index + 1; buildings' drop-off is a list of resource indexes.
   - Pricing splits cost over every resource in the parts' `cost_mix` (food and wood numbers
     unchanged).
   - Terrain `stone` (a gatherable deposit, becomes `rubble` ground when used up); deposits near
     each start on both test maps. The map border and obstacles stay `rock`.
   - The view shows stone deposits with the art kit's rock props, and the bar lists every
     resource.
   - Rules: start stocks and gather times per resource.
2. **Teams:**
   - `races[p].team` (rules or setup), `World.is_enemy(a, b)`, used by combat and anything that
     compares owners.
   - A 2v2 test.
3. **Movement classes:**
   - `ground`, `amphibious`, `flying` from unit tags (data: a tag -> class table in rules).
   - A walkability grid per class: flying ignores water and rock; amphibious walks swamp and
     shallow water (a new `shallows` terrain).
   - Flow fields keyed by class; separation and blocked-tile pushes per class.
   - Swamp speed for amphibians from data.
4. **Placement:**
   - Buildings list the terrains they may stand on.
   - Race tags can widen that (amphibians: swamp, shallows).
   - `can_build` takes the owner.
5. **Farms:**
   - A `farm` building that, when built, makes its footprint a food field with an amount.
   - The farm's terrain/look per culture: a field, or a swamp paddy for amphibians, which can
     put it on swamp.
   - Bug bushes stay the start food. The art track gets the look.
6. **Ages and tech as data:**
   - `data/tech.json`: ages and researches, with costs, time, building, requirements.
   - Effects: swap a part for another (by slot or tag) or add to a stat.
   - Commands RESEARCH and AGE_UP; types re-priced from the new recipes; existing units updated.
   - One test research. Milestone 7 fills in the content.

## Checklist
- [ ] Plan approved
- [ ] Archive: pictures along the way, journal, decisions, timeline
