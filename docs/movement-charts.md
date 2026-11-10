# Showing a movement fix

How to show that a movement or pathing change works: what a unit did before the change and after it, in a picture
someone can read at a glance. Use it for the PR picture and the archive. Start with the normal game (a real match, a
few units), not the 2,000-unit battle, which is only a load test.

## Path charts from a headless scene

Used first on #400 (a spearman frozen behind its own archers): `archive/images/2026-11-10/37-spearman-round-archers.png`.

1. **The scene.** The fix's failing test is a `test_movement` scene (strict TDD: it fails on main). The chart is
   drawn from that same scene.
2. **The trace.** Copy the test to a scratch `src/<name>.tmp.lobster`, and in the scene's tick loop print one line
   per tick for each unit you're showing, plus one line per standing obstacle:
   ```
   for(bows) id: print "B {u_x[index_of(id)]} {u_y[index_of(id)]}"
   for(PAST_TICKS):
       wstep()
       print "P {u_x[index_of(a[0])]} {u_y[index_of(a[0])]}"
   ```
   Run it, keeping only those lines: `lobster pa.tmp.lobster -- past_archers | grep "^[BP] " > after.txt`.
3. **Before.** Put main's code back under the same scratch scene (`git show origin/main:src/lib/<file> >
   src/lib/<file>`), run it into `before.txt`, then restore the fix. The scene must be identical in both runs; only
   the code under test changes.
4. **The plot.** Two panels side by side, the same axes and scale: buildings as filled rectangles, standing units
   as circles at their body size, the moving unit's path as a line with its start and end marked. Use one title per
   panel that says what happened ("Before: stuck behind its archers", "After: walks round them"), with y pointing
   down as on the map. Plot it with any tool to hand (matplotlib in the cloud container); the plotting script is
   scratch, not a repo tool (#114: no Python in the repo).
5. **Keep it.** Save it as `archive/images/<date>/NN-name.png`, look at it, commit it with the fix, and link it in the
   PR body. Delete the `.tmp.lobster` copy and the traces.

A chart shows one or a few units clearly. For crowds, chart a measure over time instead (overlap, drift or the
slowest unit's distance to its place per tick), before and after.

## Checking it in a real match

A headless scene proves the mechanism. A watched match (`./play.sh lobby "races:..." watch mute`) shows it in play.

- **Frame strips.** Record a short clip of the spot (`record:<dir> from:<s> for:<s> fps:5`, `speed:` to get there
  sooner), then lay crops of the same spot side by side frame by frame (`montage`). A unit that freezes or a block
  that sways shows up as frames that don't change, or change back and forth. Make one strip before and one after.
- **Per-tick traces.** To pin down why a unit misbehaves, temporarily print that one unit's steering each tick
  (position, velocity, waypoint, target, foe) and what `separate()` pushes it by and from whom. A small map of the
  cells round it helps too. The trace leads to the file and line at fault, and then to the headless scene that
  reproduces it. Remove the prints before committing.
