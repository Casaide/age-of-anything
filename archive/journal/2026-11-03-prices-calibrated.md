# 2026-10-31 to 2026-11-03: prices calibrated offline, matches load without fights

## What happened
Dominic asked why we balance at all before a match: "we control all the inputs, but we act like the outputs are an
unknown?" The load-time round robin (D-170) took 7 to 38 s and priced each line against whoever it met. The plan he
picked: calibrate once, offline, and fix every price per unit.

Claude wrote `src/calibrate.lobster` (sharded with `shards.sh`, 4 at once):
- `lines`: races from the lexicon's words (the lobby's dice, seeded); each of their lines is fought against a fixed
  panel at equal cost, and its price bisected until it wins half: its fair price.
- `fit`: fair price -> target points through the cost curve's inverse, then every part's `price_points`, each
  line's roster `price_points` and the giant/tiny points by weighted, regularized least squares.
  `tools/balance/write_prices.py` writes them into the data keeping its formatting.
- `measure`: held-out races' round robins at the prices as they are; `pool` puts every held-out line in one round
  robin; `oracle` prices each line at its own panel price (the method's best).
- `mod <id>`: a mod's parts priced the same way (`mod_check.sh` ends with it).

Three passes. Pass 1 (panel: greek hoplites and sewer rats) helped less than hoped on the 2-race groups: 60% to 52%
of lines off. The oracle explained why: even each line at its exact panel price left 41% off. A line in a 2-race
round robin has 13 fights, one fight is 8 points, so coin flips alone put about half the lines 10 points off. The
pool (about 140 fights a line) is the fair measure. Two more fixes: the fit weighs each line's miss by what a point
does to its price (a point is a quarter of a cheap archer's price, so the first fit made frog archers 40 food and
they won everything), and the panel became three random races' lines (slingers were fair against the hoplite panel
and weak against everyone else). Pass 3 picked creatures evenly (bears have nine words, centaurs two) and fitted the
giant and tiny points too, with age 3 added.

## Results (held out, same data, no fights at load)
| | points only | calibrated |
|---|---|---|
| the pool, 124 lines: more than 10 off the mean | 71 (57%) | 30 (24%) |
| the pool: spread (sd), more than 20 off | 16.7, 29 | 10.7, 8 |
| 2-5 race groups, 145 lines | 87 (60%) | 55 (37%) |
| the setup's default pair (rats, frogs) | 7 of 14 | 5 of 14 |
The match start: the races in 6 ms, the start in 10 ms.

## Decisions
- D-195 (supersedes D-170): prices are fixed per unit, calibrated offline; no fights at load or mid-match.

## Funny moments and bugs
- test_sim's counter fights priced a unit by its food and wood only, so archers (half gold) came twice as many as their
  price buys: "0 skirmisher left vs 25 archers worth 500".
- The first fit made bows nearly free. The backlog already said a tuner had done exactly that in milestone 10.
- A long calibration run outlived its session: pass 3 was cut off, and pass 2's prices went to main in a commit called
  "voxel".

## Left failing
- test_ai's bot vs bot (frogs vs rats) draws to 30:00 at the new prices (and to 45:00): tiny armies trading, the rats
  far ahead but never finishing. At pass 2's prices it ended at 29:02; points-only prices fail two other bot-match
  checks. A bot fix, not a price or test fix (backlog, section 3).
- placement2d's two failures are the centaur's kneeling pose (another session's art), not prices.

## Ideas parked (docs/backlog.md, section 3)
- Counters are weaker at fair prices (90% -> 72%): infantry vs spear, large vs archer. Counter bonuses are Dominic's
  call.
- Identity bonuses' price points, ages 1 and 4, flying and scouting value.
