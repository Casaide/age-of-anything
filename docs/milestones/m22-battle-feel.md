# Milestone 22: Battle feel (formations, counters you can see)

**Status:** in progress (started 2026-10-17; proposed 2026-10-16; Dominic on the three ideas: "they all sound pretty cool")
**Exit criterion:** a group moved together lines up by role (infantry front, shooters behind, cavalry on the flanks,
siege and healers at the back); units go for the foes they counter when one is near; your selected units show who
they're fighting; a Norse culture's shield infantry stand visibly tighter (if Dominic says yes); test_sim, test_ai
and the batch pass; mass_battle and race_matches show no balance collapse against the numbers before; Dominic plays
a match and sees the difference.

## Scope

Dominic asked how deep the "matchmaking" goes when two armies meet, whether archers and cavalry take different
places, and whether the attack lines could show (2026-10-16). How it works today:

- **Marching (`src/sim/world.gd` `_formation`):** a box facing the way the group goes, about twice as wide as deep,
  two bands only: melee in front, shooters and healers behind. Cavalry counts as melee and stands with the infantry;
  siege has no place of its own. Slots are dealt by where units stand, so nobody crosses.
- **Picking targets (`src/sim/combat.gd` `_nearest_foe`):** the nearest foe, a foe already fought counting as
  `SPREAD` (1.5 tiles) further per attacker, so a clash becomes duels; a unit whose foe has more than `CROWDED` (2)
  attackers looks for a free one near. Counters play no part in the choice.
- **Seeing it:** nothing is drawn.

The work:

1. **Formation by role.** Infantry in the front rows, shooters behind, cavalry (a mount, or the fast/mounted tags)
   on the flanks, siege and healers at the back; slots still dealt by position, integers only, stable order.
2. **Counter-aware targeting.** A foe a unit counters (its attack bonus classes: spears vs mounted and large,
   skirmishers vs archers) counts as some distance nearer, the amount from data (`data/rules`), not a code constant;
   the duel spreading stays.
3. **Attack lines (view only).** A thin team-coloured line from each of your selected units to its current target
   (`units.foe`), under the units, your selection only (order marks' style: `src/view/order_marks.gd`).
4. **A Norse shield wall (ask Dominic first).** Vikings have no culture of their own: "viking" adds horned helmets and
   round shields to whatever culture a race gets, and the only Shield Wall is the imperial family's research (+2
   pierce armour, no formation). A Norse culture with a tighter formation for its shield infantry (a culture's
   formation gap in data) would make "super extra tight" visible.
   **Update 2026-10-17 (D-151): the Norse culture exists now** (`norse` in data/families.json: "viking", "vikings",
   "norse", "norsemen", "nordic" point to it). Its shield-bearers already get +1 pierce armour (the Linden shields
   bonus, priced), and nearly every Norse foot soldier carries `shield.round`. What's left for this step is only
   the formation: Norse shield infantry (units tagged `shield`, not mounted) should stand tighter than anyone
   else's, Dominic's "super extra tight"; a `formation` block in the culture's data (a smaller gap between files and
   ranks) is the natural place for it.

## Plan

Written 2026-10-17 (Claude), from the code as it stands. Order: 1, 2 (sim, measured before and after), 3 (view),
4 (once Dominic says yes), 5.

**Before anything changes:** a baseline of `tests/mass_battle.gd -- 2` and `-- 3` and `tests/balance.gd -- 2` saved to
the shared notes, so every step compares against the same numbers.

**1. Formation by role** (`src/sim/world.gd` `_formation`). A group is dealt into bands by its type:
- *front*: melee foot (not mounted, not an engine);
- *shooters*: ranged foot;
- *flanks*: mounted units (the `mounted` tag; horse archers too, unless Dominic wants them with the shooters),
  split left and right by where they stand, each wing a block beside the front rows;
- *rear*: engines (`radius` of their own / the `machine` tag), healers, harmless units (trade carts, siege towers).
Each band is a box of rows (the centre's width from its own count, as now), rows spaced by the band's own biggest body
(a ram doesn't spread out the spearmen), the whole block centred on the click. A group of one role is the box it is
today; mounted units with no foot beside them form the front themselves. Slots are still dealt by where units stand
(ahead, then across, ties by index), integers only. Nothing new is stored on units, so saves are untouched.
Checks: a `test_sim` part that builds a mixed group, moves it and asserts each band's place (front ahead of shooters
ahead of rear, cavalry outside the centre's width), plus the existing move-group checks (none stuck, chokepoints).
Picture: a mixed army in formation, before and after.

**2. Counter-aware targeting** (`src/sim/combat.gd` `_nearest_foe`). Each type gets the classes its attack has a
bonus against beyond melee/pierce/building (`type_vectors`: `t.counters`, rebuilt with the type, so loaded saves get
it too). A foe in one of them counts as `rules.combat.counter_pull` milli-tiles nearer (default proposal 2000, i.e.
2 tiles, a bit more than SPREAD's 1.5 per attacker), so a spearman picks the horse over the swordsman beside it, but
not one across the field; the spreading stays as it is. Data in all three rules files. Checks: a `test_sim` part
(spear between an infantry foe and a slightly further mounted one picks the mounted one; with pull 0 it picks the
nearest), the determinism and replay checks, mass_battle and balance before and after.

**3. Attack lines (view only).** In `src/view/order_marks.gd`: a thin team-coloured line from each selected unit
to `units.foe` (unit or building), drawn under the units, only your selection, fading with distance. Nothing in the
sim. Checked by a screenshot.

**4. Norse shield wall** (Dominic's yes first). A form gap per unit type (`form_gap`, a research effect stat that
the sim applies, unpriced, like `kill_gold`), and a Norse bonus that sets it for shield infantry (tag `shield`, not
mounted): their rows close up to bodies nearly touching. `_formation` uses the band's smallest gap.

**5. Balance and play.** mass_battle (ages 2, 3), balance.gd and race_matches against the baseline; Dominic's match.

## Checklist
- [x] Plan approved by Dominic (2026-10-17: horse archers on the flanks; counter pull medium, 2 tiles; shield wall look only, always on)
- [x] 1. Formation by role
- [x] 2. Counter-aware targeting (the weight in data: `counter_pull` 2000)
- [x] 3. Attack lines for the selection
- [x] 4. Norse shield wall formation (look only, on Linden shields: `form_gap` -160)
- [ ] 5. Balance check (mass_battle and balance.gd done, unchanged; race_matches and Dominic's match to come)
- [ ] Archive: pictures taken along the way, journal, decisions, timeline (first steps done: D-155, journal 2026-10-17-battle-feel)

## Results

**2026-10-17 (Claude):** steps 1-4 built (D-155). Checks: test_sim combat `role formation`, `counter pick` (pull and
no pull), `shield wall`; the crossings (flat, choke, engines) pass. mass_battle ages 2 and 3: single-type fights
identical to the baseline, mixed fights a win or two either way; balance.gd: same outliers, counters 79%. A failure
from before this work: test_sim "counters win at least 75%" at 49/66 (74%), the same with the old formation code.
Pictures: `archive/images/2026-10-17/14-16`. Left: race_matches, Dominic's match.

## Changes from the original plan
- The shield wall lives on the Norse Linden shields bonus (both its forms) as a `form_gap` effect, not a `formation`
  block of its own: a culture has exactly three bonuses, and the effect path already reaches the sim and saves.
- Attack lines show every fight of a selected unit (also the ones it found itself), and the attack-move's dashed leg
  starts from the unit, not the foe.

## Links
- `m4-combat.md` (counters, attack-move into duels), `m14-race-identity.md` (cultures, own research),
  `m2-map-movement.md` (move groups)
