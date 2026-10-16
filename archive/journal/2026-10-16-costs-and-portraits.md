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

**Round 2** (Dominic: a drawn role glyph on the bust; the upgrade "feels a bit bland"). Six role glyphs drawn as SVGs
in the building glyphs' style (`assets/art/icons/glyph/role_*.svg`: spear, sword, bow, sling, horse, staff), picked
by the weapon's tags (a rider with a lance or blade: the horse; a centaur is its own horse and goes by its weapon;
workers none). Three upgrade buttons: U1 a gold frame, a big arrow, a pip per age; U2 before and after (the old
step small and faded in a corner, an arrow to the new bust); U3 a gold glow behind the new bust, rank chevrons.

**Built (D-145).** Dominic asked how other games show upgrades: the button shows what you'll get, and the tooltip
says "upgrade X to Y". So: busts with the role glyph everywhere a portrait shows, the line upgrade's button the next
step's bust in a gold frame, "Upgrade: X -> Y". On the way: the Train buttons and the unit card showed a line's
first step even after it was upgraded; they show its current step now.

## Pictures
- `22-unit-portrait-concepts-today-bust-badge.png`: the concept sheet, four races.
- `23-unit-portrait-concepts-round2-glyphs-upgrades.png`: round 2, the role glyphs and three upgrade buttons.
- `24-panel-bust-portraits-glyphs-upgrades-gold.png`: the Barracks in age 2 as built: Train (spear, sword) and
  their upgrades in gold frames.
