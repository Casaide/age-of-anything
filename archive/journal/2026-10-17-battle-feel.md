# 2026-10-17: Battle feel begins (milestone 22)

## What happened
Dominic asked for the formations and battle work "we discussed to improve engagement". Claude read the milestone plan
(m22-battle-feel.md), D-054 (attack-move spreads into duels, formations "cut for now") and D-151 (the Norse culture),
wrote the plan out, and asked three questions. Dominic took all three recommendations: horse archers stand on the
flanks with the other riders; units go for a foe they counter as if it were 2 tiles nearer; the Norse shield wall is
look only and always on (D-155).

Built, step by step, with a baseline of mass_battle (ages 2 and 3) and balance.gd taken first:
1. **Formation by role** (`World._formation`): bands for foot, shooters and the rear (engines, healers, carts), each
   spaced by its own biggest body, and two wings of riders beside the centre, as deep as its foot and shooters. Slots
   are still dealt by where units stand, so nobody crosses. A test_sim check (`role formation`) fails on the old code
   and passes now.
2. **Counter-aware targeting** (`Combat._nearest_foe`): each type knows the classes its attack has a bonus against
   (`t.counters`); a foe in one of them counts `rules.combat.counter_pull` (2000) nearer. Check: a spearman with a
   footman and a slightly further rider goes for the rider, and with the pull at 0 for the footman.
3. **Attack lines** (`order_marks.gd`): a selected unit in any fight (ordered, attack-move, or one it found itself) gets
   a thin team-coloured line to its foe, the foe ringed red. The attack-move's dashed red leg now starts from the unit,
   not the foe, so the two don't run side by side.
4. **Norse shield wall**: `form_gap` -160 on Norse foot carrying shields (a sim effect on Linden shields; a culture has
   exactly three bonuses). They settle body to body; frogs keep their usual gap (test_sim `shield wall`).

## Results
- mass_battle ages 2 and 3: every single-type matchup is identical to the baseline; mixed ones move a win or two
  (age 2 spear+archer v spear+cavalry 4 -> 6 of 10, age 3 sword+archer v spear+cavalry 7 -> 8). balance.gd: the
  same outliers and counter rate (79%) as before.
- test_sim combat: all new checks pass. One check was already failing before this work, with the old code too:
  "counters win at least 75% of equal-cost fights" at 49/66 (74%); the Norse "viking beetle riders" spearmen lose to
  their large units. Left for a follow-up.

## Funny moments / bugs
- Taking the attack-line picture crashed the draw: the foe ring read a unit by its index from before the sim stepped,
  and a dead unit's index ran past the end. It was already there for ordered attacks, but rarely seen; the new rings for
  every fight made it common. The ring now looks the unit up by id.
- The first shield-wall test measured a dozen Vikings piled on one spot: the test walked them into the flat test map's
  rocks.

## Pictures
- `images/2026-10-17/14-formation-by-role-riders-on-the-flanks.png`: frogs, newt riders on both wings.
- `images/2026-10-17/15-attack-lines-selected-archers-to-their-foes.png`
- `images/2026-10-17/16-norse-shield-wall-shoulder-to-shoulder.png`

## Ideas parked
- Dominic: fighting may become attack-move plus some units on defensive or stand ground. The formations and counter
  pull make that richer (a line of spears on stand ground in front of archers is a real choice now); a "hold
  formation" order is a candidate for later.
- The AI uses formations for free (it attack-moves); it doesn't yet place its riders or use stances on purpose.
