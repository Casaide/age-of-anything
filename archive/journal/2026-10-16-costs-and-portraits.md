# 2026-10-16: Costs by material, and portrait concepts

**Milestone:** 20 (Steam Deck), from Dominic's notes after a Deck session
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic: unit icons are "too zoomed out, hard to tell what's what"; the line upgrade's button looks like the
Train button beside it; and unit lines should differ in what they cost ("spears some wood and less food, swords
only food or food and gold"), as the genre's games do.

**Costs (D-144).** Every soldier cost about half food, half wood. Each part's mix now follows its material and the
unit's mix is its parts', weighted by points: bodies eat, shafts, bows and wooden shields are wood, metal is gold.
A spear in age 1 is 40-50F 25-45W, an age-2 swordsman 60F 25W 80G. The bots mine a quarter gold from age 2. Bot
economies over 40 minutes: ages on time, about twice the gold gathered, one start ran out of gold near home at 36
minutes. The race round robin on Reed Meadow (30 matches): wins spread 10-30% (before 10-40%), but 19 draws
(before 14): armies may be smaller now they need gold. Worth watching.

**Portraits (concepts, waiting on Dominic's pick).** `tests/icon_concepts.gd` frames each unit's portrait four
ways at the panel's 80 px: today, A a bust (head, chest, the weapon in hand), B today's frame with the unit's own
weapon as a badge, C both; and the line upgrade's button today beside a proposal (the next step's bust, a gold
up-arrow). The bust reads far better; the weapon badge is a line at that size (a drawn role glyph would read).

## Pictures
- `22-unit-portrait-concepts-today-bust-badge.png`: the concept sheet, four races.
