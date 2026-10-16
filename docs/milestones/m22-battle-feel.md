# Milestone 22: Battle feel (formations, counters you can see)

**Status:** planned (proposed 2026-10-16; Dominic on the three ideas: "they all sound pretty cool")
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

## Plan

Not started. A proposed session (task card "Formations by role, counter targeting, attack lines") holds the brief.
Order: 1, then 2 (both sim, measured with mass_battle and race_matches before and after), then 3 (view), then 4
once Dominic says yes.

## Checklist
- [ ] Plan approved by Dominic
- [ ] 1. Formation by role
- [ ] 2. Counter-aware targeting (the weight in data)
- [ ] 3. Attack lines for the selection
- [ ] 4. Norse culture and its shield wall (Dominic's yes first)
- [ ] 5. Balance check (mass_battle, race_matches, before and after) and Dominic's match
- [ ] Archive: pictures taken along the way, journal, decisions, timeline

## Results

## Changes from the original plan

## Links
- `m4-combat.md` (counters, attack-move into duels), `m14-race-identity.md` (cultures, own research),
  `m2-map-movement.md` (move groups)
