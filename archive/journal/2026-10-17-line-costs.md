# 2026-10-17: Lines, not parts, decide what a unit costs

**Milestone:** none (a balance fix after milestone 13's D-144)
**Who:** Dominic + Claude (Claude Code)

## What happened
Dominic asked whether swordsmen still cost wood. They did: 40-60 wood a head, for the wooden round shield (all
wood), the banner (half wood) and the sword's hilt (a fifth). Since D-144 every part brought its own material's
resources, so a swordsman (60F 45W 70G) paid more wood than an age-1 Roman spearman (50F 30W). Dominic: "that's a
mess. We're using the parts too literally." In the genre what a line costs is part of what it is, and clear: the
cheap counters cost no gold, the strong lines do.

Now each line has one mix (`rules.cost.roles`), the same for every race; the parts still set the total. Age 1 pays
any gold share in food. Prices are in tens.

Before and after (age 2):

| Unit | Before | After |
|---|---|---|
| Swordsman ("vikings") | 60F 45W 70G | 110F 0W 70G |
| Roman Legionary | 60F 40W 90G | 110F 0W 80G |
| Bronze Spearbearer (Roman) | 40F 55W 70G | 60F 100W 0G |
| Scout on a Pony | 140F 10W 70G | 220F 0W 0G |

## Decisions
- D-150: one mix per line; totals from the parts; no gold in age 1; prices in tens.
- Not done: capping how far a line's total varies by race. Dominic: centaurs can have fewer, stronger units; a cap
  would make a stronger race cheap, and cost is the balancer.

## Ideas parked
- A race perk that drops a line's gold (Dominic: maybe the rats' or spiders' infantry), only if carefully balanced
  (backlog §8).
